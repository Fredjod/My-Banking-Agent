#!/usr/bin/perl

use lib './lib';

use strict;
use warnings;
use Helpers::Logger;
use Helpers::ConfReader;
use Helpers::Date;
use Helpers::MbaFiles;
use AccountStatement::CheckingAccount;
use AccountStatement::Reporting;
use AccountStatement::SavingAccount;

my $logger = Helpers::Logger->new();
my $prop = Helpers::ConfReader->new("properties/app.txt");

$logger->print ( "Start running...", Helpers::Logger::INFO);

my @accountConfigFiles = Helpers::MbaFiles->getAccountConfigFilesName();
my $dth = Helpers::Date->new ();
my $dtPrevMonth = $dth->rollPreviousMonth();
my $dtToday = $dth->getDate();

foreach my $accountConfigFilePath (@accountConfigFiles) {
	my $accountPRM = AccountStatement::CheckingAccount->new ($accountConfigFilePath, $dtPrevMonth);
	my $accountMTD = AccountStatement::CheckingAccount->new ($accountConfigFilePath, $dtToday);
	$logger->print ( 'Processing account '.$accountMTD->getAccountNumber. ' of bank '.$accountMTD->getBankName , Helpers::Logger::INFO);
	my $reportingProcessor = AccountStatement::Reporting->new();
	$reportingProcessor->setAccDataMTD($accountMTD);
	$reportingProcessor->setAccDataPRM($accountPRM);

	# Download actuals
	my $dt_to = $dth->getDate();
	my $dt_from = $dth->getDate();	
	$dt_from->set_day(1);
	downloadBankStatementBetweenTwoDate ($accountMTD, $dt_from, $dt_to);
	
	# Check if the closing report processing is needed
	if (! -e Helpers::MbaFiles->getClosingFilePath($accountPRM) ) {
		$logger->print ( "Closing the previous month", Helpers::Logger::INFO);
		# Build 2 date: 1st and last day of the previous month
		my $dt_from_prm = $dth->rollPreviousMonth();	
		$dt_from_prm->set_day(1);
		my $dt_to_prm = DateTime->last_day_of_month( year => $dt_from_prm->year(), month => $dt_from_prm->month() );
		downloadBankStatementBetweenTwoDate ($accountPRM, $dt_from_prm, $dt_to_prm);
		$reportingProcessor->createPreviousMonthClosingReport();
	}
	if (defined $accountMTD->getOperations()) {
		# Generate the actuals reporting
		$logger->print ( "Processing of the actuals report", Helpers::Logger::INFO);
		$reportingProcessor->createActualsReport();
	
		# Run the balance control
		$logger->print ( "Run the balance control", Helpers::Logger::INFO);
		$reportingProcessor->controlBalance ( $dt_to->wday() );
	}
	
	$logger->print ( 'End of the account processing '.$accountMTD->getAccountNumber. ' of bank '.$accountMTD->getBankName , Helpers::Logger::INFO);
}

# Saving report
$logger->print ( "Check if saving report is required.", Helpers::Logger::INFO);
my $saving = AccountStatement::SavingAccount->new( );
$saving->generateLastMonthSavingReport();
$saving->mergeWithPreviousSavingReport();

$logger->print ( "End of running.", Helpers::Logger::INFO);

sub downloadBankStatementBetweenTwoDate {
	my( $account, $dt_from, $dt_to ) = @_;
	# Use the Web connector of the account bank
	my $connectorClass = 'WebConnector::'.$prop->readParamValue( 'connector.'.$account->getBankName() );
	eval "use $connectorClass";
	if( $@ ){
		$logger->print ( "Cannot load $connectorClass: $@", Helpers::Logger::ERROR);
		die("Cannot load $connectorClass: $@");
	}
	my $connector = $connectorClass->new( $prop->readParamValue( 'website.'.$account->getBankName() ));
	die $connectorClass.' is a wrong web connector class. Must inherite from WebConnector::GenericWebConnector'
		unless $connector->isa('WebConnector::GenericWebConnector');

	# Get the auth info from a separated file
	require "auth.pl";
	our %auth;

	# Get the operations from website
	my $bankData;
	$logger->print ( "Log in to ".$account->getBankName()." website", Helpers::Logger::INFO);
	if ( $connector->logIn( $auth{$account->getAccountAuth}[0], $auth{$account->getAccountAuth}[1] ) ) {
		$logger->print ( "Download and parse bank statement for account ".$account->getAccountNumber()." for month ".$account->getMonth->month()."...", Helpers::Logger::INFO);
		$connector->downloadBankStatement ( $account, $dt_from, $dt_to );
	}
	$logger->print ( "Log out", Helpers::Logger::INFO);
	$connector->logOut();
}
