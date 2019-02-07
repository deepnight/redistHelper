# About

A small script to quickly create redistribuable of an existing simple HL/JS/SWF haxe project.

It will copy all the required files in a specified folder ("redist" by default), so you just have to distribute this folder content. Especially useful to package a HashLink (HL) project.

# Install

```
haxelib install redistHelper
```

## Usage

```
USAGE:
    haxelib run redistHelper [-o <outputFolder>] [-p <project_name>] [<hxml1>] [<hxml2>] [<hxml3>]
NOTES:
    If no HXML is given, the script will pick all HXMLs found in current directory.
    If no Project Name is set, the current folder name will be used.
EXAMPLES:
    haxelib run redisHelper      // automatically finds HXMLs and build them into ./redist/
    haxelib run redisHelper hashlink.hxml -o someFolder -p MyGreatGame
    haxelib run redisHelper hashlink.hxml flash.hxml webgl.hxml
```

## Parameters

 - ``-o <output_folder>`` : specify folder where all redist files will be copied. Note: **this folder and its content will be erased each time the script is ran!** Make sure it doesn't contain important stuff (a few basic checks are done, just in case). Default is "redist".
 - ``-p <project_name>`` : change the file names of each build (like <project_name>.js for JS target or <project_name>.exe for HL). Default is the current folder name.
 - ``<hxml_N>`` : depending on the target as defined inside the HXML, all the corresponding runtime files will be created in the ``output_folder``. You can pass multiple HXML files (separated by a space) to package multiple builds in one pass. Supports JS, HL and SWF target so far. If you don't give any HXML parameter, the script will just explore current folder to gather them. Only HXMLs with compatible output will be used.

