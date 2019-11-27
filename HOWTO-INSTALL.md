#Pre-requisite
The only pre-requisite of this installation guide, is to have an Unbutu instance like.

# Installation Guide
This presents the complete installation guide for all the required applications: Apache, MySQL, PHP, Owncloud and Perl.
You can bypass some of those steps depending on your current system conf. 

First, make sure that the system is uptodate:

    $ sudo apt-get update
    $ sudo apt-get upgrade
    
## Install Apache, MariaDB, PHP and required PHP modules

    $ sudo apt-get install apache2 mariadb-server libapache2-mod-php5
    $ sudo apt-get install php5-gd php5-json php5-mysql php5-curl
    $ sudo apt-get install php5-intl php5-mcrypt php5-imagick

## Install Owncloud
Latest release: [https://owncloud.org/install/#instructions-server](https://owncloud.org/install/#instructions-server)

    $ sudo wget https://download.owncloud.org/community/owncloud-9.0.2.zip
    $ sudo unzip owncloud-9.0.2.zip
    $ sudo cp -r owncloud /path/to/webserver/document-root/oc

where /path/to/webserver/document-root is replaced by the document root of your Web server:

    $ sudo cp -r owncloud /var/www
    
Then change the owner/group of your owncloud directory to the system web user (assuming the user is www-data):

    $ sudo chown -R www-data /var/www/oc
    $ sudo chgrp -R www-data /var/www/oc  
    
##  Install Perl and required CPAN modules
Even if Perl is installed by default on your Ubuntu distribution, I recommend to have your own installation for adding modules without impacting the default Perl installation of your system.
We recommend to install it your your own unix user

Latest release: [http://www.cpan.org/src/](http://www.cpan.org/src/)

    $ sudo wget http://www.cpan.org/src/5.0/perl-5.24.0.tar.gz
    $ sudo tar -xzf perl-5.24.0.tar.gz
    $ sudo cd perl-5.24.0
    $ sudo ./Configure -des -Dprefix=$HOME/localperl
    $ sudo make
    $ sudo make install
    $ sudo cd $HOME
    $ sudo ./localperl/bin/cpan App::cpanminus

The following external modules are required

    $ sudo ./localperl/bin/cpanm DateTime 
    $ sudo ./localperl/bin/cpanm Archive::Zip
    $ sudo ./localperl/bin/cpanm LWP::UserAgent
    $ sudo ./localperl/bin/cpanm LWP::Protocol::https
    $ sudo ./localperl/bin/cpanm Spreadsheet::ParseExcel
    $ sudo ./localperl/bin/cpanm Spreadsheet::XLSX
    $ sudo ./localperl/bin/cpanm Spreadsheet::WriteExcel
    $ sudo ./localperl/bin/cpanm MIME::Lite

The Perl installation size is about 97MB

    $ sudo du -h ./localperl

And then make sure that any unix user can execute it:

    $ sudo chmod -R 755 ./localperl

## Docker variant

Change directory to the My-Banking-Agent root project dir and type the following command for executing the provided Dockerfile:

	$ docker build -t mba .

Then for running a unit test on your local machine:

	$ docker run -it --rm -v $(pwd):/usr/src/mba -w /usr/src/mba/t mba perl -w ConfReader.t 

## MyBankingAgent installation
Then unzip the MBA distribution, where xxx is the release number. The MBA files will have to be read/write by Apache/Owncloud process, thus the owner should be the system web user (assuming here www-data) 
We recommand to install MBA at the same level than webserver document root (assuming here /var): 

    $ cd /var
    $ sudo mkdir mba
    $ cd mba/
    $ sudo tar xzvf mba_xxx.tar.gz
 
 Then give the appropriate user privilege
 
    $ sudo chown -R www-data -R /var/mba
    $ sudo chgrp -R www-data  /var/mba
    
The MyBankingAgent (MBA) size is about 2MB

    $ sudo du -h ./mba

** Installation part is done!** Let's start the configuration...

# MyBankingAgent run configuration

### Banking authentification

Connect as www-data user and then 

    $ cp /var/mba/auth.dist.pl auth.pl
    $ chmod 600 auth.pl
    $ vi auth.pl
    
Change the login and password of the bank logins that you want to use. You can add any login as needed.

    our %auth = (
	 'MARC.KEY' => ['marc_login', 'marc_pwd'],
	 'SOPHIE.KEY' => ['sophie_login', 'sophie_pwd'],	
	);

### MBA run variables

    PERL_HOME=/home/mbahome/localperl
    OC_HOME=/var/www/oc


### MBA properties

Email


### Crontab

    $ crontab -e

    # m h  dom mon dow   command
    15  *  *  *  * php -f /var/www/oc/cron.php > /dev/null 2>&1
    30 20 * * * /var/mba/mba.sh > /tmp/mbalog.txt 2>&1

# Apache configuration

Assuming the you already have a webserver running, you have nothing special todo, if you have installed as mention above owncloud in your existing Documentroot.

It is strongly recommend to enable the SSL on your server:

    $ sudo a2enmod ssl
    $ sudo a2ensite default-ssl
    $ sudo service apache2 reload 

# Owncloud configuration

If this is your first owncloud installation, you have to connect to your server and follow the online wizard (setting up the admin, password, etc...)

Below, few hints for a minimal configuration.
The full documentation of Owncloud is [https://doc.owncloud.org/](https://doc.owncloud.org/)

In order to allow the connection to Owncloud server, a setup the configuration file config.php wiht your favorite text editor
Connect as tje webserver user (assuming www-data) and open the file

    $ vi /var/www/oc/config/config.php
 
 Below the file content (values are for illustration only). In the default file provided in the owncloud installation, you have to change the trusted_domains, datadirectory and overwrite.cli.url sections: 
    
    <?php
      $CONFIG = array (
      'instanceid' => 'ocSdskdd0zid9hv',
      'passwordsalt' => 'Aecch2FDMTDxsVDDSJK8QGRZBagKC/ZM',
	  'secret' => 'u6yROp+gIpKMp9jOdjklsIJkljdJYo09aAmoY+5//iSsy0',
	  'trusted_domains' => array (
        0 => '192.168.1.5',
        1 => 'home.sample.fr',
        2 => '80.59.182.86',
      ),
     'datadirectory' => '/var/owncloud/data',
     'overwrite.cli.url' => '/oc',
     'dbtype' => 'sqlite3',
     'version' => '8.1.1.3',
     'logtimezone' => 'UTC',
     'installed' => true,
    );   

By default, the Owncloud data directory is within the webserver document root. For avoiding any unwanted access to your data, the recommendation is to move the data directory out from the document root and update its path as mention above in the datadirectoy section.

    $ mv -R /var/www/oc/data /var/owncloud/data

This is the point where we can declare the access to the MBA file via Owncloud, as shown below, with "External Storage" module using the "local" storage. There are at list 2 directories:

* MBA Reporting: it contains all the reports generated by MBA (in a daily basis)
* MBA Accounts: it contains the bank accounts setup

![config Owncloud-MBA](./occonf.tiff)

Create additional owncloud login, according your needs, and then you can use any of the Owncloud client (Desktop or Mobile apps) for read and editing your MBA files. 
