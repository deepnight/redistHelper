# About

A small script to quickly create redistribuable of an existing simple HL/JS/SWF haxe project.

It will copy all the required files in a specified folder ("redist" by default), so you just have to distribute this folder content. Especially useful to package a HashLink (HL) project.

# Install

```
haxelib install redistHelper
```

## Usage

``
haxelib run redistHelper [-o <output_folder>] [-p project_name] [-hl HL_hxml_file] [-js JS_hxml_file] [-swf SWF_hxml_file]
``

## Parameters

 - ``-o <output_folder>`` : specify folder where all redist files will be copied. Note: **this folder and its content will be erased each time the script is ran!** Make sure it doesn't contain important stuff (a few basic checks are done, just in case). Default is "redist".
 - ``-p <project_name>`` : change the file names of each build (like <project_name>.js for JS target or <project_name>.exe for HL). Default is "MyProject".
 - ``-hl <hxml_file>`` : specify the HXML used to build the HL version. It will be parsed and required files (based on all its ``-lib``) will be copied from the ``HAXE`` folder.
 - ``-js <hxml_file>`` : specify the HXML used to build the JS version.
 - ``-swf <hxml_file>`` : specify the HXML used to build the SWF version.

