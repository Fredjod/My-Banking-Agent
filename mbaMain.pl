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

$logger->print ( "##### Start running...", Helpers::Logger::INFO);

# Get authentication key from command line, 1st param.
my $authKey = undef;
if ($#ARGV == 0) { $authKey = $ARGV[0] };

my @accountConfigFiles = Helpers::MbaFiles->getAccountConfigFilesName();
foreach my $accountConfigFilePath (@accountConfigFiles) {
	
	$logger->print ( '>>>> Loading statement from config file: '.$accountConfigFilePath , Helpers::Logger::INFO);
		
	my $accountPRM = Helpers::Statement->buildPreviousMonthStatement($accountConfigFilePath, undef, undef, $authKey);
	my $accountMTD = Helpers::Statement->buildCurrentMonthStatement($accountConfigFilePath, undef, $authKey);

	$logger->print ( 'Processing account '.$accountMTD->getAccountNumber. ' of bank '.$accountMTD->getBankName , Helpers::Logger::INFO);


	# Check the balance Integrity
	$accountPRM = Helpers::Statement->checkBalanceIntegrity($accountConfigFilePath, $accountMTD, $accountPRM, $authKey);
	
	# create the reporting processor
	my $reportingProcessor = AccountStatement::Reporting->new($accountPRM, $accountMTD);
	
	# Check if the closing report processing is needed
	if (! -e Helpers::MbaFiles->getClosingFilePath($accountPRM) ) {
		$logger->print ( "Processing the previous month closing report", Helpers::Logger::INFO);
		$reportingProcessor->createPreviousMonthClosingReport();
		$logger->print ( "Processing the yearly closing report", Helpers::Logger::INFO);
		my $accountYTD = Helpers::Statement->buildYTDStatement($accountConfigFilePath, $accountPRM, $authKey);
		$reportingProcessor->createYearlyClosingReport($accountYTD);
		if ( defined $accountMTD->getCategoriesBudgetToFollow ) { # This account uses web report interface
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
		if ( defined $accountMTD->getCategoriesBudgetToFollow ) { # This account uses web report interface
			if (! -e Helpers::MbaFiles->getCurrentMonthCacheObjectiveFilePath ($accountMTD)) {
				$reportingProcessor->computeCurrentMonthBudgetObjective();
			}
			$reportingProcessor->generateJSONWebreport();
		}
	
		# Run the balance control
		$logger->print ( "Run the balance check", Helpers::Logger::INFO);
		$reportingProcessor->controlBalance ();
	}
	
	$logger->print ( '<<<<< End of the account processing '.$accountMTD->getAccountNumber. ' of bank '.$accountMTD->getBankName , Helpers::Logger::INFO);
}

# Bank Saving report
$logger->print ( "Check if saving report is required.", Helpers::Logger::INFO);
my $saving = AccountStatement::SavingAccount->new( $authKey );
$saving->generateLastMonthSavingReport($authKey);

# End of the script
$logger->print ( "##### End of running.", Helpers::Logger::INFO);
