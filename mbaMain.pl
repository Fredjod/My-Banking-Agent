#!/usr/bin/perl

use lib './lib';

use strict;
use warnings;
use Helpers::Logger;
use AccountStatement::AccountData;
my $connectorClass = 'WebConnector::'.'CMWebConnector';
eval "use $connectorClass";
if( $@ ){
	die("Cannot load $connectorClass: $@");
}
my $connector = $connectorClass->new( 'https://www.creditmutuel.fr/' );
die $connectorClass.' is a wrong web connector class. Must inherite from WebConnector::GenericWebConnector' unless $connector->isa('WebConnector::GenericWebConnector');

my $logger = Helpers::Logger->new();

$logger->print ( "Start running...", Helpers::Logger::INFO);

my $cvsFilePathOpt='';
my $helpOpt=0;
my $mclosingOpt=0;
my $loginOpt;
my $passwordOpt;

for (my $i=0; $i<=$#ARGV;$i++) {
	if ($ARGV[$i] eq '-mclosing') { $mclosingOpt = 1; }	
	if ($ARGV[$i] eq '-csvFile') {$cvsFilePathOpt = $ARGV[$i+1]; }
	if ($ARGV[$i] eq '-h' or $ARGV[$i] eq '-help') {$helpOpt = 1; }
	if ($ARGV[$i] eq '-login') {$loginOpt = $ARGV[$i+1]; }
	if ($ARGV[$i] eq '-password') {$passwordOpt = $ARGV[$i+1]; }
}

if ($helpOpt) {
	print "Usage: ./mbaMain.pl options\n";
	print "Options are:\n";
	print "\t-h or -help: print this help.\n";
	print "\t-mclosing: for closing the past month.\n";
	print "\t-csvFile pathfile: for setting the full path of CSV data file. Default: Download from Bank website.\n";
	print "End of execution.\n";
	exit 0;
}

# Define 1st and last day of the previous month
my $dt_from = DateTime->now(time_zone => 'local' );
my $month = $dt_from->month();
# Todo: gerer le cas de janvier => decembre de l'annee precedente
$dt_from->set_month($month-1);
$dt_from->set_day(1);
my $dt_to = DateTime->last_day_of_month( year => $dt_from->year(), month => $dt_from->month() );

# Init the Account Data object.
my $account = AccountStatement::AccountData->new ();

# Get the operations
my $bankData;
$logger->print ( "Log in to ".$account->getBankName()." website", Helpers::Logger::INFO);
$connector->logIn($loginOpt,$passwordOpt);
$logger->print ( "Download and parse bank statement for account ".$account->getAccountNumber()."...", Helpers::Logger::INFO);
$bankData = $connector->downloadBankStatement ( $account->getAccountNumber(), $dt_from, $dt_to );
$logger->print ( "Log out", Helpers::Logger::INFO);
$connector->logOut();


# Process the operations and generate the dashboard
$logger->print ( "Parsing of bank data", Helpers::Logger::INFO);
$account->parseBankStatement($bankData);
$logger->print ( "Generate dashboard", Helpers::Logger::INFO);
$account->generateDashBoard();
$logger->print ( "End of running.", Helpers::Logger::INFO);