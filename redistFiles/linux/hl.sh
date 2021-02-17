#!/bin/bash
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
