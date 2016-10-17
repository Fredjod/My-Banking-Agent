package Helpers::Statement;

use lib "../../lib/";

use warnings;
use strict;

use Helpers::Date;
use Helpers::Logger;
use Helpers::ConfReader;
use Helpers::WebConnector;

sub buildCurrentMonthStatement {
	my ($class, $accountConfigFilePath, $currentDate) = @_;

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

	my $statement = AccountStatement::CheckingAccount->new ($accountConfigFilePath, $dt_to);

	# Call the web connector of the account bank
	my $connector = Helpers::WebConnector->buildWebConnectorObject ( $statement->getBankName() );
	$statement->parseBankStatement($connector->downloadBankStatement($statement, $dt_from, $dt_to));
	return $statement;
	
}

sub buildPreviousMonthStatement {
	my ($class, $accountConfigFilePath, $currentDate) = @_;
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

	my $statement = AccountStatement::CheckingAccount->new ($accountConfigFilePath, $dt_to);
	
	# Load statement from previous month cache file
	if ( $statement->loadBankData() ) {
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
	my ( $class, $accountConfigFilePath, $PRMStat ) = @_;

	my $statement = AccountStatement::CheckingAccount->new ($accountConfigFilePath, $PRMStat->getMonth());	
	my $yearlyFilePath = Helpers::MbaFiles->getYearlyClosingFilePath ( $statement );
	# Filling the statement operations
	$class->loadOperationsFromDetailsSheet ($yearlyFilePath, $statement);
	$statement->mergeWithAnotherStatement($PRMStat);
	return $statement;
}

sub loadOperationsFromDetailsSheet {
	my( $class, $path, $statement ) = @_;
	my $tabDetails;
	if (-e $path ) { # Reading the content of the existing yearly file.
		my $workbook = Helpers::ExcelWorkbook->openExcelWorkbook( $path );	
		my $worksheet = $workbook->worksheet(1); # operation details	
		$tabDetails = Helpers::ExcelWorkbook->readFromExcelSheetDetails ($worksheet);
	}
	# Filling the statement operations
	my @bankData;

	if (defined $tabDetails) {
		for my $row ( 1 .. $#{$tabDetails} ) { # skipping the first line containing the column headers
			my %record;
			if (defined @$tabDetails[$row]->[0]) {
				if (@$tabDetails[$row]->[0]->{value} =~ qr[^(\d{1,2})/(\d{1,2})/(\d{4})$]) { #date column?
					$record{'DATE'} = @$tabDetails[$row]->[0]->{value};
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

1;