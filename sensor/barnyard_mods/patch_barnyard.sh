#!/bin/bash

echo "I am broken."
exit

if [ -z "$1" -o -z "$2" ]; then
	echo "Usage: $0 /path/to/barnyard /path/to/sguil"
	exit 1
fi

PATH_TO_BARNYARD=$1
PATH_TO_SGUIL=$2

(
	cp $PATH_TO_SGUIL/sensor/barnyard_mods/op_sguil.* $PATH_TO_BARNYARD/src/output-plugins/
	cd $PATH_TO_BARNYARD
	pwd
	patch -p0 < $PATH_TO_SGUIL/sensor/barnyard_mods/barnyard.patch
) && (
	aclocal; autoconf; automake
	echo "Barnyard successfully patched" 
) || (
	echo "Patching failed"
)
