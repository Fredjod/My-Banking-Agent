#!/bin/bash

### PARAMS ###
VERSION=1.0


# Packaging
mkdir mba
cp -R lib mba/
cp -R properties mba/
cp mbaMain.pl mba/
cp mba.sh mba/
cp LICENSE mba/
cp README.md mba/
cd t/
perl -w ConfReader.t
perl -w AccountData.t
cd ..
#zip -yqr mba_$VERSION.zip mba
tar -zcf mba_$VERSION.tar.gz mba
rm -r ./mba

# deploy in /Users/home/Documents/
mv mba_$VERSION.tar.gz /Users/home/Documents/
cd /Users/home/Documents/
gunzip -c mba_$VERSION.tar.gz | tar xopf -
chmod +x mba/mba.sh
rm mba_$VERSION.tar.gz