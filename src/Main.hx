import neko.Lib;

class Main {
	static var RUNTIME_FILES = [
		{ lib:null, f:"hl.exe" },
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

	static var NEW_LINE = "\n";


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

		// Haxe install folder
		var haxeFolder = Sys.getEnv("HAXEPATH");
		if( haxeFolder==null )
			error("Missing environment variable HAXEPATH.");

		// Set CWD to the directory haxelib was called
		var haxeLibDir = Sys.getCwd();
		var projectDir = isolatedParams[isolatedParams.length-1]; // call directory is passed as the last param in haxelibs
		if( projectDir==null )
			error("Script wasn't called using: haxelib run redistHelper [...]");
		Sys.setCwd(projectDir);

		// Project name
		var projectName = getParameter("-p");
		if( projectName==null ) {
			var p = haxe.io.Path.removeTrailingSlashes( StringTools.replace(projectDir,"\\","/") );
			var split = p.split("/");
			projectName = split[split.length-1];
		}
		Lib.println("Project name: "+projectName);

		// List HXMLs
		var hxmls = [];
		for(p in isolatedParams)
			if( p.indexOf(".hxml")>=0 )
				hxmls.push(p);
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
		var redistFolder = getParameter("-o");
		if( redistFolder==null )
			redistFolder = "redist";

		// Prepare base folder
		Lib.println("Preparing folders...");
		var cwd = StringTools.replace( Sys.getCwd(), "\\", "/" );
		var abs = StringTools.replace( sys.FileSystem.absolutePath(redistFolder), "\\", "/" );
		if( abs.indexOf(cwd)<0 || abs==cwd )
			error("For security reasons, target folder should be nested inside current folder.");
		directoryContainsOnly(redistFolder, ["exe","dat","dll","hdll","js","swf","html"]); // avoid deleting unexpected files
		removeDirectory(redistFolder);
		createDirectory(redistFolder);



		// Parse HXML files given as parameters
		for(hxml in hxmls) {
			var content = sys.io.File.read(hxml, false).readAll().toString();

			// HL
			if( content.indexOf("-hl ")>=0 ) {
				// Create folder
				createDirectory(redistFolder+"/"+projectName);

				// Copy runtimes
				Lib.println("Copying HL runtime files...");
				for( r in RUNTIME_FILES ) {
					if( r.lib==null || hxmlRequiresLib(hxml, r.lib) ) {
						Lib.println(" -> "+r.f + ( r.lib==null?"" : " [required by -lib "+r.lib+"]") );
						copy(haxeFolder+r.f, redistFolder+"/"+projectName+"/"+r.f);
					}
				}
				sys.FileSystem.rename(redistFolder+"/"+projectName+"/hl.exe", redistFolder+"/"+projectName+"/"+projectName+".exe");
				Lib.println("");

				// Build
				Lib.println("Building "+hxml+"...");
				Sys.command("haxe", [hxml]);
				var out = getHxmlOutput(hxml,"-hl");
				copy(out, redistFolder+"/"+projectName+"/hlboot.dat");
				Lib.println("");
			}

			// JS
			if( content.indexOf("-js ")>=0 ) {
				// Build
				Lib.println("Building "+hxml+"...");
				Sys.command("haxe", [hxml]);
				var out = getHxmlOutput(hxml,"-js");
				copy(out, redistFolder+"/client.js");
				// Create HTML
				Lib.println("Creating HTML...");
				var fi = sys.io.File.read(haxeLibDir+"/res/webgl.html");
				var html = "";
				while( !fi.eof() )
				try { html += fi.readLine()+"\n"; } catch(e:haxe.io.Eof) {}
				html = StringTools.replace(html, "%project%", projectName);
				html = StringTools.replace(html, "%js%", "client.js");
				var fo = sys.io.File.write(redistFolder+"/"+projectName+".html", false);
				fo.writeString(html);
				fo.close();
				Lib.println("");
			}

			// SWF
			if( content.indexOf("-swf ")>=0 ) {
				Lib.println("Building "+hxml+"...");
				Sys.command("haxe", [hxml]);
				var out = getHxmlOutput(hxml,"-swf");
				copy(out, redistFolder+"/"+projectName+".swf");
				Lib.println("");
			}
		}

		Lib.println("Done.");
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

	static function directoryContainsOnly(path:String, allowedExts:Array<String>) {
		if( !sys.FileSystem.exists(path) )
			return;

		for( e in sys.FileSystem.readDirectory(path) ) {
			if( sys.FileSystem.isDirectory(path+"/"+e) )
				directoryContainsOnly(path+"/"+e, allowedExts);
			else {
				var extMatched = false;
				for(ext in allowedExts)
					if( e.indexOf(ext)>0 ) {
						extMatched = true;
						break;
					}
				if( !extMatched )
					error("Target folder (which will be deleted) seems to contain unexpected files like "+e);
			}
		}
	}

	static function copy(from:String, to:String) {
		try {
			sys.io.File.copy(from, to);
		}
		catch(e:Dynamic) {
			error("Can't copy "+from+" ("+e+")");
		}
	}

	static function getHxmlOutput(hxmlPath:String, lookFor:String) : Null<String> {
		if( hxmlPath==null )
			return null;

		if( !sys.FileSystem.exists(hxmlPath) )
			error("File not found: "+hxmlPath);

		try {
			var fi = sys.io.File.read(hxmlPath, false);
			for( line in fi.readAll().toString().split(NEW_LINE) ) {
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
		Lib.println("  haxelib run redistHelper [-o <outputFolder>] [-p <project_name>] [<hxml1>] [<hxml2>] [<hxml3>]");
		Lib.println("NOTES:");
		Lib.println("  If no HXML is given, the script will pick all HXMLs found in current directory.");
		Lib.println("  If no Project Name is set, the current folder name will be used.");
		Sys.exit(0);
	}

	static function error(msg:Dynamic) {
		Lib.println("");
		Lib.println("ERROR - "+Std.string(msg));
		usage();
	}
}

