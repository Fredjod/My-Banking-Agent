#!/bin/bash

### PARAMS ###
VERSION=2.2

# Run unit testing
echo '--- Unit testing... ---'
cd t/
perl -w ConfReader.t
perl -w DateHelper.t
perl -w AccountData.t
perl -w AccountReporting.t
perl -w MbaFiles.t
cd ..

# Packaging
echo '--- Packaging... ---'
mkdir mba
mkdir mba/logs
mkdir mba/accounts
cp -R lib mba/
cp -R properties mba/
mv mba/properties/app.txt mba/properties/app.dist.txt 
cp mbaMain.pl mba/
cp mba.sh mba/
cp t/accounts/config.033033050050029.xls mba/accounts/dist.config.033033050050029.xls
cp auth.pl mba/auth.dist.pl
cp LICENSE mba/
cp README.md mba/
chmod +x mba/mbaMain.pl
chmod +x mba/mba.sh
chmod +x mba/properties/installDeamon.sh
chmod +x mba/properties/uninstallDeamon.sh
#zip -yqr mba_$VERSION.zip mba
if [ -e "mba_$VERSION.tar.gz" ]
then
	rm mba_$VERSION.tar.gz
fi
tar -zcf mba_$VERSION.tar.gz mba
echo '--- Package mba_'$VERSION'.tar.gz ready --- '
rm -r ./mba