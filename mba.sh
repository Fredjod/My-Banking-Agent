#!/bin/bash

### PARAMS ###
# Web Account login
LOGIN=0603920712304

# The password value has to be saved in the MacOS X keychains
# The password should be stored in the "login" keychain.
# The "Account Name" of the keychain item should be the web account login
### END PARAMS ####

PASSWORD=$(security find-generic-password -a $LOGIN -w)
cd $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
perl mbaMain.pl -login $LOGIN -password $PASSWORD