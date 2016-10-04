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
1;