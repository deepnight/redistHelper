import dn.Lib;
import dn.FilePath;
import dn.FileTools;

typedef RuntimeFile = {
	var lib: Null<String>;
	var f: String; // defaults to 64bits version
	var ?f32: String; // alternative 32bits version
	var ?executableFormat: String;
}

typedef ExtraCopiedFile = {
	var source : FilePath;
	var isDir : Bool;
	var rename: Null<String>;
}

class Main {
	static var NEKO_RUNTIME_FILES_WIN : Array<RuntimeFile> = [
		{ lib:null, f:"neko.lib" },

		{ lib:null, f:"concrt140.dll" },
		{ lib:null, f:"gcmt-dll.dll" },
		{ lib:null, f:"msvcp140.dll" },
		{ lib:null, f:"neko.dll" },
		{ lib:null, f:"vcruntime140.dll" },

		{ lib:null, f:"mysql.ndll" },
		{ lib:null, f:"mysql5.ndll" },
		{ lib:null, f:"regexp.ndll" },
		{ lib:null, f:"sqlite.ndll" },
		{ lib:null, f:"ssl.ndll" },
		{ lib:null, f:"std.ndll" },
		{ lib:null, f:"ui.ndll" },
		{ lib:null, f:"zlib.ndll" },
	];

	static var HL_RUNTIME_FILES_WIN : Array<RuntimeFile> = [
		{ lib:null, f:"hl.exe", executableFormat:"$.exe" },
		{ lib:null, f:"libhl.dll" },
		{ lib:null, f:"msvcr120.dll" },
		{ lib:null, f:"msvcp120.dll" },
		{ lib:null, f:"fmt.hdll" },
		{ lib:null, f:"ssl.hdll" },

		{ lib:"heaps", f:"OpenAL32.dll" },
		{ lib:"heaps", f:"openal.hdll" },
		{ lib:"heaps", f:"ui.hdll" },
		{ lib:"heaps", f:"uv.hdll" },

		{ lib:"hlsdl", f:"SDL2.dll" },
		{ lib:"hlsdl", f:"sdl.hdll" },

		{ lib:"hlsteam", f:"steam.hdll" },
		{ lib:"hlsteam", f:"steam_api64.dll", f32:"steam_api.dll" },

		{ lib:"hldx", f:"directx.hdll" },
		{ lib:"hldx", f:"d3dcompiler_47.dll" },
	];
	static var HL_RUNTIME_FILES_MAC : Array<RuntimeFile> = [
		{ lib:null, f:"redistFiles/mac/hl", executableFormat:"$" },
		{ lib:null, f:"redistFiles/mac/libhl.dylib" },
		{ lib:null, f:"redistFiles/mac/libpng16.16.dylib" }, // fmt
		{ lib:null, f:"redistFiles/mac/libvorbis.0.dylib" }, // fmt
		{ lib:null, f:"redistFiles/mac/libvorbisfile.3.dylib" }, // fmt
		{ lib:null, f:"redistFiles/mac/libmbedtls.10.dylib" }, // SSL

		{ lib:"heaps", f:"redistFiles/mac/libuv.1.dylib" },
		{ lib:"heaps", f:"redistFiles/mac/libopenal.1.dylib" },

		{ lib:"hlsdl", f:"redistFiles/mac/libSDL2-2.0.0.dylib" },
	];

	static var PAK_BUILDER_BIN = "pakBuilder.hl";
	static var PAK_BUILDER_OUT = "redistTmp";

	static var SWF_RUNTIME_FILES_WIN : Array<RuntimeFile> = [
		{ lib:null, f:"redistFiles/flash/win_flashplayer_32_sa.exe", executableFormat:"flashPlayer.bin" },
	];
	static var SINGLE_PARAMETERS = [
		"-zip" => true,
		"-sign" => true,
		"-pak" => true,
		"-h" => true,
		"--help" => true,
		"-z" => true,
		"-v" => true,
		"--verbose" => true,
		"-hl32" => true,
	];

	static var NEW_LINE = "\n";

	static var redistHelperDir = "";
	static var projectDir = "";
	static var projectName = "unknown";
	static var verbose = false;


	static function main() {
		haxe.Log.trace = function(m, ?pos) {
			if ( pos != null && pos.customParams == null )
				pos.customParams = ["debug"];

			Lib.println(Std.string(m));
		}
		FilePath.SLASH_MODE = OnlySlashes;

		if( Sys.args().length==0 )
			usage();

		Sys.println("");

		// Misc parameters
		if( hasParameter("-h") || hasParameter("--help") )
			usage();
		verbose = hasParameter("-v") || hasParameter("--verbose");
		var zipping = hasParameter("-zip") || hasParameter("-z");
		var isolatedParams = getIsolatedParameters();

		// Set CWD to the directory haxelib was called
		redistHelperDir = cleanUpDirPath( Sys.getCwd() );
		projectDir = cleanUpDirPath( isolatedParams.pop() ); // call directory is passed as the last param in haxelibs
		if( verbose ) {
			Sys.println("RedistHelperDir="+redistHelperDir);
			Sys.println("ProjectDir="+projectDir);
		}
		try {
			Sys.setCwd(projectDir);
		}
		catch(e:Dynamic) {
			error("Script wasn't called using: haxelib run redistHelper [...]  (projectDir="+projectDir+")");
		}

		// List HXMLs and extra files
		var hxmlPaths = [];
		var extraFiles : Array<ExtraCopiedFile> = [];
		for(p in isolatedParams)
			if( p.indexOf(".hxml")>=0 )
				hxmlPaths.push(p);
			else {
				// Found an isolated extra file to copy
				var renameParts = p.split("@");
				var path = renameParts[0];
				if( !sys.FileSystem.exists(path) )
					error("File not found: "+path);

				var isDir = sys.FileSystem.isDirectory(path);
				var originalFile = isDir ? FilePath.fromDir(path) : FilePath.fromFile(path);
				if( renameParts.length==1 )
					extraFiles.push({ source:originalFile, rename:null, isDir:isDir });
				else
					extraFiles.push({ source:originalFile, rename:renameParts[1], isDir:isDir });
			}
		if( verbose ) {
			Sys.println("ExtraFiles listing:");
			for(e in extraFiles) {
				Sys.println( " -> "+e.source.full
					+ ( e.rename!=null ? " >> "+e.rename : "" )
					+ ( e.isDir ? " [DIRECTORY]" : "" )
				);
			}
		}
		if( hxmlPaths.length==0 ) {
			usage();
			// // Search for HXML in project folder if no parameter was given
			// for( f in sys.FileSystem.readDirectory(projectDir) )
			// 	if( !sys.FileSystem.isDirectory(f) && f.indexOf(".hxml")>=0 )
			// 		hxmlPaths.push(f);

			// if( hxmlPaths.length==0 )
			// 	error("No HXML found in current folder.");
			// else
			// 	Lib.println("Discovered "+hxmlPaths.length+" potential HXML file(s): "+hxmlPaths.join(", "));
		}

		// Project name
		projectName = getParameter("-p");
		if( projectName==null ) {
			var split = projectDir.split("/");
			projectName = split[split.length-2];
		}
		Lib.println("Project name: "+projectName);

		// Output folder
		var baseRedistDir = getParameter("-o");
		if( baseRedistDir==null )
			baseRedistDir = "redist";
		if( baseRedistDir.indexOf("$")>=0 )
			error("The \"$\" in the \"-o\" parameter is deprecated. RedistHelper now exports each redistribuable to a separate folder by default.");

		// Prepare base folder
		initRedistDir(baseRedistDir, extraFiles);


		// Parse HXML files given as parameters
		for(hxml in hxmlPaths) {
			Sys.println("Parsing "+hxml+"...");
			var content = getFullHxml( hxml );

			// HL
			if( content.indexOf("-hl ")>=0 ) {
				// Build
				var directX = content.indexOf("hldx")>0;

				Lib.println("Building "+hxml+"...");
				compile(hxml);

				function makeHl(hlDir:String, files:Array<RuntimeFile>, use32bits:Bool) {
					Lib.println("Packaging "+hlDir+"...");
					initRedistDir(hlDir, extraFiles);

					// Create folder
					createDirectory(hlDir);

					// Runtimes
					copyRuntimeFiles(hxml, "HL", hlDir, files, use32bits);

					// Copy HL bin file
					var out = getHxmlOutput(hxml,"-hl");
					copy(out, hlDir+"/hlboot.dat");

					copyExtraFilesIn(extraFiles, hlDir);
				}

				// Package HL
				if( directX ) {
					// DirectX 64bits
					makeHl(baseRedistDir+"/directx/"+projectName, HL_RUNTIME_FILES_WIN, false);
					if( zipping )
						zipFolder( '$baseRedistDir/${projectName}_directx.zip', baseRedistDir+"/directx");

					// DirectX 32bits
					if( hasParameter("-hl32") ) {
						makeHl(baseRedistDir+"/directx32/"+projectName, HL_RUNTIME_FILES_WIN, true); // directX 32 bits
						if( zipping )
							zipFolder( '$baseRedistDir/${projectName}_directx32.zip', baseRedistDir+"/directx32");
					}
				}
				else {
					// SDL Windows 64bits
					makeHl(baseRedistDir+"/opengl_win/"+projectName, HL_RUNTIME_FILES_WIN, false);
					if( zipping )
						zipFolder( '$baseRedistDir/${projectName}_opengl_win.zip', baseRedistDir+"/opengl_win/");

					// SDL Windows 32bits
					if( hasParameter("-hl32") ) {
						makeHl(baseRedistDir+"/opengl_win32/"+projectName, HL_RUNTIME_FILES_WIN, true);
						if( zipping )
							zipFolder( '$baseRedistDir/${projectName}_opengl_win32.zip', baseRedistDir+"/opengl_win32/");
					}

					// SDL Mac
					makeHl(baseRedistDir+"/opengl_mac/"+projectName, HL_RUNTIME_FILES_MAC, false);
					if( zipping )
						zipFolder( '$baseRedistDir/${projectName}_opengl_mac.zip', baseRedistDir+"/opengl_mac/");
				}
			}

			// JS
			if( content.indexOf("-js ")>=0 ) {
				// Build
				var jsDir = baseRedistDir+"/js";
				initRedistDir(jsDir, extraFiles);

				Lib.println("Building "+hxml+"...");
				compile(hxml);

				Lib.println("Packaging "+jsDir+"...");
				var out = getHxmlOutput(hxml,"-js");
				copy(out, jsDir+"/client.js");

				// Create HTML
				Lib.println("Creating HTML...");
				var fi = sys.io.File.read(redistHelperDir+"redistFiles/webgl.html");
				var html = "";
				while( !fi.eof() )
				try { html += fi.readLine()+NEW_LINE; } catch(e:haxe.io.Eof) {}
				html = StringTools.replace(html, "%project%", projectName);
				html = StringTools.replace(html, "%js%", "client.js");
				var fo = sys.io.File.write(jsDir+"/index.html", false);
				fo.writeString(html);
				fo.close();

				copyExtraFilesIn(extraFiles, jsDir);
				if( zipping )
					zipFolder( baseRedistDir+"/js.zip", jsDir);
			}

			// Neko
			if( content.indexOf("-neko ")>=0 ) {
				var nekoDir = baseRedistDir+"/neko";
				initRedistDir(nekoDir, extraFiles);

				Lib.println("Building "+hxml+"...");
				compile(hxml);

				Lib.println("Creating executable...");
				var out = FilePath.fromFile( getHxmlOutput(hxml,"-neko") );
				Sys.command("nekotools", ["boot",out.full]);
				out.extension = "exe";

				Lib.println("Packaging "+nekoDir+"...");
				copy(out.full, nekoDir+"/"+projectName+".exe");
				if( hasParameter("-sign") )
					signExecutable(nekoDir+"/"+projectName+".exe");

				copyRuntimeFiles(hxml, "Neko", nekoDir, NEKO_RUNTIME_FILES_WIN, false);

				copyExtraFilesIn(extraFiles, nekoDir);
				if( zipping )
					zipFolder( baseRedistDir+"/neko.zip", nekoDir);
			}

			// SWF
			if( content.indexOf("-swf ")>=0 ) {
				var swfDir = '$baseRedistDir/flash/$projectName';
				initRedistDir(swfDir, extraFiles);

				Lib.println("Building "+hxml+"...");
				compile(hxml);

				Lib.println("Packaging "+swfDir+"...");
				var out = getHxmlOutput(hxml,"-swf");
				copy(out, swfDir+"/"+projectName+".swf");
				copyRuntimeFiles(hxml, "SWF", swfDir, SWF_RUNTIME_FILES_WIN, false);

				var script = [
					'@echo off',
					'start flashPlayer.bin $projectName.swf',
				];
				createTextFile('$swfDir/Play $projectName.bat', script.join("\n"));

				copyExtraFilesIn(extraFiles, swfDir);
				if( zipping )
					zipFolder( baseRedistDir+"/swf.zip", swfDir);
			}
		}

		cleanUpExit();
		Lib.println("Done.");
		Sys.exit(0);
	}

	static function checkExeInPath(exe:String) {
		var p = new sys.io.Process("where /q "+exe);
		if( p.exitCode()==0 )
			return true;
		else
			return false;
	}


	static function signExecutable(exePath:String) {
		Lib.println("Code signing executable...");

		// Check EXE
		if( !sys.FileSystem.exists(exePath) )
			error("Cannot sign executable, file not found: "+exePath);

		var fp = FilePath.fromFile(exePath);
		if( fp.extension!="exe" ) {
			Lib.println("  Warning: only supported on Windows executables");
			return false;
		}


		// Check if MS SignTool is installed
		if( !checkExeInPath("signtool.exe") )
			error('You need "signtool.exe" in PATH. You can get it by installing Microsoft Windows SDK (only pick "signing tools").');

		// Get PFX path from either argument or env "CSC_LINK"
		var pfx : Null<String> = null;
		if( hasParameter("-pfx") && !hasParameter("-sign") )
			error('Argument "-pfx" implies to also have "-sign" arg.');
		if( hasParameter("-sign") ) {
			pfx = getParameter("-pfx");
			if( pfx==null || pfx=="" )
				pfx = Sys.getEnv("CSC_LINK");
			if( pfx==null || !sys.FileSystem.exists(pfx) )
				error("Certificate file (.pfx) is missing after -pfx argument.");
		}

		Lib.println('  Using certificate: $pfx');

		// Get password for env "CSC_KEY_PASSWORD" or by asking the user for it
		var pass = hasParameter("-pfx") ? null : Sys.getEnv("CSC_KEY_PASSWORD");
		if( pass==null ) {
			Sys.print("  Enter PFX password: ");
			pass = Sys.stdin().readLine();
		}
		var result = Sys.command('signtool.exe sign /f "$pfx" /fd SHA256 /t http://timestamp.digicert.com /p "$pass" $exePath');
		if( result!=0 )
			error('Code signing failed! (code $result)');

		return true;
	}

	static function cleanUpExit() {
		Lib.println("Cleaning up...");

		if( sys.FileSystem.exists(PAK_BUILDER_BIN) )
			sys.FileSystem.deleteFile(PAK_BUILDER_BIN);

		if( hasParameter("-pak") && sys.FileSystem.exists(PAK_BUILDER_OUT+".pak") )
			sys.FileSystem.deleteFile(PAK_BUILDER_OUT+".pak");
	}

	static function createTextFile(path:String, content:String) {
		sys.io.File.saveContent(path, content);
	}

	static function compile(hxmlPath:String) {
		// Compile
		if( Sys.command("haxe", [hxmlPath]) != 0 )
			error('Compilation failed!');

		// PAK
		if( hasParameter("-pak") ) {
			// Compile PAK builder
			if( !sys.FileSystem.exists(PAK_BUILDER_BIN) ) {
				Lib.println("Compiling PAK builder ("+Sys.getCwd()+")...");
				if( Sys.command("haxe -hl "+PAK_BUILDER_BIN+" -lib heaps -main hxd.fmt.pak.Build") != 0 )
					error("Could not compile PAK builder!");
			}

			// Ignore elements
			var extraArgs = [];
			Lib.println("Creating PAK...");
			var ignores = getIgnoredElements();
			if( ignores.names.length>0 )
				extraArgs.push("-exclude-names "+ignores.names.join(","));
			if( ignores.exts.length>0 )
				extraArgs.push("-exclude "+ignores.exts.join(","));

			if( extraArgs.length>0 )
				Sys.println("  Extra arguments: "+extraArgs.join(" "));

			// Run it
			if( Sys.command( "hl "+PAK_BUILDER_BIN+" -out "+PAK_BUILDER_OUT+" "+extraArgs.join(" ") ) != 0 ) {
				error("Failed to run HL to build PAK!");
			}
		}
	}

	static function copyRuntimeFiles(hxmlPath:String, targetName:String, targetDir:String, runTimeFiles:Array<RuntimeFile>, useHl32bits:Bool) {
		if( verbose )
			Lib.println("Copying "+targetName+" runtime files to "+targetDir+"... ");

		var exes = [];
		for( r in runTimeFiles ) {
			if( r.lib==null || hxmlRequiresLib(hxmlPath, r.lib) ) {
				var fileName = useHl32bits && r.f32!=null ? r.f32 : r.f;
				var from = findFile(fileName, useHl32bits);
				if( verbose )
					Lib.println(" -> "+fileName + ( r.lib==null?"" : " [required by -lib "+r.lib+"] (source: "+from+")") );
				var toFile = r.executableFormat!=null ? StringTools.replace(r.executableFormat, "$", projectName) : fileName.indexOf("/")<0 ? fileName : fileName.substr(fileName.lastIndexOf("/")+1);
				var to = targetDir+"/"+toFile;
				if( r.executableFormat!=null && verbose )
					Lib.println(" -> Renamed executable to "+toFile);
				copy(from, to);

				// List executables
				if( r.executableFormat!=null )
					exes.push( FilePath.fromFile(targetDir+"/"+toFile) );
			}
		}

		// Copy PAK
		if( hasParameter("-pak") )
			copy(PAK_BUILDER_OUT+".pak", targetDir+"/res.pak");

		// Set EXEs icon
		if( hasParameter("-icon") && targetDir.indexOf("mac") == -1 ) // but not for mac builds
			for( exeFp in exes ) {
				var i = getParameter("-icon");
				if( i==null )
					error("Missing icon path");

				var iconFp = FilePath.fromFile( StringTools.replace( i, "\"", "") );

				iconFp.useSlashes();
				exeFp.useSlashes();

				Lib.println("Replacing EXE icon...");
				if( !sys.FileSystem.exists(iconFp.full) )
					error("Icon file not found: "+iconFp.full);

				if( verbose ) {
					Lib.println("  exe="+exeFp.full);
					Lib.println("  icon="+iconFp.full);
				}
				if( runTool('rcedit/rcedit.exe', ['"${exeFp.full}"', '--set-icon "${iconFp.full}" ']) != 0 )
					error("rcedit failed!");
			}

		// Sign exe
		if( hasParameter("-sign") && exes.length>0 )
			for( fp in exes )
				signExecutable(fp.full);
	}


	static function runTool(path:String, args:Array<String>) : Int {
		var toolFp = FilePath.fromFile('$redistHelperDir/tools/$path');
		toolFp.useSlashes();
		var cmd = '"${toolFp.full}" ${args.join(" ")}';
		if( verbose )
			Lib.println("Executing tool: "+cmd);

		// Use sys.io.Process instead of Sys.command because of quotes ("") bug
		var p = new sys.io.Process(cmd);
		var code = p.exitCode();
		p.close();
		if( verbose && code!=0 )
			Lib.println('  Failed with error code $code');
		return code;
	}


	static function getIgnoredElements() {
		var out = {
			names: [],
			exts: [],
		}

		if( !hasParameter("-ignore") )
			return out;

		if( getParameter("-ignore")==null )
			error("Missing names or extensions after -ignore");

		var parts = getParameter("-ignore").split(",");
		for(p in parts) {
			p = StringTools.trim(p);
			if( p.indexOf("*.")>0 )
				error("Malformed ignored file name: "+p);
			else if( p.indexOf("*.")==0 )
				out.exts.push( p.substr(2) );
			else
				out.names.push(p);
		}
		return out;
	}


	static function copyExtraFilesIn(extraFiles:Array<ExtraCopiedFile>, targetPath:String) {
		if( extraFiles.length==0 )
			return;

		Sys.println("Copying extra files to "+targetPath+"...");

		// Ignored files/dirs
		var ignores = getIgnoredElements();
		ignores.names.push(".tmp");
		ignores.names.push(".git");
		ignores.names.push(".svn");
		Sys.println("  Ignoring: names="+ignores.names+" extensions="+ignores.exts);

		// Copy extra files/dirs
		for(f in extraFiles) {
			if( f.isDir ) {
				// Copy a directory structure
				if( verbose )
					Lib.println(" -> DIRECTORY: "+projectDir+f.source.full+"  =>  "+targetPath);
				FileTools.copyDirectoryRec(f.source.full, targetPath, ignores.names, ignores.exts);

				// Rename
				if( f.rename!=null ) {
					var arr = f.source.getDirectoryArray();
					var folderName = arr[arr.length-1];
					if( verbose )
						Lib.println("   -> renaming "+targetPath+"/"+folderName+" to: "+targetPath+"/"+f.rename);
					sys.FileSystem.rename(targetPath+"/"+folderName, targetPath+"/"+f.rename);
				}
			}
			else {
				// Copy a file
				var to = f.source.fileWithExt;
				if( f.rename!=null )
					to = f.rename;
				if( verbose )
					Lib.println(" -> FILE: "+projectDir+f.source.full+"  =>  "+targetPath+"/"+to);
				copy(projectDir+f.source.full, targetPath+"/"+to);
			}
		}
	}

	static function zipFolder(zipPath:String, basePath:String) {
		if( zipPath.indexOf(".zip")<0 )
			zipPath+=".zip";

		Lib.println("Zipping "+basePath+"...");
		if( !verbose )
			Lib.print(" -> ");

		// List entries
		var entries : List<haxe.zip.Entry> = new List();
		var pendingDirs = [basePath];
		while( pendingDirs.length>0 ) {
			var cur = pendingDirs.shift();
			for( fName in sys.FileSystem.readDirectory(cur) ) {
				var path = cur+"/"+fName;
				if( sys.FileSystem.isDirectory(path) ) {
					pendingDirs.push(path);
					entries.add({
						fileName: path.substr(basePath.length+1) + "/",
						fileSize: 0,
						fileTime: sys.FileSystem.stat(path).ctime,
						data: haxe.io.Bytes.alloc(0),
						dataSize: 0,
						compressed: false,
						crc32: null,
					});
				}
				else {
					var bytes = sys.io.File.getBytes(path);
					entries.add({
						fileName: path.substr(basePath.length+1),
						fileSize: sys.FileSystem.stat(path).size,
						fileTime: sys.FileSystem.stat(path).ctime,
						data: bytes,
						dataSize: bytes.length,
						compressed: false,
						crc32: null,
					});
				}
			}
		}

		// Zip entries
		var out = new haxe.io.BytesOutput();
		for(e in entries)
			if( e.data.length>0 ) {
				if( verbose )
					Sys.println(" -> Compressing: "+e.fileName+" ("+e.fileSize+" bytes)");
				else
					Sys.print("*");
				e.crc32 = haxe.crypto.Crc32.make(e.data);
				haxe.zip.Tools.compress(e,9);
			}
		var w = new haxe.zip.Writer(out);
		w.write(entries);
		Lib.println(" -> Created "+zipPath+" ("+out.length+" bytes)");
		sys.io.File.saveBytes(zipPath, out.getBytes());
	}

	static function findFile(f:String, useHl32bits:Bool) {
		if( sys.FileSystem.exists(redistHelperDir+f) )
			return redistHelperDir+f;

		// Locate haxe tools
		var haxeTools = ["haxe.exe", "hl.exe", "neko.exe" ];
		var paths = [];
		for(path in Sys.getEnv("PATH").split(";")) {
			path = cleanUpDirPath(path);
			for(f in haxeTools)
				if( sys.FileSystem.exists(path+f) ) {
					paths.push(path);
					break;
				}
		}

		if( useHl32bits ) {
			// Prioritize 32bits files over 64bits
			paths.insert(0, redistHelperDir+"redistFiles/hl32/");  // HL
		}
		paths.push(redistHelperDir+"redistFiles/");

		if( paths.length<=0 )
			throw "Haxe tools not found ("+haxeTools.join(", ")+") in PATH!";

		for(path in paths)
			if( sys.FileSystem.exists(path+f) )
				return path+f;

		throw "File not found: "+f+", lookup paths="+paths.join(", ");
	}

	static function cleanUpDirPath(path:String) {
		var fp = FilePath.fromDir(path);
		fp.useSlashes();
		return fp.directoryWithSlash;
	}

	static function initRedistDir(d:String, extraFiles:Array<ExtraCopiedFile>) {
		if( verbose )
			Lib.println("Initializing folder: "+d+"...");
		try {
			// List all extra files, including folders content
			var allExtraFiles = [];
			for(f in extraFiles)
				if( !f.isDir )
					allExtraFiles.push(f.rename!=null ? f.rename : f.source.fileWithExt);
				else {
					var all = FileTools.listAllFilesRec(f.source.full);
					for(f in all.files)
						allExtraFiles.push( FilePath.extractFileWithExt(f) );
				}


			var cwd = StringTools.replace( Sys.getCwd(), "\\", "/" );
			var abs = StringTools.replace( sys.FileSystem.absolutePath(d), "\\", "/" );
			if( abs.indexOf(cwd)<0 || abs==cwd )
				error("For security reasons, target folder should be nested inside current folder.");
			// avoid deleting unexpected files
			directoryContainsOnly(
				d,
				["exe","dat","dll","hdll","ndll","js","swf","html","dylib","zip","lib","bin","bat","pak"],
				allExtraFiles
			);
			FileTools.deleteDirectoryRec(d);
			createDirectory(d);
		}
		catch(e:Dynamic) {
			error("Couldn't initialize dir "+d+". Maybe it's in use or opened somewhere right now?");
		}
	}


	static function getFullHxml(f:String) {
		var lines = sys.io.File.read(f, false).readAll().toString().split(NEW_LINE);
		var i = 0;
		while( i<lines.length ) {

			// trims the comment content from the line.
			var commentHash = lines[i].indexOf("#");
			if( commentHash >= 0 )
				lines[i] = lines[i].substr(0, commentHash);

			if( lines[i].indexOf(".hxml")>=0 && lines[i].indexOf("-cmd")<0 )
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
			error("Couldn't create directory "+path+". Maybe it's in use right now? [ERR:"+e+"]");
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
					error("Output folder \""+path+"\" (which will be deleted) seems to contain unexpected files like "+e);
			}
		}
	}

	static function copy(from:String, to:String) {
		try {
			sys.io.File.copy(from, to);
		}
		catch(e:Dynamic) {
			error("Can't copy "+from+" to "+to+" ("+e+")");
		}
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
			if( p.charAt(0)=="-" ) {
				if( !SINGLE_PARAMETERS.exists(p) )
					ignoreNext = true;
			}
			else if( !ignoreNext )
				all.push(p);
			else
				ignoreNext = false;
		}

		return all;
	}

	// static function getIsolatedParameter(idx:Int) : Null<String> {
	// 	var i = 0;
	// 	var ignoreNext = false;
	// 	for( p in Sys.args() ) {
	// 		if( p.charAt(0)=="-" )
	// 			ignoreNext = true;
	// 		else if( !ignoreNext ) {
	// 			if( idx==i )
	// 				return p;
	// 			i++;
	// 		}
	// 		else
	// 			ignoreNext = false;
	// 	}

	// 	return null;
	// }

	static function usage() {
		Lib.println("");
		Lib.println("USAGE:");
		Lib.println("  haxelib run redistHelper <hxml1> [<hxml2>] [<hxml3>] [customFile1] [customFile2]");
		Lib.println("");
		Lib.println("EXAMPLES:");
		Lib.println("  haxelib run redistHelper myGame.hxml");
		Lib.println("  haxelib run redistHelper myGame.hxml docs/CHANGELOG.md docs/LICENSE");
		Lib.println("  haxelib run redistHelper myGame.hxml docs/README@read_me.txt");
		Lib.println("  haxelib run redistHelper myGame.hxml docs");
		Lib.println("  haxelib run redistHelper myGame.hxml docs -ignore backups,*.zip");
		Lib.println("  haxelib run redistHelper myGame.hxml -sign -pfx path/to/myCertificate.pfx");
		Lib.println("");
		Lib.println("OPTIONS:");
		Lib.println("  -o <outputDir>: change the default redistHelper output dir (default: \"redist/\")");
		Lib.println("  -p <projectName>: change the default project name (if not provided, it will use the name of the parent folder where this script is called)");
		Lib.println("  -icon <iconFilePath>: replace EXE icon (only works for Windows and HL target)");
		Lib.println("  -hl32: when building Hashlink targets, this option will also package a 32bits version of the HL runtime in separate redist folders.");
		Lib.println("  -zip: create a zip file for each build");
		Lib.println("  -ignore <namesOrExtensions>: List of files to be ignored when copying extra directories (typically temp files or similar things). Names should be separated by a comma \",\", no space. To ignore file extensions, use the \"*.ext\" format. See examples.");
		Lib.println("  -pak: generate a PAK file from the existing Heaps resource folder");
		Lib.println("  -sign: code sign the executables using a PFX certificate. A password will be requested to use the certificate. If the -pfx argument is not provided, the PFX path will be looked up in the environment var CSC_LINK. The password will also be looked up in the environment var CSC_KEY_PASSWORD.");
		Lib.println("  -pfx <pathToPfxFile>: Use provided PFX file to sign the executables (implies the use of -sign)");
		Lib.println("  -h: show this help");
		Lib.println("  -v: verbose mode (display more informations)");
		Lib.println("");
		Lib.println("NOTES:");
		Lib.println("  - All specified \"Custom files\" will be copied in each redist folders (can be useful for README, LICENSE, etc.).");
		Lib.println("  - You can specify folders to copy among \"Custom files\".");
		Lib.println("  - Custom files can be renamed after copy, just add \"@\" followed by the final name after the file path. Example:");
		Lib.println("      haxelib run redistHelper myGame.hxml docs/README@read_me.txt");
		Lib.println("      The \"README\" file from docs/ will be renamed to \"read_me.txt\" in the target folder.");
		Lib.println("");
		Sys.exit(0);
	}

	static function error(msg:Dynamic) {
		Lib.println("");
		Lib.println("ERROR - "+Std.string(msg));
		cleanUpExit();
		Sys.exit(1);
	}
}


