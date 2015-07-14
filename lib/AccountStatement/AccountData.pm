package AccountStatement::AccountData;

use lib '../../lib';
use strict;
use warnings;
use DateTime;
use Helpers::ExcelWorkbook;
use Spreadsheet::ParseExcel;
use Spreadsheet::XLSX;
use Spreadsheet::WriteExcel;
#use Excel::Writer::XLSX;
use Spreadsheet::WriteExcel::Utility;
use Helpers::ConfReader;
use utf8;
use Data::Dumper;
use Helpers::Logger;

use constant INCOME		=> 1;
use constant EXPENSE	=> 2;

sub new
{
    my ($class) = @_;
    
    my $prop = Helpers::ConfReader->new("properties/app.txt");
    my $self = {
    	_bankName => initBankName($prop),
    	_accountNumber =>	initAccountNumber($prop),
    	_accountDesc =>	initAccountDesc($prop),
    	_categories => 	initCategoriesDefinition($prop),
    	_operations => undef
    };
    if ( !defined $self->{_accountNumber} ) { die "bank account number value not found!"; }
    bless $self, $class;
    return $self;
}

sub initAccountDesc {
	my ($prop) = @_;
	return lookForPairKeyValue($prop, $prop->readParamValue("account.desc.label"));	
}

sub initAccountNumber {
	my ($prop) = @_;
	return lookForPairKeyValue($prop, $prop->readParamValue("account.number.label"));
}

sub initBankName {
	my ($prop) = @_;
	return lookForPairKeyValue($prop, $prop->readParamValue("bank.name.label"));	
	
}

sub lookForPairKeyValue {
	my ($prop, $key) = @_;
	my $workbook = Helpers::ExcelWorkbook->openExcelWorkbook($prop->readParamValue("workbook.categories.path"));	
	my $worksheet = $workbook->worksheet($prop->readParamValue("worksheet.categories.name"));		
	my ( $row_min, $row_max ) = $worksheet->row_range();
	my $value;
	my $row;
	for $row ( $row_min .. $row_max ) {
		my $cell = $worksheet->get_cell( $row, 0 );
		next unless $cell && uc $cell->unformatted() eq $key;
		$value = $worksheet->get_cell( $row, 1 )->unformatted();
		last;
	}
	return $value;	
}

sub initCategoriesDefinition {
	my ($prop) = @_;
	my $workbook = Helpers::ExcelWorkbook->openExcelWorkbook($prop->readParamValue("workbook.categories.path"));	
	my $worksheet = $workbook->worksheet($prop->readParamValue("worksheet.categories.name"));		
	my ( $row_min, $row_max ) = $worksheet->row_range();
	my @categories;
	push (@categories, undef); # The index 0 is used to store the incomes default caterory
	push (@categories, undef); # The index 1 is used to store the expenses default caterory
	
	for my $row ( $row_min .. $row_max ) {
		next unless ($worksheet->get_cell( $row, 0 ) && $worksheet->get_cell( $row, 1 ));
		my $operationType = validateFamily($prop, $worksheet->get_cell( $row, 0 )->value());
		if ($operationType == 0 ) { next; }
		
		my %record;
		$record{FAMILY} = $worksheet->get_cell( $row, 0 )->value();
		$record{CATEGORY} = $worksheet->get_cell( $row, 1 )->value();
		$record{TYPEOPE} = $operationType;
		$record{KEYWORDS} = ();
		if ( defined $worksheet->get_cell( $row, 2 )) {
			my @list = map { trim($_) } split(',', $worksheet->get_cell( $row, 2 )->value());
			$record{KEYWORDS} = \@list;
		}
		if ($#{$record{KEYWORDS}} == -1) {
			push (@categories, \%record);
		} else {
			if (uc ${$record{KEYWORDS}}[0] eq uc $prop->readParamValue("operation.keyword.default")) {
				if ($record{TYPEOPE} eq INCOME ) {
					$categories[0] = \%record;
				}
				else {
					$categories[1] = \%record;
				}
			} else {
				push (@categories, \%record);
			}
		}
	}
	return \@categories;	
}

sub validateFamily {
	# validate if the family exists and whether its a income or an expense family.
	# Return 0 for unknown family, return INCOME for an income family, EXPENSE for expense family.
	my( $prop, $family ) = @_;
	my $operationType = 0;
	my $incomeFamilies = $prop->readParamValueList("income.families");
	foreach my $item (@$incomeFamilies) {
		next unless uc $item eq uc $family;
		$operationType = INCOME;
		last;
	}
	if ($operationType == 0) {
		my $expenseFamilies = $prop->readParamValueList("expense.families");
		foreach my $item (@$expenseFamilies) {
			next unless uc $item eq uc $family;
			$operationType = EXPENSE;
			last;
		}
	}
	return $operationType;
}

sub trim {
	my ($str) = @_;
	return $str =~ s/^\s+|\s+$//gr;
}

sub parseBankStatement {
	my( $self, $bankData) = @_;
	# bankData is an array of hashes. Each hash is a transaction with the following info and format:
	# [ 
	#	{
    #      'DATE' => 'DD/MM/YYYY',
    #      'AMOUNT' => -NNNN.NN,
   	#      'DETAILS' => 'A string describing the transaction',
    #      'BALANCE' => -NNNN.NN,
    #    },
    #    {
    #		...
	#	 }
    # ]
	
	my $logger = Helpers::Logger->new();
	my $categories = $self->getCategories();
	my @operations;

	foreach my $line (@$bankData) {
		my $default = 1;
		my $i;
		for ($i=2; $i<$#{$categories}+1; $i++) {
			my $keywords = @$categories[$i]->{KEYWORDS};
			foreach my $keyword (@$keywords) {
				if ($keyword ne '' && $line->{DETAILS} =~ /$keyword/) {
					$default = 0;
					last;
				}
			}
			if (not $default) { last; }
		}
		if (not $default) {
			# Check the consistency of operation type and category family
			if ( ($line->{AMOUNT} < 0 && @$categories[$i]->{TYPEOPE} == EXPENSE)
			  || ($line->{AMOUNT} >= 0 && @$categories[$i]->{TYPEOPE} == INCOME) ) {
				push (@operations, buildExtendedRecord($line, @$categories[$i]));
			}
			else {
				$logger->print ( "Inconsistency: $line->{DETAILS} / $line->{AMOUNT} / @$categories[$i]->{TYPEOPE}", Helpers::Logger::INFO);
				$default = 1; #for managing inconsistency, requalify the operation as a defaut one
			}
		}
		if ($default) {
			if ($line->{AMOUNT} < 0) { # It's an expense
				push (@operations, buildExtendedRecord($line, @$categories[1]));
			}
			else { # It's an income
				push (@operations, buildExtendedRecord($line, @$categories[0]));
			}
		}
	}
	$self->{_operations} = \@operations;
	return \@operations;
}

sub buildExtendedRecord {
	my( $line, $categoryRecord) = @_;
	my %operationRecord;

	my ($d,$m,$y) = $line->{DATE} =~ /^([0-9]{2})\/([0-9]{2})\/([0-9]{4})\z/;
	my $date = DateTime->new(
	   year      => $y,
	   month     => $m,
	   day       => $d,
	   time_zone => 'local',
	);

	$operationRecord{DATE}		= $line->{DATE};
	$operationRecord{DAY}		= $date->day();
	$operationRecord{WDAY}		= int(($date->day()-1)/7).'.'.$date->wday();
	$operationRecord{WDAYNAME}	=$date->day_name();		
	$operationRecord{DEBIT}		= ( $line->{AMOUNT} < 0 ) ? $line->{AMOUNT} : undef;
	$operationRecord{CREDIT}	= ( $line->{AMOUNT} >= 0 ) ? $line->{AMOUNT} : undef;
	$operationRecord{TYPE}		= $categoryRecord->{TYPEOPE};
	$operationRecord{FAMILY}	= $categoryRecord->{FAMILY};
	$operationRecord{CATEGORY}	= $categoryRecord->{CATEGORY};
	$operationRecord{LIBELLE}	= $line->{DETAILS};		
	$operationRecord{SOLDE}		= $line->{BALANCE};	
	
	return \%operationRecord
}

sub groupBy {
	my( $self, $key, $value ) = @_;
	my $ope = $self->getOperations();
	my %pivot;
	my $tot = 0;
	
	for (my $i=0; $i<$#{$ope}+1; $i++) {
		if (defined @$ope[$i]->{$value} && @$ope[$i]->{$value} ne '') {
			$pivot{@$ope[$i]->{$key}} += @$ope[$i]->{$value};
			$tot += @$ope[$i]->{$value};
		}
	}
	return [\%pivot, $tot];
}

sub groupByWhere {
	my( $self, $key, $value, $where ) = @_;
	my $ope = $self->getOperations();
	my %pivot;
	my $tot = 0;
	
	for (my $i=0; $i<$#{$ope}+1; $i++) {
		if (defined @$ope[$i]->{$value} && @$ope[$i]->{$value} ne '') {
			my $boolWhere = 1;
			for (my $w=0; $w<$#{$where}+1; $w=$w+2) { 
				 if (@$ope[$i]->{@$where[$w]} ne @$where[$w+1]) { $boolWhere = 0 } }
			if ($boolWhere) {
				$pivot{@$ope[$i]->{$key}} += @$ope[$i]->{$value};
				$tot += @$ope[$i]->{$value};
			}
		}
	}
	return [\%pivot, $tot];
}


sub generateDashBoard {
	my( $self ) = @_;
	my $dt_currmonth = DateTime->now(time_zone => 'local' );	
	my $dt_prevmonth = DateTime->now(time_zone => 'local' );
	my $month = $dt_currmonth->month();
	my $year = $dt_currmonth->year();
	# first day of last month
	if ($month > 1) {
		$dt_prevmonth->set_month($month-1);
	} else { # shift to december of previous year
		$dt_prevmonth->set_month(12);
		$dt_prevmonth->set_year($year-1)
	}
	
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $reportMonthStr = sprintf "%4d-%02d", $dt_prevmonth->year(), $dt_prevmonth->month();
	my $wb_out = Spreadsheet::WriteExcel->new( $reportMonthStr.'_'.$self->getAccountNumber().'_'.$prop->readParamValue('excel.report.basename').'.xls' );
	my $currency_format = $wb_out->add_format( num_format => eval($prop->readParamValue('workbook.dashboard.currency.format')));
	my $date_format = $wb_out->add_format(num_format => $prop->readParamValue('workbook.dashboard.date.format'));
	my $wb_tpl = Helpers::ExcelWorkbook->openExcelWorkbook($prop->readParamValue("workbook.dashboard.template.path"));	

	
	### Summary sheet
	my $ws_tpl = $wb_tpl->worksheet( 0 );		
	my $ws_out = $wb_out->add_worksheet( $ws_tpl->get_name() );

	my ( $row_min, $row_max ) = $ws_tpl->row_range();
	my ( $col_min, $col_max ) = $ws_tpl->col_range();
	
	my $ops = $self->getOperations();
	my $rshift = 0;

	for my $row ( 0 .. $row_max ) {
		for my $col ( 0 .. $col_max ) {
			my $cell = $ws_tpl->get_cell( $row, $col );
			next unless $cell;			
			my $value = $cell->value();
			my $fx_tpl = $cell->get_format();
			my $font = Helpers::ExcelWorkbook->fontTranslator($fx_tpl->{Font});
			my $shading = Helpers::ExcelWorkbook->cellFormatTranslator($fx_tpl);
			my $fx_out = $wb_out->add_format( %$font, %$shading);

			if ($value eq '<ACCOUNT_NUMBER>') { $ws_out->write( $row+$rshift, $col, '\''.$self->getAccountNumber, $fx_out ); next; }
			if ($value eq '<ACCOUNT_DESC>') { $ws_out->write( $row+$rshift, $col, $self->getAccountDesc, $fx_out); next; }
			if ($value eq '<CURR_MONTH>') { $ws_out->write( $row+$rshift, $col, $dt_prevmonth->month_name().' '.$dt_prevmonth->year(), $fx_out ); next; }
			if ($value eq '<INIT_BALANCE>') { $ws_out->write( $row+$rshift, $col, @$ops[0]->{SOLDE}, $currency_format ); next; }
			if ($value eq '<END_BALANCE>') { $ws_out->write( $row+$rshift, $col, @$ops[$#{$ops}]->{SOLDE}, $currency_format ); next; }
			if ($value eq '<LOOP_EXPENSES>') {
				my $rshift = $self->displayPivotSumup($wb_out, $ws_out, $row, $col, $currency_format, $fx_out, 'DEBIT');
				next;
			}
			if ($value eq '<LOOP_INCOMES>') { 
				my $rshift = $self->displayPivotSumup($wb_out, $ws_out, $row, $col, $currency_format, $fx_out, 'CREDIT');
				next;
			}
			#else, copy the value and format from the template
			$ws_out->write( $row, $col, $value, $fx_out );
		}
	}
	### Details sheet
	$ws_tpl = $wb_tpl->worksheet( 1 );		
	$ws_out = $wb_out->add_worksheet( $ws_tpl->get_name() );
	my @dataRow = (
	 [
		'DATE',
		'DEBIT',
		'CREDIT',
		'FAMILY',
		'CATEGORY',
		'LIBELLE',	
		'SOLDE',
	 ]
	);
	$self->displayDetailsDataRow ( $ws_out, 0, \@dataRow, $date_format, $currency_format ) ;
	foreach my $i (0 .. $#{$ops}) {
		my @dataRow = (
		 [
			@$ops[$i]->{DATE},
			@$ops[$i]->{DEBIT},
			@$ops[$i]->{CREDIT},
			@$ops[$i]->{FAMILY},
			@$ops[$i]->{CATEGORY},
			@$ops[$i]->{LIBELLE},	
			@$ops[$i]->{SOLDE},
		 ]
		);
		$self->displayDetailsDataRow ( $ws_out, $i+1, \@dataRow, $date_format, $currency_format ) ;
	}
	$ws_out->autofilter(0, 0, $#{$ops}, $#dataRow+1);
	
	### cashflow sheet
	# init cashflow data
	my $dt_lastday =  DateTime->last_day_of_month( year => $dt_currmonth->year(), month => $dt_currmonth->month() );
	my @cashflow = ();
	for (my $d=1; $d<=$dt_lastday->day(); $d++) {
		my %record;
		$dt_currmonth->set_day($d);
		$record{DATE} = sprintf "%02d/%02d/%4d", $d, $dt_currmonth->month, $dt_currmonth->year();
		$record{DAY} = $d;
		$record{WDAY} = int(($d-1)/7).'.'.$dt_currmonth->wday();
		$record{WDAYNAME} = $dt_currmonth->day_name();
		$record{'MONTHLY EXPENSES'} = undef;
		$record{'MONTHLY EXPENSES DETAILS'} = undef;
		$record{'WEEKLY EXPENSES'} = undef;
		$record{'WEEKLY EXPENSES DETAILS'} = undef;
		$record{'MONTHLY INCOMES'} = undef;
		$record{'MONTHLY INCOMES DETAILS'} = undef;
		push (@cashflow, \%record);
	}
	my @where = ('FAMILY', 'MONTHLY EXPENSES');
	my $pivotDay = $self->groupByWhere ('DAY', 'DEBIT', \@where);
	$self->populateCashflowMonthlyTransactions ( \@cashflow, @$pivotDay[0], 'MONTHLY EXPENSES', 'DEBIT' );

	@where = ('FAMILY', 'MONTHLY INCOMES');
	$pivotDay = $self->groupByWhere ('DAY', 'CREDIT', \@where);
	$self->populateCashflowMonthlyTransactions ( \@cashflow, @$pivotDay[0], 'MONTHLY INCOMES', 'CREDIT' );

	@where = ('FAMILY', 'WEEKLY EXPENSES');
	$pivotDay = $self->groupByWhere ('WDAY', 'DEBIT', \@where);
	$self->populateCashflowWeeklyTransactions ( \@cashflow, @$pivotDay[0], 'WEEKLY EXPENSES', 'DEBIT' );
	
	$ws_tpl = $wb_tpl->worksheet( 2 );		
	$ws_out = $wb_out->add_worksheet( $ws_tpl->get_name() );
	
	@dataRow = (
	 [
		'DATE',
		'WDAY',
		'MONTHLY EXPENSES',
		'MONTHLY INCOMES',
		'WEEKLY EXPENSES',
		'EXCEPTIONAL EXPENSES',
		'EXCEPTIONAL INCOMES',
		@$ops[$#{$ops}]->{SOLDE}
	 ]
	);
	$self->displayDetailsDataRow ( $ws_out, 0, \@dataRow, $date_format, $currency_format ) ;
	foreach my $i (0 .. $#cashflow) {
		my @dataRow = ( 
		 [
			$cashflow[$i]->{DATE},
			$cashflow[$i]->{WDAYNAME},
			$cashflow[$i]->{'MONTHLY EXPENSES'},
			$cashflow[$i]->{'MONTHLY INCOMES'},
			$cashflow[$i]->{'WEEKLY EXPENSES'},
			undef,
			undef,
			'=H'.($i+1).'+SUM(C'.($i+2).':G'.($i+2).')'
		 ],
		 [ undef,
		   undef,
		   $cashflow[$i]->{'MONTHLY EXPENSES DETAILS'},
		   $cashflow[$i]->{'MONTHLY INCOMES DETAILS'},
		   $cashflow[$i]->{'WEEKLY EXPENSES DETAILS'},
		   undef,
		   undef,
		   undef,
		 ]
		);
		$self->displayDetailsDataRow ( $ws_out, $i+1, \@dataRow, $date_format, $currency_format ) ;
	}
	
	
}

sub displayPivotSumup {
	my( $self, $wb_out, $ws_out, $row, $col, $currency_format, $fx_out, $type ) = @_;
	my $categories = $self->getCategories();
	my $rinit = $row;
	my $pivot = $self->groupBy ('CATEGORY', $type);
	foreach my $i (0 .. $#{$categories}) {
		if ( @$categories[$i]->{'TYPEOPE'} == (($type eq 'CREDIT') ? INCOME : EXPENSE) ) {
			$ws_out->write( $row, $col, @$categories[$i]->{'CATEGORY'}, $fx_out );
			foreach my $key ( keys @$pivot[0] ) {
				if ( $key eq @$categories[$i]->{'CATEGORY'} && @$categories[$i]->{'TYPEOPE'} == (($type eq 'CREDIT') ? INCOME : EXPENSE) ) {
					$ws_out->write( $row, $col+1, @$pivot[0]->{$key}, $currency_format );	
				}
			}
			$row++;
		}
	}
	my $fx_tot = $wb_out->add_format();
	my $fx_sum = $wb_out->add_format();
    $fx_tot->copy($fx_out);
    $fx_tot->set_bold();
   	$fx_sum->copy($currency_format);
   	$fx_sum->set_bold();
	$ws_out->write( $row, $col, 'Total', $fx_tot ); 	
	$ws_out->write( $row, $col+1, '=SUM('.xl_rowcol_to_cell( $rinit, $col+1 ).':'.xl_rowcol_to_cell( $row-1, $col+1 ).')', $fx_sum ); 
	return $row - $rinit;		
}

sub displayDetailsDataRow {
	my( $self, $ws_out, $row, $dataRow, $date_format, $currency_format) = @_;
	my $columnValueArray = @$dataRow[0];
	foreach my $i (0 .. $#{$columnValueArray}) {
		if (defined @$columnValueArray[$i] && @$columnValueArray[$i]=~/\d/) { # currency column?
			$ws_out->write( $row, $i, @$columnValueArray[$i], $currency_format ); 
		}
		if (defined @$columnValueArray[$i] && @$columnValueArray[$i] =~ qr[^(\d{1,2})/(\d{1,2})/(\d{4})$]) { #date column?
			my $date = sprintf "%4d-%02d-%02dT", $3, $2, $1;
			$ws_out->write_date_time($row, $i, $date, $date_format);
		}
		else {
			$ws_out->write( $row, $i, @$columnValueArray[$i] );
		}
	}
	if ($#{$dataRow} == 1) { # Cell comment to be written
		my $columnCommentArray = @$dataRow[1];
		foreach my $i (0 .. $#{$columnCommentArray}) {
			if (defined @$columnCommentArray[$i]) {
				$ws_out->write_comment( $row, $i, @$columnCommentArray[$i] );
			}
		}
	}
}

sub populateCashflowMonthlyTransactions {
	my( $self, $cashflow, $pivotDay, $family, $type ) = @_;
	foreach my $day ( keys $pivotDay ) {
		my $found = 0;
		foreach my $i (0 .. $#{$cashflow}) {
			if (@$cashflow[$i]->{DAY} == $day) {
				@$cashflow[$i]->{$family} = $pivotDay->{$day};
				my @where = ('DAY', $day, 'FAMILY', $family);
				my $pivotCateg = $self->groupByWhere ('CATEGORY', $type, \@where);
				@$cashflow[$i]->{$family.' DETAILS'} = $self->buildCategoryDetails ( @$pivotCateg[0] );
				$found = 1;
				last;
			}
		}
		if (!$found) {
			if (defined @$cashflow[$#{$cashflow}]->{$family} ) {
				@$cashflow[$#{$cashflow}]->{$family} += $pivotDay->{$day};
			} else {
				@$cashflow[$#{$cashflow}]->{$family} = $pivotDay->{$day};
			}
			my @where = ('DAY', $day, 'FAMILY', $family);
			my $pivotCateg = $self->groupByWhere ('CATEGORY', $type, \@where);
			if (defined @$cashflow[$#{$cashflow}]->{$family.' DETAILS'} ) {
				@$cashflow[$#{$cashflow}]->{$family.' DETAILS'} += $self->buildCategoryDetails ( @$pivotCateg[0] );
			} else {
				@$cashflow[$#{$cashflow}]->{$family.' DETAILS'} = $self->buildCategoryDetails ( @$pivotCateg[0] );
			}
		}
	}
	
}

sub populateCashflowWeeklyTransactions {
	my( $self, $cashflow, $pivotDay, $family, $type ) = @_;
	foreach my $i (0 .. $#{$cashflow}) {
		my $found = 0;
		foreach my $wday ( keys $pivotDay ) {
			if (@$cashflow[$i]->{WDAY} == $wday) {
				@$cashflow[$i]->{$family} = $pivotDay->{$wday};
				my @where = ('WDAY', $wday, 'FAMILY', $family);
				my $pivotCateg = $self->groupByWhere ('CATEGORY', $type, \@where);
				@$cashflow[$i]->{$family.' DETAILS'} = $self->buildCategoryDetails ( @$pivotCateg[0] );
				$found = 1;
				last;
			}
		}
		if (!$found) {
			my $wday = @$cashflow[$i]->{WDAY};
			$wday =~ s/\d\.(\d)/0.$1/;
			@$cashflow[$i]->{$family} = $pivotDay->{$wday};
			my @where = ('WDAY', $wday, 'FAMILY', $family);
			my $pivotCateg = $self->groupByWhere ('CATEGORY', $type, \@where);
			@$cashflow[$i]->{$family.' DETAILS'} = $self->buildCategoryDetails ( @$pivotCateg[0] );

		}
	}
	
}

sub buildCategoryDetails {
	my( $self, $categHash ) = @_;
	my $details = undef;
	foreach my $categItem ( keys $categHash ) {
		if ( defined $details ) { $details .= "\n\r"; }
		$details .= $categItem.'='.$categHash->{$categItem};
	}
	return $details;
	
}

sub getAccountDesc {
	 my( $self ) = @_;
	return $self->{_accountDesc};
}

sub getAccountNumber {
	 my( $self ) = @_;
	return $self->{_accountNumber};
}

sub getBankName {
	 my( $self ) = @_;
	return $self->{_bankName};
}

sub getCategories {
	my( $self) = @_;
	return $self->{_categories};	
}

sub getOperations {
	my( $self) = @_;
	return $self->{_operations};		
}

1;