import neko.Lib;

class Main {
	static var RUNTIME_FILES = [
		{ dep:null, f:"hl.exe" },
		{ dep:null, f:"libhl.dll" },
		{ dep:null, f:"msvcr120.dll" },
		{ dep:null, f:"fmt.hdll" },
		{ dep:null, f:"ssl.hdll" },

		{ dep:"heaps", f:"OpenAL32.dll" },

		{ dep:"heaps", f:"openal.hdll" },
		{ dep:"heaps", f:"ui.hdll" },
		{ dep:"heaps", f:"uv.hdll" },

		{ dep:"hlsdl", f:"SDL2.dll" },
		{ dep:"hlsdl", f:"sdl.hdll" },

		{ dep:"hlsteam", f:"steam.hdll" },
		{ dep:"hlsteam", f:"steam_api.dll" },

		{ dep:"hldx", f:"directx.hdll" },
		{ dep:"hldx", f:"d3dcompiler_47.dll" },
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

		// Read parameters
		var haxeFolder = Sys.getEnv("HAXEPATH");
		if( haxeFolder==null )
			error("Missing environment variable HAXEPATH.");

		var redistFolder = getParameter("-o");
		if( redistFolder==null )
			redistFolder = "redist";

		if(getParameter("-hl")==null && getParameter("-swf")==null && getParameter("-js")==null )
			error("At least one target parameter is required (-hl, -js or -swf).");

		var projectName = getParameter("-p");
		if( projectName==null )
			projectName = "MyProject";

		// Set CWD to the directory haxelib was called
		var callCwd = getIsolatedParameter(0);
		if( callCwd==null )
			error("Script wasn't called using: haxelib run redistHelper [...]");
		Sys.setCwd(callCwd);

		// Prepare base folder
		Lib.println("Preparing folders...");
		var cwd = StringTools.replace( Sys.getCwd(), "\\", "/" );
		var abs = StringTools.replace( sys.FileSystem.absolutePath(redistFolder), "\\", "/" );
		if( abs.indexOf(cwd)<0 || abs==cwd )
			error("For security reasons, target folder should be nested inside current folder.");
		scanDirectory(redistFolder, ["exe","dat","dll","hdll","js","swf"]); // avoid deleting unexpected files
		removeDirectory(redistFolder);
		createDirectory(redistFolder);

		// HL
		var hxml = getParameter("-hl");
		if( hxml!=null ) {
			// Create folder
			createDirectory(redistFolder+"/"+projectName);

			// Copy runtimes
			Lib.println("Copying HL runtime files...");
			for( r in RUNTIME_FILES ) {
				if( r.dep==null || hxmlRequiresLib(hxml, r.dep) ) {
					Lib.println(" -> "+r.f + ( r.dep==null?"" : " [required by -lib "+r.dep+"]") );
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
		var hxml = getParameter("-js");
		if( hxml!=null ) {
			Lib.println("Building "+hxml+"...");
			Sys.command("haxe", [hxml]);
			var out = getHxmlOutput(hxml,"-js");
			copy(out, redistFolder+"/"+projectName+".js");
			Lib.println("");
		}

		// SWF
		var hxml = getParameter("-swf");
		if( hxml!=null ) {
			Lib.println("Building "+hxml+"...");
			Sys.command("haxe", [hxml]);
			var out = getHxmlOutput(hxml,"-swf");
			copy(out, redistFolder+"/"+projectName+".swf");
			Lib.println("");
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

	static function scanDirectory(path:String, fileExts:Array<String>) {
		if( !sys.FileSystem.exists(path) )
			return;

		for( e in sys.FileSystem.readDirectory(path) ) {
			if( sys.FileSystem.isDirectory(path+"/"+e) )
				scanDirectory(path+"/"+e, fileExts);
			else {
				var extMatched = false;
				for(ext in fileExts)
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
		Lib.println("USAGE - haxelib run redistHelper [-hl <hxml_file>] [-js <hxml_file>] [-swf <hxml_file>] [-o <targetFolder>] [-p <project_name>]");
		Sys.exit(0);
	}

	static function error(msg:Dynamic) {
		Lib.println("");
		Lib.println("ERROR - "+Std.string(msg));
		usage();
	}
}

