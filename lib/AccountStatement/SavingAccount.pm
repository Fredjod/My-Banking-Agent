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
    my ($class) = @_;
    # $class->SUPER::new(@_);
    my $prop = Helpers::ConfReader->new("properties/app.txt");
    my $logger = Helpers::Logger->new();
    my @balances = ();
    my @operations = ();
    
    my $self = {
    	_accountReferences => undef, # array of references for opening accounts
    	_balances => \@balances, # array of balances
    	_operations => \@operations, # array of operations
    	_month => undef,
    	_total => 0,
    };
    bless $self, $class;

    my @config = Helpers::MbaFiles->getAccountConfigFilesName( $prop->readParamValue('saving.config.pattern') );
    if ($#config == -1) {
    	$logger->print ( "No config file found for saving accounts", Helpers::Logger::ERROR);
    }
    else {
    	$logger->print ( "Opening account config file: ". $config[0], Helpers::Logger::DEBUG);
    	$self->{_accountReferences} = initReferences($config[0]);
    }
    return $self;  
}

sub generateLastMonthSavingReport {
	my ( $self ) = @_;
	my $logger = Helpers::Logger->new();
	
	unless (defined $self->getAccountReferences) {
		$logger->print ( "No saving account references available.", Helpers::Logger::ERROR);
		return;
	}
	my $dt_from = Helpers::Date->new ();
	$dt_from = $dt_from->rollPreviousMonth();
	$self->{_month} = $dt_from;
	my $path = Helpers::MbaFiles->getSavingFilePath ( $dt_from );
	my $dt_to = DateTime->last_day_of_month( year => $dt_from->year(), month => $dt_from->month() );;
    if (-e $path) {
    	$logger->print ( "The saving report $path already exists", Helpers::Logger::DEBUG);
    }
    else {
     	$logger->print ( "Start previous month saving reporting...", Helpers::Logger::INFO);
    	$self->loadOperationsAndBalances($dt_from, $dt_to);
    	$self->storeToExcel ($path, $dt_from);
    }
}

sub mergeWithPreviousSavingReport {
	my ( $self ) = @_;
	my $dtPrevReporting = Helpers::Date->new ( self->getMonth() );
	$dtPrevReporting->rollPreviousMonth();
	my $path = Helpers::MbaFiles->getSavingFilePath ( $dtPrevReporting );
	
	
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
	my ( $self, $dt_from, $dt_to ) = @_;
    my $prop = Helpers::ConfReader->new("properties/app.txt");
    my $logger = Helpers::Logger->new();
	my $ref = $self->getAccountReferences();

	
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
		my $operations = $self->getOperations();
		@$operations = sort { $a->{'DATE'} cmp $b->{'DATE'}  } @$operations;
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

sub storeToExcel {
	my( $self, $path, $dt_from) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $logger = Helpers::Logger->new();
	my $wb_out = Helpers::ExcelWorkbook->createWorkbook ( $path );
	my $currency_format = $wb_out->add_format( num_format => eval($prop->readParamValue('workbook.dashboard.currency.format')));
	my $date_format = $wb_out->add_format(num_format => $prop->readParamValue('workbook.dashboard.date.format'));

	my $ws_out = $wb_out->add_worksheet( "Solde" );
	my $bal = $self->getBalances();

	$ws_out->write( 0, 2, $dt_from->month() );
	foreach my $i (0 .. $#{$bal}) {
		$ws_out->write( $i+1, 0,  @$bal[$i]->{NUMBER});
		$ws_out->write( $i+1, 1,  @$bal[$i]->{NAME});
		$ws_out->write( $i+1, 2,  @$bal[$i]->{BALANCE}, $currency_format);
	}
	$ws_out->set_column(0, 0,  18);	
	$ws_out->set_column(1, 1,  35);
	$ws_out->set_column(2, 2,  10);
	
	my $ope = $self->getOperations();
	$ws_out = $wb_out->add_worksheet( "Details" );
	$ws_out->write( 0, 0, "DATE" );
	$ws_out->write( 0, 1, "DEBIT" );
	$ws_out->write( 0, 2, "CREDIT" );
	$ws_out->write( 0, 3, "ACCOUNT NUMBER" );
	$ws_out->write( 0, 4, "ACCOUNT NAME" );
	$ws_out->write( 0, 5, "DETAILS" );
	
		
	foreach my $i (0 .. $#{$ope}) {
		$ws_out->write_date_time( $i+1, 0,  @$ope[$i]->{DATE}, $date_format);
		(@$ope[$i]->{TYPE} == AccountStatement::Account::EXPENSE) ? 
			$ws_out->write( $i+1, 1,  @$ope[$i]->{AMOUNT}, $currency_format) :
			$ws_out->write( $i+1, 2,  @$ope[$i]->{AMOUNT}, $currency_format);
		$ws_out->write( $i+1, 3,  @$ope[$i]->{NUMBER});
		$ws_out->write( $i+1, 4,  @$ope[$i]->{NAME});
		$ws_out->write( $i+1, 5,  @$ope[$i]->{DETAILS});
	}
	$ws_out->set_column(1, 3,  12);	
	$ws_out->set_column(3, 3,  18);
	$ws_out->set_column(4, 5,  35);
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

sub getTotal {
	my ( $self ) = @_;
	return $self->{_total};
}

sub getMonth {
	my ( $self ) = @_;
	return $self->{_month};
}


1;