### Install Perl and some additional CPAN modules. Even if perl is already install, I recommend to have your own installation for the adding of modules.
wget http://www.cpan.org/src/5.0/perl-5.22.0.tar.gz
tar -xzf perl-5.22.0.tar.gz
cd perl-5.22.0
./Configure -des -Dprefix=$HOME/localperl
make
make install
./localperl/bin/cpan App::cpanminus
./localperl/bin/cpanm DateTime 
./localperl/bin/cpanm Archive::Zip
./localperl/bin/cpanm LWP::UserAgent
./localperl/bin/cpanm LWP::Protocol::https
./localperl/bin/cpanm Parse::Decrescent
94Mo