#!/bin/bash

source $(dirname $0)/auth.sh

if [ -n "$LOGIN" ] && [ -n "$PASSWORD" ]
then
	CMD=dcontrol
	if [ $1 = "weekly" ]
	then
		CMD=wcontrol
	fi
	cd $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
	perl mbaMain.pl -cmd $CMD -login $LOGIN -password $PASSWORD
else
	echo "ERR: Website user and password can't be read from Mac OS X keychain. Not found Service is: '$KEYCHAIN_SERVICE'." 
fi