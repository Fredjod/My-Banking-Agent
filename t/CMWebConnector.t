#!/usr/bin/perl

use lib "../lib/";

use warnings;
use DateTime;

my $connectorClass = 'WebConnector::'.'CMWebConnector';
eval "use $connectorClass";
if( $@ ){
 die("Cannot load $connectorClass: $@");
}
my $connector = $connectorClass->new( 'https://www.creditmutuel.fr/' );
die $connectorClass.' is a wrong web connector class. Must inherite from WebConnector::GenericWebConnector' unless $connector->isa('WebConnector::GenericWebConnector');

my ($d,$m,$y) = '01/05/2015' =~ /^([0-9]{2})\/([0-9]{2})\/([0-9]{4})\z/
   or die;
my $dt_from = DateTime->new(
   year      => $y,
   month     => $m,
   day       => $d,
   time_zone => 'local',
);

($d,$m,$y) = '28/05/2015' =~ /^([0-9]{2})\/([0-9]{2})\/([0-9]{4})\z/
   or die;
my $dt_to = DateTime->new(
   year      => $y,
   month     => $m,
   day       => $d,
   time_zone => 'local',
);

$connector->logIn('user','password');
print $connector->downloadCSV('accountnumber', $dt_from, $dt_to);
$connector->logOut();