#!/usr/bin/perl

use lib './lib';

use strict;
use warnings;
use Helpers::Logger;
use Helpers::ConfReader;
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

my $helpOpt=0;
my $OperationOpt='';
my $loginOpt;
my $passwordOpt;

for (my $i=0; $i<=$#ARGV;$i++) {
	if ($ARGV[$i] eq '-h' or $ARGV[$i] eq '-help') {$helpOpt = 1; }
	if ($ARGV[$i] eq '-cmd') {$OperationOpt = $ARGV[$i+1]; }
	if ($ARGV[$i] eq '-login') {$loginOpt = $ARGV[$i+1]; }
	if ($ARGV[$i] eq '-password') {$passwordOpt = $ARGV[$i+1]; }
}

if ($helpOpt) {
	print "Usage: ./mbaMain.pl options\n";
	print "Options are:\n";
	print "\t-h or -help: print this help.\n";
	print "\t-cmd { closing, control }: for closing the past month or for controling the balance of current month is as planned.\n";
	print "End of execution.\n";
	exit 0;
}

if ($OperationOpt eq "closing") {
	$logger->print ( "Closing the previous month", Helpers::Logger::INFO);
	# Build 2 date: 1st and last day of the previous month
	my $dt_from = DateTime->now(time_zone => 'local' );
	my $month = $dt_from->month();
	my $year = $dt_from->year();
	# first day of last month
	if ($month > 1) {
		$dt_from->set_month($month-1);
	} else { # shift to december of previous year
		$dt_from->set_month(12);
		$dt_from->set_year($year-1)
	}
	$dt_from->set_day(1);
	my $dt_to = DateTime->last_day_of_month( year => $dt_from->year(), month => $dt_from->month() );
	my $account = buildBankStatement ($dt_from, $dt_to);
	$logger->print ( "Generate dashboard", Helpers::Logger::INFO);
	$account->generateDashBoard();
}
elsif ( ($OperationOpt eq "wcontrol") || ($OperationOpt eq "dcontrol") ) {
	$logger->print ( "Controling the variation between current and planned balance", Helpers::Logger::INFO);
	# Downloading the bankstatement from the 1st of the current month till now
	my $dt_from = DateTime->now(time_zone => 'local' );
	$dt_from->set_day(1);
	my $dt_to = DateTime->now(time_zone => 'local' );
	my $account = buildBankStatement ($dt_from, $dt_to);
	$logger->print ( "Control the balance", Helpers::Logger::INFO);
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $thresold = ($OperationOpt eq "wcontrol") ? $prop->readParamValue('alert.weekly.threshold') : $prop->readParamValue('alert.daily.threshold');
	my $negative = ( $prop->readParamValue('alert.weekly.threshold') eq 'on' );
	$account->controlBalance($thresold, $negative);
}
else {
	$logger->print ( "No operation requested. Did nothing!", Helpers::Logger::ERROR);	
}
$logger->print ( "End of running.", Helpers::Logger::INFO);

sub buildBankStatement {
	my( $dt_from, $dt_to ) = @_;
	# Init the Account Data object.
	my $account = AccountStatement::AccountData->new ();
	
	# Get the operations of previous month
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
	return $account;
}
