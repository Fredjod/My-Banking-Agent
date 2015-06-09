#!/usr/bin/perl

use lib "../lib/";

use warnings;
use DateTime;
use Helpers::Logger;
use Data::Dumper;

my $logger = Helpers::Logger->new();

my $connectorClass = 'WebConnector::'.'CMWebConnector';
eval "use $connectorClass";
if( $@ ){
	$logger->print ( "Cannot load $connectorClass: $@", Helpers::Logger::ERROR);
	die("Cannot load $connectorClass: $@");
}
my $connector = $connectorClass->new( 'https://www.creditmutuel.fr/' );
unless ( $connector->isa('WebConnector::GenericWebConnector') ) {
	$logger->print ( "$connectorClass is a wrong web connector class. Must inherite from WebConnector::GenericWebConnector", Helpers::Logger::ERROR);
	die "$connectorClass is a wrong web connector class. Must inherite from WebConnector::GenericWebConnector";
}

my ($d,$m,$y) = '01/05/2015' =~ /^([0-9]{2})\/([0-9]{2})\/([0-9]{4})\z/
   or die;
my $dt_from = DateTime->new(
   year      => $y,
   month     => $m,
   day       => $d,
   time_zone => 'local',
);

($d,$m,$y) = '31/05/2015' =~ /^([0-9]{2})\/([0-9]{2})\/([0-9]{4})\z/
   or die;
my $dt_to = DateTime->new(
   year      => $y,
   month     => $m,
   day       => $d,
   time_zone => 'local',
);

$logger->print ( "Log in to CM website", Helpers::Logger::INFO);
$connector->logIn('user','password');
$logger->print ( "Log in to CM website", Helpers::Logger::INFO);
$logger->print ( "Download and parse bank statement...", Helpers::Logger::INFO);
my $bankData = $connector->downloadBankStatement ( 'bankaccount', $dt_from, $dt_to );
$logger->print ( "Log out to CM website", Helpers::Logger::INFO);
$connector->logOut();
print Dumper $bankData;
