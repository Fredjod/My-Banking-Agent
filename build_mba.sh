#!/bin/bash

### PARAMS ###
VERSION=1.1

# Packaging
mkdir mba
mkdir mba/logs
cp -R lib mba/
cp -R properties mba/
cp mbaMain.pl mba/
cp t/t.categories.xls mba/categories.dist.xls
cp auth.sh mba/auth.dist.sh
cp closing.sh mba/
cp control.sh mba/
cp LICENSE mba/
cp README.md mba/
cd t/
perl -w ConfReader.t
perl -w AccountData.t
cd ..
chmod +x mba/closing.sh
chmod +x mba/control.sh
chmod +x mba/properties/installDeamon.sh
chmod +x mba/properties/uninstallDeamon.sh
#zip -yqr mba_$VERSION.zip mba
if [ -e "mba_$VERSION.tar.gz" ]
then
	rm mba_$VERSION.tar.gz
fi
tar -zcf mba_$VERSION.tar.gz mba
rm -r ./mba