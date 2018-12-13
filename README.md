# About

TODO

## Usage

`` 
haxelib run redistHelper -o <target_folder> [-p project_name] [-hl HL_hxml_file] [-js JS_hxml_file] [-swf SWF_hxml_file] 
`` 

## Parameters
 - ``-o <target_folder>`` : specify folder where all redist files will be copied. Note: **this folder and its content will be erased each time the script is ran!** Make sure it doesn't contain important stuff.
 - ``-p <project_name>`` : change the file names of each build (like <project_name>.js for JS target or <project_name>.exe for HL)
 - ``-hl <hxml_file>`` : specify the HXML used to build the HL version. It will be parsed and required files (based on all its ``-lib``) will be copied from the ``HAXE`` folder.
 - ``-js <hxml_file>`` : specify the HXML used to build the JS version.
 - ``-swf <hxml_file>`` : specify the HXML used to build the SWF version.
 
