import neko.Lib;

typedef RuntimeFile = {
	var lib: Null<String>;
	var f: String;
	var ?executableFormat: String;
}

typedef ExtraCopiedFile = {
	var path: String;
	var file: String;
}

class Main {
	static var RUNTIME_FILES_WIN : Array<RuntimeFile> = [
		{ lib:null, f:"hl.exe", executableFormat:"$.exe" },
		{ lib:null, f:"libhl.dll" },
		{ lib:null, f:"msvcr120.dll" },
		{ lib:null, f:"fmt.hdll" },
		{ lib:null, f:"ssl.hdll" },

		{ lib:"heaps", f:"OpenAL32.dll" },
		{ lib:"heaps", f:"openal.hdll" },
		{ lib:"heaps", f:"ui.hdll" },
		{ lib:"heaps", f:"uv.hdll" },

		{ lib:"hlsdl", f:"SDL2.dll" },
		{ lib:"hlsdl", f:"sdl.hdll" },

		{ lib:"hlsteam", f:"steam.hdll" },
		{ lib:"hlsteam", f:"steam_api.dll" },

		{ lib:"hldx", f:"directx.hdll" },
		{ lib:"hldx", f:"d3dcompiler_47.dll" },
	];
	static var RUNTIME_FILES_MAC : Array<RuntimeFile> = [
		{ lib:null, f:"macRedist/hl", executableFormat:"$" },
		{ lib:null, f:"macRedist/libhl.dylib" },
		{ lib:null, f:"macRedist/libpng16.16.dylib" }, // fmt
		{ lib:null, f:"macRedist/libvorbis.0.dylib" }, // fmt
		{ lib:null, f:"macRedist/libvorbisfile.3.dylib" }, // fmt
		{ lib:null, f:"macRedist/libmbedtls.10.dylib" }, // SSL

		{ lib:"heaps", f:"macRedist/libuv.1.dylib" },
		{ lib:"heaps", f:"macRedist/libopenal.1.dylib" },

		{ lib:"hlsdl", f:"macRedist/libSDL2-2.0.0.dylib" },
	];

	static var NEW_LINE = "\n";

	static var redistHelperDir = "";
	static var projectDir = "";


	static function main() {
		haxe.Log.trace = function(m, ?pos) {
			if ( pos != null && pos.customParams == null )
				pos.customParams = ["debug"];

			Lib.println(Std.string(m));
		}

		if( Sys.args().length==0 )
			usage();

		// Misc parameters
		var isolatedParams = getIsolatedParameters();

		// Set CWD to the directory haxelib was called
		redistHelperDir = cleanupPathWithTrailing( Sys.getCwd() );
		projectDir = cleanupPathWithTrailing( isolatedParams.pop() ); // call directory is passed as the last param in haxelibs
		if( projectDir==null )
			error("Script wasn't called using: haxelib run redistHelper [...]");
		Sys.setCwd(projectDir);

		// Project name
		var projectName = getParameter("-p");
		if( projectName==null ) {
			var split = projectDir.split("/");
			projectName = split[split.length-2];
		}
		Lib.println("Project name: "+projectName);

		// List HXMLs
		var hxmls = [];
		var extraFiles : Array<ExtraCopiedFile> = [];
		for(p in isolatedParams)
			if( p.indexOf(".hxml")>=0 )
				hxmls.push(p);
			else {
				var tmp = StringTools.replace(p,"\\","/").split("/");
				extraFiles.push({ path:p, file:tmp[tmp.length-1] });
			}
		if( hxmls.length==0 ) {
			// Search for HXML in project folder if no parameter was given
			for( f in sys.FileSystem.readDirectory(projectDir) )
				if( !sys.FileSystem.isDirectory(f) && f.indexOf(".hxml")>=0 )
					hxmls.push(f);

			if( hxmls.length==0 )
				error("No HXML found in current folder.");
			else
				Lib.println("Discovered "+hxmls.length+" potential HXML file(s): "+hxmls.join(", "));
		}

		// Output folder
		var baseRedistDir = getParameter("-o");
		if( baseRedistDir==null )
			baseRedistDir = "redist";

		// Prepare base folder
		var separateDirs = baseRedistDir.indexOf("$")>=0;
		if( !separateDirs )
			initRedistDir(baseRedistDir, extraFiles);

		var extraFilesTargets = [];

		// Parse HXML files given as parameters
		for(hxml in hxmls) {
			var content = getFullHxml( hxml );

			// HL
			if( content.indexOf("-hl ")>=0 ) {
				// Build
				var directX = content.indexOf("hldx")>0;

				var redistDir = separateDirs ? StringTools.replace(baseRedistDir, "$", directX ? "dx" : "sdl") : baseRedistDir;
				if( separateDirs )
					initRedistDir(redistDir, extraFiles);

				Lib.println("Building "+hxml+"...");
				Sys.command("haxe", [hxml]);

				function makeHl(tDir:String, files:Array<RuntimeFile>) {
					// Create folder
					createDirectory(tDir);
					extraFilesTargets.push(tDir);

					// Copy runtimes
					Lib.println("Copying HL runtime files to "+tDir+"...");
					for( r in files ) {
						if( r.lib==null || hxmlRequiresLib(hxml, r.lib) ) {
							Lib.println(" -> "+r.f + ( r.lib==null?"" : " [required by -lib "+r.lib+"]") );
							var from = findFileInEnvPath(r.f);
							var toFile = r.executableFormat!=null ? StringTools.replace(r.executableFormat, "$", projectName) : r.f.indexOf("/")<0 ? r.f : r.f.substr(r.f.lastIndexOf("/")+1);
							var to = tDir+"/"+toFile;
							if( r.executableFormat!=null )
								Lib.println(" -> Renamed executable to "+toFile);
							copy(from, to);
						}
					}

					// Copy HL bin file
					var out = getHxmlOutput(hxml,"-hl");
					copy(out, tDir+"/hlboot.dat");
					Lib.println("");
				}

				// Package HL
				if( directX )
					makeHl(redistDir+"/"+projectName, RUNTIME_FILES_WIN); // directX, windows only
				else {
					makeHl(redistDir+"/"+projectName+".win", RUNTIME_FILES_WIN); // SDL windows
					makeHl(redistDir+"/"+projectName+".mac", RUNTIME_FILES_MAC); // SDL Mac
				}

			}

			// JS
			if( content.indexOf("-js ")>=0 ) {
				// Build
				var redistDir = separateDirs ? StringTools.replace(baseRedistDir,"$","js") : baseRedistDir;
				if( separateDirs )
					initRedistDir(redistDir, extraFiles);

				Lib.println("Building "+hxml+"...");
				Sys.command("haxe", [hxml]);
				var out = getHxmlOutput(hxml,"-js");
				copy(out, redistDir+"/client.js");
				// Create HTML
				Lib.println("Creating HTML...");
				var fi = sys.io.File.read(redistHelperDir+"res/webgl.html");
				var html = "";
				while( !fi.eof() )
				try { html += fi.readLine()+NEW_LINE; } catch(e:haxe.io.Eof) {}
				html = StringTools.replace(html, "%project%", projectName);
				html = StringTools.replace(html, "%js%", "client.js");
				var fo = sys.io.File.write(redistDir+"/"+projectName+".html", false);
				fo.writeString(html);
				fo.close();
				extraFilesTargets.push(redistDir);
				Lib.println("");
			}

			// SWF
			if( content.indexOf("-swf ")>=0 ) {
				var redistDir = separateDirs ? StringTools.replace(baseRedistDir,"$","swf") : baseRedistDir;
				if( separateDirs )
					initRedistDir(redistDir, extraFiles);

				Lib.println("Building "+hxml+"...");
				Sys.command("haxe", [hxml]);
				var out = getHxmlOutput(hxml,"-swf");
				copy(out, redistDir+"/"+projectName+".swf");
				extraFilesTargets.push(redistDir+"/"+projectName);
				Lib.println("");
			}
		}

		for(f in extraFiles) {
			var dups = new Map();
			for(t in extraFilesTargets) {
				if( dups.exists(t) )
					continue;
				dups.set(t, true);
				Lib.println("Copying file "+f.path+" to "+t+"...");
				copy(projectDir+f.path, t+"/"+f.file);
			}
		}


		Lib.println("Done.");
	}

	static inline function cleanupPathWithTrailing(path:String) {
		return haxe.io.Path.addTrailingSlash( StringTools.replace(path, "\\", "/") );
	}

	static function findFileInEnvPath(f:String) {
		if( sys.FileSystem.exists(redistHelperDir+f) )
			return redistHelperDir+f;

		for(path in Sys.getEnv("path").split(";")) {
			path = cleanupPathWithTrailing(path);
			if( sys.FileSystem.exists(path+f) )
				return path+f;
		}

		throw "File not found: "+f;
	}

	static function initRedistDir(d:String, extraFiles:Array<ExtraCopiedFile>) {
		Lib.println("Initializing folder: "+d+"...");
		var cwd = StringTools.replace( Sys.getCwd(), "\\", "/" );
		var abs = StringTools.replace( sys.FileSystem.absolutePath(d), "\\", "/" );
		if( abs.indexOf(cwd)<0 || abs==cwd )
			error("For security reasons, target folder should be nested inside current folder.");
		// avoid deleting unexpected files
		directoryContainsOnly(d, ["exe","dat","dll","hdll","js","swf","html","dylib"], extraFiles.map( function(e) return e.file) );
		removeDirectory(d);
		createDirectory(d);
	}


	static function getFullHxml(f:String) {
		var lines = sys.io.File.read(f, false).readAll().toString().split(NEW_LINE);
		var i = 0;
		while( i<lines.length ) {
			if( lines[i].indexOf(".hxml")>=0 )
				lines[i] = getFullHxml(lines[i]);
			i++;
		}

		return lines.join(NEW_LINE);
	}


	static function createDirectory(path:String) {
		try {
			sys.FileSystem.createDirectory(path);
		}
		catch(e:Dynamic) {
			error("Couldn't create directory "+path+" ("+e+")");
		}
	}

	static function removeDirectory(path:String) {
		if( !sys.FileSystem.exists(path) )
			return;

		for( e in sys.FileSystem.readDirectory(path) ) {
			if( sys.FileSystem.isDirectory(path+"/"+e) )
				removeDirectory(path+"/"+e);
			else
				sys.FileSystem.deleteFile(path+"/"+e);
		}
		sys.FileSystem.deleteDirectory(path+"/");
	}

	static function directoryContainsOnly(path:String, allowedExts:Array<String>, ignoredFiles:Array<String>) {
		if( !sys.FileSystem.exists(path) )
			return;

		for( e in sys.FileSystem.readDirectory(path) ) {
			if( sys.FileSystem.isDirectory(path+"/"+e) )
				directoryContainsOnly(path+"/"+e, allowedExts, ignoredFiles);
			else {
				var suspFile = true;
				if( e.indexOf(".")<0 )
					suspFile = false; // ignore extension-less files

				for(ext in allowedExts)
					if( e.indexOf("."+ext)>0 ) {
						suspFile = false;
						break;
					}
				for(f in ignoredFiles)
					if( f==e )
						suspFile = false;
				if( suspFile )
					error("Target folder (which will be deleted) seems to contain unexpected files like "+e);
			}
		}
	}

	static function copy(from:String, to:String) {
		// try {
			sys.io.File.copy(from, to);
		// }
		// catch(e:Dynamic) {
		// 	error("Can't copy "+from+" ("+e+")");
		// }
	}

	static function getHxmlOutput(hxmlPath:String, lookFor:String) : Null<String> {
		if( hxmlPath==null )
			return null;

		if( !sys.FileSystem.exists(hxmlPath) )
			error("File not found: "+hxmlPath);

		try {
			var content = getFullHxml(hxmlPath);
			for( line in content.split(NEW_LINE) ) {
				if( line.indexOf(lookFor)>=0 )
					return StringTools.trim( line.split(lookFor)[1] );
			}
		} catch(e:Dynamic) {
			error("Could not read "+hxmlPath+" ("+e+")");
		}
		error("No "+lookFor+" output in "+hxmlPath);
		return null;
	}

	static function hxmlRequiresLib(hxmlPath:String, libId:String) : Bool {
		if( hxmlPath==null )
			return false;

		if( !sys.FileSystem.exists(hxmlPath) )
			error("File not found: "+hxmlPath);

		try {
			var fi = sys.io.File.read(hxmlPath, false);
			var content = fi.readAll().toString();
			if( content.indexOf("-lib "+libId)>=0 )
				return true;
			for(line in content.split(NEW_LINE))
				if( line.indexOf(".hxml")>=0 )
					return hxmlRequiresLib(line, libId);
		} catch(e:Dynamic) {
			error("Could not read "+hxmlPath+" ("+e+")");
		}
		return false;
	}

	static function hasParameter(id:String) {
		for( p in Sys.args() )
			if( p==id )
				return true;
		return false;
	}

	static function getParameter(id:String) : Null<String> {
		var isNext = false;
		for( p in Sys.args() )
			if( p==id )
				isNext = true;
			else if( isNext )
				return p;

		return null;
	}

	static function getIsolatedParameters() : Array<String> {
		var all = [];
		var ignoreNext = false;
		for( p in Sys.args() ) {
			if( p.charAt(0)=="-" )
				ignoreNext = true;
			else if( !ignoreNext )
				all.push(p);
			else
				ignoreNext = false;
		}

		return all;
	}

	static function getIsolatedParameter(idx:Int) : Null<String> {
		var i = 0;
		var ignoreNext = false;
		for( p in Sys.args() ) {
			if( p.charAt(0)=="-" )
				ignoreNext = true;
			else if( !ignoreNext ) {
				if( idx==i )
					return p;
				i++;
			}
			else
				ignoreNext = false;
		}

		return null;
	}

	static function usage() {
		Lib.println("USAGE:");
		Lib.println("  haxelib run redistHelper [-o <outputDir>] [-p <project_name>] [<hxml1>] [<hxml2>] [<hxml3>] [customFile1] [customFile2]");
		Lib.println("NOTES:");
		Lib.println("  - If no HXML is given, the script will pick all HXMLs found in current folder.");
		Lib.println("  - If no Project Name is set, the current folder name will be used.");
		Lib.println("  - All specificied \"Custom files\" will be copied in the redist folders");
		Lib.println("  - You can export each HXML build in a separate folder by adding a \"$\" in the -o parameter.");
		Lib.println("    Example: -o redist.$");
		Lib.println("    This will output each build in a separate folder named redist.js, redist.swf, etc.");
		Sys.exit(0);
	}

	static function error(msg:Dynamic) {
		Lib.println("");
		Lib.println("ERROR - "+Std.string(msg));
		usage();
	}
}

