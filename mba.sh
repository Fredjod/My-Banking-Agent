#!/bin/bash
PERL_HOME=/home/mbahome/localperl
OC_HOME=/var/www/oc


cd $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
$PERL_HOME/bin/perl mbaMain.pl
php $OC_HOME/occ files:scan --all