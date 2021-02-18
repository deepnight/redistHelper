#!/bin/bash
# On Windows, hl.exe will use hlboot.dat automatically if not provided any argument
# Doesn't appear to work on Linux but a simple script can do it
# As a bonus the script itself will give executable permissions to the executable
# (However there doesn't appear to be any way to ensure this script itself is executable,
# so the user will have to make this script executable before being able to use it)
# Absolute path to this script, e.g. /home/user/bin/foo.sh
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in, thus /home/user/bin
SCRIPTPATH=$(dirname "$SCRIPT")
cd $SCRIPTPATH
SCRIPTNAME=`basename -s ".sh" $0`
if test ! -x $SCRIPTNAME
then
  chmod +x $SCRIPTNAME
fi
./$SCRIPTNAME hlboot.dat
