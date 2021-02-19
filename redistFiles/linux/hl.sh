#!/bin/bash
# One problem with laucnhing the hl executable without arguments (so it defaults to hlboot.dat)
# is that it doesn't work if it is launched from another directory
# This is hardly a problem in Windows since most apps are laucnhed by double-clicking on them
# (so the working directory is the one where the executable is) but in Linux it is very common
# to launch apps from another directory. Execute this script instead so there's no problems
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
LD_LIBRARY_PATH=$SCRIPTPATH:$LD_LIBRARY_PATH ./$SCRIPTNAME
