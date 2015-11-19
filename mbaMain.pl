#!/usr/bin/perl

use lib './lib';

use strict;
use warnings;
use Helpers::Logger;
use Helpers::ConfReader;
use Helpers::Date;
use Helpers::MbaFiles;
use AccountStatement::AccountData;
use AccountStatement::Reporting;

my $logger = Helpers::Logger->new();
my $prop = Helpers::ConfReader->new("properties/app.txt");

$logger->print ( "Start running...", Helpers::Logger::INFO);

my @accountConfigFiles = Helpers::MbaFiles->getAccountConfigFilesName();
my $dth = Helpers::Date->new ();
my $dtPrevMonth = $dth->rollPreviousMonth();
my $dtToday = $dth->getDate();

foreach my $accountConfigFilePath (@accountConfigFiles) {
	my $accountPRM = AccountStatement::AccountData->new ($accountConfigFilePath, $dtPrevMonth);
	my $accountMTD = AccountStatement::AccountData->new ($accountConfigFilePath, $dtToday);
	$logger->print ( 'Processing account '.$accountMTD->getAccountNumber. ' of bank '.$accountMTD->getBankName , Helpers::Logger::INFO);
	my $reportingProcessor = AccountStatement::Reporting->new();
	$reportingProcessor->setAccDataMTD($accountMTD);
	$reportingProcessor->setAccDataPRM($accountPRM);

	# Download actuals
	my $dt_to = $dth->getDate();
	my $dt_from = $dth->getDate();	
	$dt_from->set_day(1);
	if ( ! downloadBankStatementBetweenTwoDate ($accountMTD, $dt_from, $dt_to) ) {
		$logger->print ( $accountMTD->getAccountNumber." can not be loaded", Helpers::Logger::ERROR);
	}
	else {
	
		# Check if the closing report processing is needed
		if (! -e Helpers::MbaFiles->getClosingFilePath($accountPRM) ) {
			$logger->print ( "Closing the previous month", Helpers::Logger::INFO);
			# Build 2 date: 1st and last day of the previous month
			my $dt_from_prm = $dth->rollPreviousMonth();	
			$dt_from_prm->set_day(1);
			my $dt_to_prm = DateTime->last_day_of_month( year => $dt_from_prm->year(), month => $dt_from_prm->month() );
			if ( ! downloadBankStatementBetweenTwoDate ($accountPRM, $dt_from_prm, $dt_to_prm) ) {
				$logger->print ( $accountPRM->getAccountNumber." can not be loaded", Helpers::Logger::ERROR);
			} else {
				$logger->print ( "Processing of the previous month closing report", Helpers::Logger::INFO);
				$reportingProcessor->createPreviousMonthClosingReport();
			}
		}
		
		# Generate the actuals reporting
		$logger->print ( "Processing of the actuals report", Helpers::Logger::INFO);
		$reportingProcessor->createActualsReport();
	
		# Run the balance control
		$logger->print ( "Run the balance control", Helpers::Logger::INFO);
		my $threshold = 100;
		$threshold = ( $dt_to->wday() == 1 ) ? $prop->readParamValue('alert.mondays.threshold') : $prop->readParamValue('alert.daily.threshold');
		$reportingProcessor->controlBalance ($threshold);
	}
	
	$logger->print ( 'End of the account processing '.$accountMTD->getAccountNumber. ' of bank '.$accountMTD->getBankName , Helpers::Logger::INFO);
}
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
		$bankData = $connector->downloadBankStatement ( $account->getAccountNumber(), $dt_from, $dt_to );
	}
	$logger->print ( "Log out", Helpers::Logger::INFO);
	$connector->logOut();
	
	# Process the operations into the accountData object
	$logger->print ( "Parsing of bank data", Helpers::Logger::INFO);
	if (defined $bankData) {
		$account->parseBankStatement($bankData);
		return 1;
	} else {
		return 0;
	}
}
