package Helpers::Statement;

use lib "../../lib/";

use warnings;
use strict;

use Helpers::Date;
use Helpers::Logger;
use Helpers::ConfReader;
use Helpers::WebConnector;
use Helpers::MbaFiles;

sub buildCurrentMonthStatement {
	my ($class, $accountConfigFilePath, $currentDate, $authKey) = @_;

	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $logger = Helpers::Logger->new();
	my ($dt_to, $dt_from, $dth);

	if (defined $currentDate) { # $currentDate is used to force a specific date instead of the current system date.
		$dth = Helpers::Date->new($currentDate);
	} else {
		$dth = Helpers::Date->new();	
	}
	$dt_to = $dth->getDate();
	$dt_from = $dth->getDate();
	$dt_from->set_day(1);

	my $statement = AccountStatement::CheckingAccount->new ($accountConfigFilePath, $dt_to, $authKey);

	# Call the web connector of the account bank
	my $connector = Helpers::WebConnector->buildWebConnectorObject ( $statement->getBankName() );
	$statement->parseBankStatement($connector->downloadBankStatement($statement, $dt_from, $dt_to));
	return $statement;
	
}

sub buildPreviousMonthStatement {
	my ($class, $accountConfigFilePath, $currentDate, $forceCacheRefreshing, $authKey) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $logger = Helpers::Logger->new();

	my $dth;
	if (defined $currentDate) { # $currentDate is used to force a specific date instead of the current system date.
		$dth = Helpers::Date->new($currentDate);
	} else {
		$dth = Helpers::Date->new();	
	}	
	my $dt_from = $dth->rollPreviousMonth();
	$dt_from->set_day(1);
	my $dt_to = DateTime->last_day_of_month( year => $dt_from->year(), month => $dt_from->month() );

	my $statement = AccountStatement::CheckingAccount->new ($accountConfigFilePath, $dt_to, $authKey);
	
	# Load statement from previous month cache file
	if ( $statement->loadBankData() and !defined $forceCacheRefreshing) {
		$logger->print ( "Cache of previous month operation is loaded", Helpers::Logger::INFO);
	} else { 
	# or download it from bank website
		my $connector = Helpers::WebConnector->buildWebConnectorObject ( $statement->getBankName() );
		$statement->parseBankStatement($connector->downloadBankStatement($statement, $dt_from, $dt_to));
		$statement->saveBankData();
	}
	
	return $statement;
}

sub buildYTDStatement {
	my ( $class, $accountConfigFilePath, $PRMStat, $authKey ) = @_;

	my $statement = AccountStatement::CheckingAccount->new ($accountConfigFilePath, $PRMStat->getMonth(), $authKey);	
	my $yearlyFilePath = Helpers::MbaFiles->getYearlyClosingFilePath ( $statement );
	# Filling the statement operations
	$class->loadOperationsFromDetailsSheet ( $yearlyFilePath, $statement, $PRMStat->getMonth() );
	$statement->mergeWithAnotherStatement($PRMStat);
	return $statement;
}

sub loadOperationsFromDetailsSheet {
	my( $class, $path, $statement, $dt ) = @_;
	my $tabDetails;
	if (-e $path ) { # Reading the content of the existing yearly file.
		my $workbook = Helpers::ExcelWorkbook->openExcelWorkbook( $path );	
		my $worksheet = $workbook->worksheet(2); # operation details	
		$tabDetails = Helpers::ExcelWorkbook->readFromExcelSheetDetails ($worksheet);
	}
	my $monthToExlude = "NA";
	if (defined $dt) { # month/year to exclude from bankData. Useful when closing report is re-generated
		$monthToExlude = sprintf ("%02d/%4d", $dt->month(), $dt->year() );
	}
	
	# Filling the statement operations
	my @bankData;

	if (defined $tabDetails) {
		for my $row ( 1 .. $#{$tabDetails} ) { # skipping the first line containing the column headers
			my %record;
			if (defined @$tabDetails[$row]->[0]) {
				if (@$tabDetails[$row]->[0]->{value} =~ qr[^(\d{1,2})/(\d{1,2})/(\d{4})$]) { #date column?
					if ($monthToExlude ne sprintf ("%02d/%4d", $2, $3) ) {
						$record{'DATE'} = @$tabDetails[$row]->[0]->{value};
					} else { next; }
				} else { next; }
			} else { next; }
			if ( defined @$tabDetails[$row]->[1] ) { # Debit?
				if ( @$tabDetails[$row]->[1]->{unformatted} =~ /^[+-]?\d+(\.\d+)?$/ ) { # currency column?
					$record{'AMOUNT'} = @$tabDetails[$row]->[1]->{unformatted};
				} else { next; }
			} elsif ( defined @$tabDetails[$row]->[2]) { # Credit?
				if ( @$tabDetails[$row]->[2]->{unformatted} =~ /^[+-]?\d+(\.\d+)?$/ ) { # currency column?
					$record{'AMOUNT'} = @$tabDetails[$row]->[2]->{unformatted};
				} else { next; }
			} else {next; }
			
			if ( defined @$tabDetails[$row]->[5] ) { # Details?
				$record{'DETAILS'} = @$tabDetails[$row]->[5]->{value};
			} else {next; }
			if ( defined @$tabDetails[$row]->[6] ) { # Balance?
				if ( @$tabDetails[$row]->[6]->{unformatted} =~ /^[+-]?\d+(\.\d+)?$/ ) { # currency column?
					$record{'BALANCE'} = @$tabDetails[$row]->[6]->{unformatted};
				} else { next; }
			} else { next; }
			
			push (@bankData, \%record);
		}
	}
	$statement->parseBankStatement(\@bankData);
}

sub checkBalanceIntegrity {
	# Check whether final previous month balance is equal to the starting current month balance
	# This problem happens time to time when previous month transactions are recorded by bank system
	# after the first day of the current month, kind of "anti-dated" transactions.
	# In that case, the closing process needs to be relauched.
	# closing report and yearly report are regenerated
	# the forecasted report is renamed, because could have been updated by user. A new one is regenerated.
	
	my ( $class, $accountConfigFilePath, $MTDStat, $PRMStat, $authKey ) = @_;
	my $newPRMStatement = $PRMStat;
	my $logger = Helpers::Logger->new();
	my $ops = $MTDStat->getOperations();
	if (defined $ops) { # The integrity test is done only if current month has transactions.
		my $initialMTDBalance = @$ops[0]->{SOLDE} - ( 
			( ( defined @$ops[0]->{DEBIT} ) ? @$ops[0]->{DEBIT} : 0 ) + 
			( ( defined @$ops[0]->{CREDIT} ) ? @$ops[0]->{CREDIT} : 0 )
			);
		
		if (abs($PRMStat->getBalance() - $initialMTDBalance) > 0.009 ) { # Integrity check failed
			$logger->print ( "Balances integrity testing failded. PRM: ".$PRMStat->getBalance()." / MTD: ".$initialMTDBalance." Diff: ".abs($PRMStat->getBalance() - $initialMTDBalance), Helpers::Logger::ERROR);
			$logger->print ( "Balances integrity testing failded: Previous month closing is rebuilding", Helpers::Logger::INFO);
			$newPRMStatement = $class->buildPreviousMonthStatement ($accountConfigFilePath, $MTDStat->getMonth(), 1, $authKey); # Force the cache refreshing
			if ( -e Helpers::MbaFiles->getClosingFilePath( $PRMStat ) ) {
				$logger->print ( "Balances integrity failded: Deleting the obsoleted previous month closing report", Helpers::Logger::INFO);
				unlink glob Helpers::MbaFiles->getClosingFilePath( $PRMStat );
			}
			if ( -e Helpers::MbaFiles->getForecastedFilePath ($MTDStat)) {
				$logger->print ( "Balances integrity failded: The forecasted report is renamed for saving any user manual updates", Helpers::Logger::INFO);
				rename Helpers::MbaFiles->getForecastedFilePath($MTDStat), Helpers::MbaFiles->getForecastedFilePath($MTDStat)."_obsoleted.xls";
			}
		}
		else {
			$logger->print ( "Balances integrity testing succeded", Helpers::Logger::DEBUG);
		}
	}
	return $newPRMStatement;
}

1;