### Install Perl and some additional CPAN modules. Even if perl is already installed, I recommend to have your own installation for the adding of modules.
wget http://www.cpan.org/src/5.0/perl-5.22.0.tar.gz
tar -xzf perl-5.22.0.tar.gz
cd perl-5.22.0
./Configure -des -Dprefix=$HOME/localperl
make
make install
cd $HOME
./localperl/bin/cpan App::cpanminus
# The following external modules are required
./localperl/bin/cpanm DateTime 
./localperl/bin/cpanm Archive::Zip
./localperl/bin/cpanm LWP::UserAgent
./localperl/bin/cpanm LWP::Protocol::https
./localperl/bin/cpanm Parse::Decrescent
./localperl/bin/cpanm Spreadsheet::ParseExcel
./localperl/bin/cpanm Spreadsheet::XLSX
./localperl/bin/cpanm Spreadsheet::WriteExcel
./localperl/bin/cpanm MIME::Lite
du -h ./localperl
# 97M
# Then unzip the MBA distribution, where xxx is the release number.
tar xzvf mba_xxx.tar.gz
chmod 775 mba/accounts/
du -h ./mba
# 2.9M
# Installation is done 