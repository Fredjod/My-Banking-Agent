#!/bin/bash

### PARAMS ###
VERSION=3.6

# Run unit testing
echo '--- Unit testing... ---'

cd t/
testFilesArray=( "ConfReader.t"
				"DateHelper.t"
				"MbaFiles.t" 
				"CheckingAccount.t"
				"PlannedOperation.t"
				"Reporting1.t"
				"Reporting2.t"
				"Reporting3.t"
				"SavingAccount.t"
				)

for file in "${testFilesArray[@]}"
do
	perl -w $file
	if [ $? -gt 0 ]
	then
		echo !!!!! $file FAILED !!!!
	exit 1
	fi
done

cd ..

# Packaging
echo '--- Packaging... ---'
mkdir mba
mkdir mba/logs
mkdir mba/accounts
mkdir mba/reporting
cp -R lib mba/
cp -R properties mba/
mv mba/properties/app.txt mba/properties/app.dist.txt 
cp mbaMain.pl mba/
cp mba.sh mba/
cp t/accounts/config.0303900020712303.xls mba/accounts/dist.config.0303900020712303.xls
cp t/reporting/0303900020712303/dist.planned_operations.xls mba/reporting/dist.planned_operations.xls
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
cd mba
tar -zcf ../mba_$VERSION.tar.gz ./*
echo '--- Package mba_'$VERSION'.tar.gz is ready --- '
cd ..
rm -r ./mba