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
use Spreadsheet::WriteExcel::Utility;
use Data::Dumper;

sub new {
    my ($class ) = @_;
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


sub generateLastMonthSavingReport {
	my ( $self, $dt ) = @_;
	my $logger = Helpers::Logger->new();
	
	unless (defined $self->getAccountReferences) {
		$logger->print ( "No saving account references available.", Helpers::Logger::ERROR);
		return;
	}
	my $dth = Helpers::Date->new ($dt); #if $dt is undef, return the current date.
	my $dt_from = $dth->rollPreviousMonth();
	$self->{_month} = $dt_from;
	my $path = Helpers::MbaFiles->getSavingFilePath ( $dt_from );
	my $dt_to = DateTime->last_day_of_month( year => $dt_from->year(), month => $dt_from->month() );;
    if (-e $path) {
    	$logger->print ( "The saving report $path already exists", Helpers::Logger::DEBUG);
    }
    else {
     	$logger->print ( "Generate previous month saving reporting...", Helpers::Logger::INFO);
    	$self->loadOperationsAndBalances($dt_from, $dt_to);
    	$self->mergeWithPreviousSavingReport();
    	Helpers::MbaFiles->deleteOldSavingFiles ($dt_from);
    }
}

sub mergeWithPreviousSavingReport {
	my ( $self ) = @_;
	my $logger = Helpers::Logger->new();
	my $pathCurr = Helpers::MbaFiles->getSavingFilePath ( $self->getMonth() );
	my $dth = Helpers::Date->new ( $self->getMonth() );
	my $dtPrevReporting = $dth->rollPreviousMonth();
	my $pathPrev = Helpers::MbaFiles->getSavingFilePath ( $dtPrevReporting );
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	
	if (-e $pathPrev) { # if previous saving report exists, starting of the merge, otherwise, do nothing.
		$logger->print ( "Merging of the 2 last saving reporting", Helpers::Logger::INFO);
		my $maxHistoryBalanceInMonth = $prop->readParamValue('saving.history.balance.max');
		my $maxHistoryDetailsInLine = $prop->readParamValue('saving.history.details.max');
		
		# Reading the content of the previous saving report
		my $wb = Helpers::ExcelWorkbook->openExcelWorkbook($pathPrev);
		my $ws = $wb->worksheet( 0 ); # Balance sheet
		my $prevBalanceSheet = $self->readFromExcelSheetBalance ($ws, $maxHistoryBalanceInMonth+2, undef);
		$ws = $wb->worksheet( 1 ); # Details sheet
		my $prevDetails = Helpers::ExcelWorkbook->readFromExcelSheetDetails ($ws, undef, $maxHistoryDetailsInLine+1);
				
		my $balances = $self->getBalances();
		my $prevAccList = @$prevBalanceSheet[0];
		
		# Merge balances current and prev
		foreach my $ip (0 .. $#{$prevAccList}) {
			my $found = 0;
			foreach my $ic (0 .. $#{$balances}) {
				if (@$balances[$ic]->{NUMBER} eq @$prevAccList[$ip]) {
					$found = 1;
					last;
				}
			}
			if (! $found) {
				my %record;
				$record {NUMBER} = @$prevAccList[$ip];
				$record {NAME} = @$prevBalanceSheet[1]->{'NAME '.@$prevAccList[$ip]};
				$record {BALANCE} = undef;
				push ($balances, \%record);				
			}
		}
		$self->storeToExcel ( $pathCurr, $dth->getDate(), $prevBalanceSheet, $prevDetails );
	} else {
		$self->storeToExcel ( $pathCurr, $dth->getDate() );
	}	
}

sub readFromExcelSheetBalance {
	my ( $self, $ws ) = @_;
	my ( $row_min, $row_max ) = $ws->row_range();
	my ( $col_min, $col_max ) = $ws->col_range();
	my @tabSheet = ();
	# Populate a data structure as followed
	# ( [
	#		('04043 40040043 40', '04043 40040042 45', ...)
	#	],
	#	[
	#		{MONTH}->12
	#		{BALANCE 04043 40040043 40}->132343.49
	#		{NAME 04043 40040043 40}->COMPTE EPARGNE LOGEMENT
	#		{BALANCE 04043 40040042 45}->4343.30
	#		{NAME 04043 40040042 45}->LIVRET BLEU
	#		{BALANCE 04043 40040045 46}->143.14
	#		...
	# 	],
	#	[
	#		{MONTH}->11
	#		..
	#	]
	#	...
	# )
	my @accList = ();
	for my $row ( 1 .. $row_max - 1 ) {
		my $cell_num = $ws->get_cell ($row, 0);
		if (defined $cell_num) {
			push (@accList, $cell_num->value());
		}
	}
	push (@tabSheet, \@accList);
	for my $col ( 2 .. $col_max ) {
		my %month;
		$month{MONTH} = $ws->get_cell( 0, $col )->value();
		for my $row ( 1 .. $row_max - 1 ) {
			my $cell_num = $ws->get_cell ($row, 0);
			my $cell_name = $ws->get_cell( $row, 1 );	
			my $cell_bal = $ws->get_cell( $row, $col );	
			if (defined $cell_num) {
				$month{ 'NAME '. $cell_num->value() } = ( defined $cell_name ? $cell_name->value() : undef );
				$month{ 'BALANCE '. $cell_num->value() } = ( defined $cell_bal ? $cell_bal->unformatted() : undef );				
			}
		}
		push (@tabSheet, \%month);
	}
	return \@tabSheet;
}


sub loadOperationsAndBalances {
	my ( $self, $dt_from, $dt_to ) = @_;
    my $prop = Helpers::ConfReader->new("properties/app.txt");
    my $logger = Helpers::Logger->new();
	my $ref = $self->getAccountReferences();
	
	my $i = 0;
	while ( $i<$#{$ref}+1 ) {
		my $bankname = @$ref[$i]->{'BANK'};
		my $authKey = @$ref[$i]->{'KEY'};
		my $connector = Helpers::WebConnector->buildWebConnectorObject ($bankname);
		my @listOfAccountToDownloadInOneLogin;
		do {
			push (@listOfAccountToDownloadInOneLogin, @$ref[$i]);
			$i++;
		} while ( $i<$#{$ref}+1 && @$ref[$i]->{'BANK'} eq $bankname && @$ref[$i]->{'KEY'} eq $authKey);
		my $result = $connector->downloadMultipleBankStatement(\@listOfAccountToDownloadInOneLogin, $dt_from, $dt_to);
		for my $record ( @$result ) {
			$self->addSavingRecord ($record->{'BANKOPE'}, $record->{'NUMBER'}, $record->{'DESC'}, $record->{'BALANCE'});
		}		
	}	
	my $operations = $self->getOperations();
	@$operations = sort { join('', (split '/', $b->{'DATE'})[2,1,0]) cmp join('', (split '/', $a->{'DATE'})[2,1,0]) } @$operations;
	
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
	my( $self, $path, $dt_from, $tabPrevBal, $tabPrevDet ) = @_;
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
	$ws_out->write_formula ($#{$bal}+2, 2, '=SUM(C2:C'.($#{$bal}+2).')');
	
	my $numberOfMonth = 0;
	if ( defined $tabPrevBal ) {
		foreach my $j (1 .. $#{$tabPrevBal}) {
			$ws_out->write( 0, 2+$j,  @$tabPrevBal[$j]->{MONTH});
			foreach my $i (0 .. $#{$bal}) {
				$ws_out->write( $i+1, 2+$j,  @$tabPrevBal[$j]->{'BALANCE '. @$bal[$i]->{NUMBER} }, $currency_format);
			}
			my $excelTopRef = xl_rowcol_to_cell(1, 2+$j);
			my $excelDownRef = xl_rowcol_to_cell($#{$bal}+1, 2+$j);
			$ws_out->write_formula ($#{$bal}+2, 2+$j, '=SUM('.$excelTopRef.':'.$excelDownRef.')' );
		}
		$numberOfMonth += $#{$tabPrevBal};
	}
	
	$ws_out->set_column(0, 0,  18);	
	$ws_out->set_column(1, 1,  65);
	$ws_out->set_column(2, $numberOfMonth+2,  12);
	$ws_out->set_zoom(90);
	
	my $ope = $self->getOperations();
	$ws_out = $wb_out->add_worksheet( "Details" );
	$ws_out->write( 0, 0, "DATE" );
	$ws_out->write( 0, 1, "DEBIT" );
	$ws_out->write( 0, 2, "CREDIT" );
	$ws_out->write( 0, 3, "ACCOUNT NUMBER" );
	$ws_out->write( 0, 4, "ACCOUNT NAME" );
	$ws_out->write( 0, 5, "DETAILS" );
	
	my $lastrow = 0;	
	foreach my $i (0 .. $#{$ope}) {
		@$ope[$i]->{DATE} =~ qr[^(\d{1,2})/(\d{1,2})/(\d{4})$];  #date column
		my $date = sprintf "%4d-%02d-%02dT", $3, $2, $1;
		$ws_out->write_date_time( $i+1, 0, $date, $date_format);
		(@$ope[$i]->{TYPE} == AccountStatement::Account::EXPENSE) ? 
			$ws_out->write( $i+1, 1,  @$ope[$i]->{AMOUNT}, $currency_format) :
			$ws_out->write( $i+1, 2,  @$ope[$i]->{AMOUNT}, $currency_format);
		$ws_out->write( $i+1, 3,  @$ope[$i]->{NUMBER});
		$ws_out->write( $i+1, 4,  @$ope[$i]->{NAME});
		$ws_out->write( $i+1, 5,  @$ope[$i]->{DETAILS});
		$lastrow = $i+1;
	}
	
	my $row=0;
	if (defined $tabPrevDet) {
		for $row ( 1 .. $#{$tabPrevDet} ) { # skipping the first line containing the column headers
			for my $col ( 0 .. $#{@$tabPrevDet[$row]} ) {
				if (defined @$tabPrevDet[$row]->[$col]) {
					if (@$tabPrevDet[$row]->[$col]->{value} =~ qr[^(\d{1,2})/(\d{1,2})/(\d{4})$]) { #date column?
						my $date = sprintf "%4d-%02d-%02dT", $3, $2, $1;
						$ws_out->write_date_time($lastrow+$row, $col, $date, $date_format);
					}
					elsif ( @$tabPrevDet[$row]->[$col]->{unformatted} =~ /^[+-]?\d+(\.\d+)?$/ ) { # currency column?
						$ws_out->write( $lastrow+$row, $col, @$tabPrevDet[$row]->[$col]->{unformatted}, $currency_format ); 
					}
					else {
						$ws_out->write( $lastrow+$row, $col, @$tabPrevDet[$row]->[$col]->{value} );
					}
				}
			}
		}
	}
	$ws_out->autofilter(0, 0, $lastrow+$row, 5);
	$ws_out->set_column(0, 0,  10);	
	$ws_out->set_column(1, 3,  12);	
	$ws_out->set_column(3, 3,  18);
	$ws_out->set_column(4, 4,  65);
	$ws_out->set_column(5, 5,  45);
	$ws_out->set_zoom(80);
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