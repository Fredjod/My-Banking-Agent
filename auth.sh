#!/bin/bash

### PARAMS ###
# Web Account login for MacOS X using Keychains
KEYCHAIN_SERVICE='Online Bank Account info'

# The user and password values have to be saved in the MacOS X keychains
# The user and password should be stored in the "login" keychain.
# The Name of the keychain item should be 'Online Bank Account info'
### END PARAMS ####

LOGIN=$(security find-generic-password -s "$KEYCHAIN_SERVICE" | perl -lne 'print $1 if /\"acct\"<blob>=\"(.*)\"/')
PASSWORD=$(security find-generic-password -a $LOGIN -w)
### For debug needs
# echo Username: $USER >> logs/out.txt
# security find-generic-password -a $LOGIN -w >>logs/out.txt 2>&1
