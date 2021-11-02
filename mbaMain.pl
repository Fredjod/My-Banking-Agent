#!/usr/bin/perl

use lib './lib';

use strict;
use warnings;
use Helpers::Logger;
use Helpers::ConfReader;
use Helpers::MbaFiles;
use Helpers::Statement;
use AccountStatement::CheckingAccount;
use AccountStatement::Reporting;
use AccountStatement::SavingAccount;

my $logger = Helpers::Logger->new();
my $prop = Helpers::ConfReader->new("properties/app.txt");

$logger->print ( "Start running...", Helpers::Logger::INFO);

my @accountConfigFiles = Helpers::MbaFiles->getAccountConfigFilesName();
foreach my $accountConfigFilePath (@accountConfigFiles) {
	
	my $accountPRM = Helpers::Statement->buildPreviousMonthStatement($accountConfigFilePath);
	my $accountMTD = Helpers::Statement->buildCurrentMonthStatement($accountConfigFilePath);

	$logger->print ( 'Processing account '.$accountMTD->getAccountNumber. ' of bank '.$accountMTD->getBankName , Helpers::Logger::INFO);

	# Check the balance Integrity
	$accountPRM = Helpers::Statement->checkBalanceIntegrity($accountConfigFilePath, $accountMTD, $accountPRM);
	
	# create the reporting processor
	my $reportingProcessor = AccountStatement::Reporting->new($accountPRM, $accountMTD);
	
	# Check if the closing report processing is needed
	if (! -e Helpers::MbaFiles->getClosingFilePath($accountPRM) ) {
		$logger->print ( "Processing the previous month closing report", Helpers::Logger::INFO);
		$reportingProcessor->createPreviousMonthClosingReport();
		$logger->print ( "Processing the yearly closing report", Helpers::Logger::INFO);
		my $accountYTD = Helpers::Statement->buildYTDStatement($accountConfigFilePath, $accountPRM);
		$reportingProcessor->createYearlyClosingReport($accountYTD);
		if ( $accountMTD->getCategoriesBudgetToFollow ) { # This account uses web report interface
			$reportingProcessor->computeCurrentMonthBudgetObjective();
		}
	}
	
	# Check if the forecasted report processing is needed
	if (! -e Helpers::MbaFiles->getForecastedFilePath ($accountMTD)) {
		$logger->print ( "Processing the forecasted cashflow report", Helpers::Logger::INFO);
		$reportingProcessor->createForecastedCashflowReport();
	}
	
	if (defined $accountMTD->getOperations()) { #if there is at least 1 operation in the current month statement
		# Generate the actuals reporting
		$logger->print ( "Processing the actuals report", Helpers::Logger::INFO);
		$reportingProcessor->createActualsReport();
	
		# Generate JSON Files for Web report interface
		if ( $accountMTD->getCategoriesBudgetToFollow ) { # This account uses web report interface
			if (! -e Helpers::MbaFiles->getCurrentMonthCacheObjectiveFilePath ($accountMTD)) {
				$reportingProcessor->computeCurrentMonthBudgetObjective();
			}
			$reportingProcessor->generateJSONWebreport();
		}
	
		# Run the balance control
		$logger->print ( "Run the balance check", Helpers::Logger::INFO);
		$reportingProcessor->controlBalance ();
	}
	
	$logger->print ( 'End of the account processing '.$accountMTD->getAccountNumber. ' of bank '.$accountMTD->getBankName , Helpers::Logger::INFO);
}

# Bank Saving report
$logger->print ( "Check if saving report is required.", Helpers::Logger::INFO);
my $saving = AccountStatement::SavingAccount->new( );
$saving->generateLastMonthSavingReport();

# End of the script
$logger->print ( "End of running.", Helpers::Logger::INFO);
