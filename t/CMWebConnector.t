#!/usr/bin/perl

use lib "../lib/";

use warnings;
use strict;
use DateTime;
use Helpers::Logger;
use Data::Dumper;

my $logger = Helpers::Logger->new();
my $prop = Helpers::ConfReader->new("properties/app.txt");

# Use the Web connector of the account bank
my $connectorClass = 'WebConnector::'.$prop->readParamValue( 'connector.CREDITMUTUEL');
eval "use $connectorClass";
if( $@ ){
	$logger->print ( "Cannot load $connectorClass: $@", Helpers::Logger::ERROR);
	die("Cannot load $connectorClass: $@");
}
my $connector = $connectorClass->new( $prop->readParamValue( 'website.CREDITMUTUEL') );
die $connectorClass.' is a wrong web connector class. Must inherite from WebConnector::GenericWebConnector'
	unless $connector->isa('WebConnector::GenericWebConnector');

# NEVER COMMIT ON GIT with real values
# ####################################
my $login = 'xxxxxxxxx';
my $password = 'xxxxxxx';
my $accontNum = '06xxx 000xxxxxx xx';
######################################

my ($d,$m,$y) = '01/12/2019' =~ /^([0-9]{2})\/([0-9]{2})\/([0-9]{4})\z/
   or die;
my $dt_from = DateTime->new(
   year      => $y,
   month     => $m,
   day       => $d,
   time_zone => 'local',
);

($d,$m,$y) = '31/12/2019' =~ /^([0-9]{2})\/([0-9]{2})\/([0-9]{4})\z/
   or die;
my $dt_to = DateTime->new(
   year      => $y,
   month     => $m,
   day       => $d,
   time_zone => 'local',
);

$logger->print ( "Log in to CM website", Helpers::Logger::INFO);
my $status = $connector->logIn($login, $password);
if ($status) {
	$logger->print ( "Download and parse bank statement...", Helpers::Logger::INFO);
	my $bankData = $connector->download ( $accontNum, $dt_from, $dt_to, 'ofx' );
	print $bankData;
}
$logger->print ( "Log out from CM website", Helpers::Logger::INFO);
$connector->logOut($login);

