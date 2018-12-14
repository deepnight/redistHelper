# About

A small script to quickly create redistribuable of an existing simple HL/JS/SWF haxe project.

It will copy all the required files in a specified folder ("redist" by default), so you just have to distribute this folder content. Especially useful to package a HashLink (HL) project.

# Install

```
haxelib install redistHelper
```

## Usage

``
haxelib run redistHelper [-o <outputFolder>] [-p <project_name>] <hxml_1> [<hxml_2>] [<hxml_3>]
``

Example:
``
haxelib run redistHelper -p SomeGreatGame build_hl.hxml build_js.hxml build_swf.hxml
``


## Parameters

 - ``-o <output_folder>`` : specify folder where all redist files will be copied. Note: **this folder and its content will be erased each time the script is ran!** Make sure it doesn't contain important stuff (a few basic checks are done, just in case). Default is "redist".
 - ``-p <project_name>`` : change the file names of each build (like <project_name>.js for JS target or <project_name>.exe for HL). Default is "MyProject".
 - ``<hxml_N>`` : depending on the target as defined inside the HXML, all the corresponding runtime files will be created in the ``output_folder``. You can pass multiple HXML files (separated by a space) to package multiple builds in one pass. Supports JS, HL and SWF target so far.

