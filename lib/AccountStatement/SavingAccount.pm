package AccountStatement::SavingAccount;

use lib '../../lib';
use parent 'AccountStatement::Account';

use strict;
use warnings;
use DateTime;
use Helpers::ConfReader;
use utf8;
use Helpers::Logger;
use Helpers::Date;
use Helpers::ExcelWorkbook;
use Helpers::WebConnector;
use Spreadsheet::ParseExcel;

sub new {
    my ($class, $savingConfigFilePath, $dtMonth) = @_;
    # $class->SUPER::new(@_);
    # my $prop = Helpers::ConfReader->new("properties/app.txt");
    my $logger = Helpers::Logger->new();
    $logger->print ( "Opening account config file: $savingConfigFilePath", Helpers::Logger::DEBUG);
    my @balances = ();
    my @operations = ();
    
    my $self = {
    	_accountReferences => initReferences ( $savingConfigFilePath ), # array of references for opening accounts
    	_balances => \@balances, # array of balances
    	_operations => \@operations, # array of operations
    	_month => $dtMonth,
    	_total => 0,
    };
    bless $self, $class;
    
    $self->loadOperationsAndBalances ();
    
    return $self;  
}

sub initReferences {
	my ($savingConfigFilePath) = @_;
	my $workbook = Helpers::ExcelWorkbook->openExcelWorkbook( $savingConfigFilePath );	
	my $worksheet = $workbook->worksheet( 0 );		
	my ( $row_min, $row_max ) = $worksheet->row_range();
	my @ref;
	my $value;
	my $row;
	for $row ( $row_min .. $row_max ) {
		my $cell = $worksheet->get_cell( $row, 0 );
		next unless $cell;
		my %record;
		$record{'BANK'} = $worksheet->get_cell( $row, 0 )->unformatted();
		$record{'KEY'} = $worksheet->get_cell( $row, 1 )->unformatted();
		$record{'NUMBER'} = $worksheet->get_cell( $row, 2 )->unformatted();
		$record{'DESC'} = $worksheet->get_cell( $row, 3 )->unformatted();
		push (@ref, \%record);
	}
	@ref = sort { $a->{'BANK'} cmp $b->{'BANK'} || $a->{'KEY'} cmp $b->{'KEY'} } @ref;
	return \@ref;
}

sub loadOperationsAndBalances {
	my ( $self ) = @_;
    my $prop = Helpers::ConfReader->new("properties/app.txt");
    my $logger = Helpers::Logger->new();
	my $ref = $self->getAccountReferences();
	my $dt_from = $self->getMonth();
	$dt_from->set_day(1);
	my $dth = Helpers::Date->new ();
	my $dt_to = $dth->getDate();
	
	my $i = 0;
	while ( $i<$#{$ref}+1 ) {
		my $bankname;
		my $authKey;
		my $connector;
		$bankname = @$ref[$i]->{'BANK'};
		$authKey = @$ref[$i]->{'KEY'};			
		$connector = Helpers::WebConnector->buildWebConnectorObject ($bankname);
		my $bankData;
		$logger->print ( "Log in to ".$bankname." website", Helpers::Logger::INFO);
		if ( $connector->logIn(  Helpers::WebConnector->getLogin ($authKey),  Helpers::WebConnector->getPwd ($authKey) ) ) {
			do {
				$logger->print ( "Download and parse bank statement for account ".@$ref[$i]->{'DESC'}." for month ".$dt_from->month()."...", Helpers::Logger::INFO);
				my $balance = $connector->downloadBalance ( @$ref[$i]->{'NUMBER'}, $dt_from, $dt_to );
				my $bankOpe = $connector->downloadOperations ( @$ref[$i]->{'NUMBER'}, $dt_from, $dt_to );
				$self->addSavingRecord ($bankOpe, @$ref[$i]->{'NUMBER'}, @$ref[$i]->{'DESC'}, $balance);
				$i++;
			} while ( $i<$#{$ref}+1 && @$ref[$i]->{'BANK'} eq $bankname && @$ref[$i]->{'KEY'} eq $authKey);
		}
		$logger->print ( "Log out", Helpers::Logger::INFO);
		$connector->logOut();
	}	
}

sub addSavingRecord {
	my ( $self, $bankOpe, $accountNumber, $accountName, $balance ) = @_;
	my $logger = Helpers::Logger->new();
	my $operations = $self->getOperations();
	my $balances = $self->getBalances();

	foreach my $line (@$bankOpe) {
		my %record;
		$record {DATE} = $line->{DATE};
		$record {TYPE} = ( $line->{AMOUNT} < 0 ? AccountStatement::Account::EXPENSE : AccountStatement::Account::INCOME );
		$record {AMOUNT} = $line->{AMOUNT};
		$record {NUMBER} = $accountNumber;
		$record {NAME} = $accountName;
		$record {DETAILS} = $line->{DETAILS};
		push ($operations, \%record);
	}
	my %record;
	$record {NUMBER} = $accountNumber;
	$record {NAME} = $accountName;
	$record {BALANCE} = $balance;
	push ($balances, \%record);
	$self->{_total} += $balance;
}

sub getAccountReferences {
	my ( $self ) = @_;
	return $self->{_accountReferences};
}

sub getOperations {
	my ( $self ) = @_;
	return $self->{_operations};
}

sub getBalances {
	my ( $self ) = @_;
	return $self->{_balances};
}

sub getMonth {
	my ( $self ) = @_;
	return $self->{_month};
}

sub getTotal {
	my ( $self ) = @_;
	return $self->{_total};
}

1;