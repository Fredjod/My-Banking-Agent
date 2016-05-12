package AccountStatement::Reporting;

use lib '../../lib';
use strict;
use warnings;
use DateTime;
use Helpers::ExcelWorkbook;
use Spreadsheet::ParseExcel;
use Spreadsheet::XLSX;
use Spreadsheet::WriteExcel::Utility;
use utf8;
use Data::Dumper;
use Helpers::Logger;
use Helpers::SendMail;
use Helpers::Date;
use AccountStatement::CheckingAccount;


sub new
{
    my ($class ) = @_;
        
    my $self = {
    	_accDataPRM => undef, # Previous month (1er to last day)
    	_accDataMTD => undef, # Current month (1er to now)
    	_sheetClipBoard => undef,
    };
    bless $self, $class;
    return $self;
}

sub createPreviousMonthClosingReport {
	
	my( $self) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $wb_out = Helpers::ExcelWorkbook->createWorkbook ( Helpers::MbaFiles->getClosingFilePath ( $self->getAccDataPRM ) );
	my $currency_format = $wb_out->add_format( num_format => eval($prop->readParamValue('workbook.dashboard.currency.format')));
	my $date_format = $wb_out->add_format(num_format => $prop->readParamValue('workbook.dashboard.date.format'));
	my $current_format_actuals = $wb_out->add_format();
	$current_format_actuals->copy($currency_format);
	$current_format_actuals->set_pattern(17);
	
	$self->generateSummarySheet($self->getAccDataPRM(), $wb_out, $currency_format, $date_format);
	$self->generateDetailsSheet($self->getAccDataPRM(), $wb_out, $currency_format, $date_format);
	$self->generateCashflowSheet( $self->getAccDataMTD(), $self->getAccDataPRM(), $wb_out, $currency_format, $date_format, $current_format_actuals);

}


sub createActualsReport {
	
	my( $self) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	$self->copyCashflowExcelSheet (Helpers::MbaFiles->getClosingFilePath ( $self->getAccDataPRM ), 2 );
	my $wb_out = Helpers::ExcelWorkbook->createWorkbook( Helpers::MbaFiles->getActualsFilePath ( $self->getAccDataMTD ) );
	my $currency_format = $wb_out->add_format( num_format => eval($prop->readParamValue('workbook.dashboard.currency.format')));
	my $date_format = $wb_out->add_format(num_format => $prop->readParamValue('workbook.dashboard.date.format'));
	my $current_format_actuals = $wb_out->add_format();
	$current_format_actuals->copy($currency_format);
	$current_format_actuals->set_pattern(17);
	
	$self->generateDetailsSheet($self->getAccDataMTD(), $wb_out, $currency_format, $date_format);
	$self->generateActualsCashflowSheet( $self->getAccDataMTD(), $wb_out, $currency_format, $date_format, $current_format_actuals);
	$self->generateVariationSheet ( $self->getAccDataMTD(), $wb_out, $currency_format, $date_format );
}

sub generateSummarySheet
{
	my ( $self, $statement, $wb_out, $currency_format, $date_format) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $wb_tpl = Helpers::ExcelWorkbook->openExcelWorkbook($prop->readParamValue("workbook.dashboard.template.path"));
	my $dt_prevmonth = $statement->getMonth()->clone();
	
	my $ws_tpl = $wb_tpl->worksheet( 0 );		
	my $ws_out = $wb_out->add_worksheet( $ws_tpl->get_name() );

	my ( $row_min, $row_max ) = $ws_tpl->row_range();
	my ( $col_min, $col_max ) = $ws_tpl->col_range();
	
	my $ops = $statement->getOperations();
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
			
			# By default, balance = end of month balance
			my $balance = $statement->getBalance();
			if (defined $ops) {
				$balance = 	@$ops[0]->{SOLDE} - ( (! defined @$ops[0]->{DEBIT} ? 0 : @$ops[0]->{DEBIT} )
								+ (! defined @$ops[0]->{CREDIT} ? 0 : @$ops[0]->{CREDIT} ) 
								 );		
			}

			if ($value eq '<ACCOUNT_NUMBER>') { $ws_out->write( $row+$rshift, $col, $statement->getAccountNumber, $fx_out ); next; }
			if ($value eq '<ACCOUNT_DESC>') { $ws_out->write( $row+$rshift, $col, $statement->getAccountDesc, $fx_out); next; }
			if ($value eq '<CURR_MONTH>') { $ws_out->write( $row+$rshift, $col, $dt_prevmonth->month_name().' '.$dt_prevmonth->year(), $fx_out ); next; }
			if ($value eq '<INIT_BALANCE>') { $ws_out->write( $row+$rshift, $col, $balance, $currency_format ); next; }
			if ($value eq '<END_BALANCE>') { $ws_out->write( $row+$rshift, $col, $statement->getBalance(), $currency_format ); next; }
			if ($value eq '<LOOP_EXPENSES>') {
				my $rshift = $self->displayPivotSumup($statement, $wb_out, $ws_out, $row, $col, $currency_format, $fx_out, 'DEBIT');
				next;
			}
			if ($value eq '<LOOP_INCOMES>') { 
				my $rshift = $self->displayPivotSumup($statement, $wb_out, $ws_out, $row, $col, $currency_format, $fx_out, 'CREDIT');
				next;
			}
			#else, copy the value and format from the template
			if ($value ne '') {
				$ws_out->write( $row, $col, $value, $fx_out );
			}
		}
	}
	$ws_out->set_column(0, 4,  15);
}

sub generateDetailsSheet
{
	my ( $self, $statement, $wb_out, $currency_format, $date_format) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $wb_tpl = Helpers::ExcelWorkbook->openExcelWorkbook($prop->readParamValue("workbook.dashboard.template.path"));
	
	### Details sheet
	my $ws_tpl = $wb_tpl->worksheet( 1 );		
	my $ws_out = $wb_out->add_worksheet( $ws_tpl->get_name() );
	my $ops = $statement->getOperations();
	
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
	if ( defined $ops ) {
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
		$ws_out->autofilter(0, 0, $#{$ops}+1, $#{$dataRow[0]});
	}
	$ws_out->set_column(0, 2,  10);
	$ws_out->set_column(3, 4,  20);
	$ws_out->set_column(5, 5,  40);
	$ws_out->set_column(6, 6,  10);	
}

sub generateCashflowSheet
{
	my ( $self, $statMTD, $statPRM, $wb_out, $currency_format, $date_format, $current_format_actuals) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $wb_tpl = Helpers::ExcelWorkbook->openExcelWorkbook($prop->readParamValue("workbook.dashboard.template.path"));

	my $dt_currmonth = $statMTD->getMonth()->clone();
	
	my $dt_lastday =  DateTime->last_day_of_month( year => $dt_currmonth->year(), month => $dt_currmonth->month() );
	my @cashflow = ();
	my $ws_tpl = $wb_tpl->worksheet( 2 );		
	my $ws_out = $wb_out->add_worksheet( $ws_tpl->get_name().'-'.sprintf ("%4d-%02d-%02d", $dt_currmonth->year, $dt_currmonth->month, $dt_currmonth->day ) );
	my $balance = $statMTD->getBalance();
	my $ops = $statMTD->getOperations();
	if (defined $ops) {
		$balance = @$ops[0]->{SOLDE} - ( (! defined @$ops[0]->{DEBIT} ? 0 : @$ops[0]->{DEBIT} )
							+ (! defined @$ops[0]->{CREDIT} ? 0 : @$ops[0]->{CREDIT} ) 
							 );		
	} else {
		$ops = $statPRM->getOperations();
		if (defined $ops) {
			$balance = @$ops[$#{$ops}]->{SOLDE};
		}
	}
	
	### cashflow sheet
	# init cashflow data
	
	# Write header line
	my @dataRow = (
	 [
		'DATE',
		'WDAY',
		'MONTHLY INCOMES',
		'EXCEPTIONAL INCOMES',
		'MONTHLY EXPENSES',
		'WEEKLY EXPENSES',
		'EXCEPTIONAL EXPENSES',
		$balance
	 ]
	);
	$self->displayDetailsDataRow ( $ws_out, 0, \@dataRow, $date_format, $currency_format ) ;
	
	if ( defined $statMTD->getOperations() ) { # We are NOT at the begining of the month 
		$self->populateCashflowSheet (\@cashflow, $statMTD, 1, $dt_currmonth->day(), 'ACTUALS', $dt_currmonth, $ws_out, $currency_format, $date_format, $current_format_actuals);
		if ($dt_currmonth->day() < $dt_lastday->day() ) {
			$self->populateCashflowSheet (\@cashflow, $statPRM, $dt_currmonth->day()+1, $dt_lastday->day(), 'FORECASTED', $dt_currmonth, $ws_out, $currency_format, $date_format, $current_format_actuals);
		}
	}
	else {
			$self->populateCashflowSheet (\@cashflow, $statPRM, 1, $dt_lastday->day(), 'FORECASTED', $dt_currmonth, $ws_out, $currency_format, $date_format, $current_format_actuals);	
	}
	$ws_out->set_column(0, 1,  10);	
	$ws_out->set_column(2, 2,  19);
	$ws_out->set_column(3, 3,  23);
	$ws_out->set_column(4, 5,  19);
	$ws_out->set_column(6, 6,  23);	
	$ws_out->set_column(7, 7,  10);	
	$ws_out->set_zoom(95);
}

sub generateActualsCashflowSheet
{
	my ( $self, $statMTD, $wb_out, $currency_format, $date_format, $current_format_actuals) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $wb_tpl = Helpers::ExcelWorkbook->openExcelWorkbook($prop->readParamValue("workbook.dashboard.template.path"));

	my $dt_currmonth = $statMTD->getMonth()->clone();
	
	my $dt_lastday =  DateTime->last_day_of_month( year => $dt_currmonth->year(), month => $dt_currmonth->month() );
	my @cashflow = ();
	my $ws_tpl = $wb_tpl->worksheet( 2 );
	my $sheetName = $ws_tpl->get_name().'-'.sprintf ("%4d-%02d-%02d", $dt_currmonth ->year, $dt_currmonth ->month, $dt_currmonth ->day );
	
	
	my $ws_out = $wb_out->add_worksheet( $sheetName );
	my $ops = $statMTD->getOperations();
	
	# Write header line
	my @dataRow = (
	 [
		'DATE',
		'WDAY',
		'MONTHLY INCOMES',
		'EXCEPTIONAL INCOMES',
		'MONTHLY EXPENSES',
		'WEEKLY EXPENSES',
		'EXCEPTIONAL EXPENSES',
		@$ops[0]->{SOLDE} - ( (! defined @$ops[0]->{DEBIT} ? 0 : @$ops[0]->{DEBIT} )
							+ (! defined @$ops[0]->{CREDIT} ? 0 : @$ops[0]->{CREDIT} ) 
							 )
	 ]
	);
	$self->displayDetailsDataRow ( $ws_out, 0, \@dataRow, $date_format, $currency_format ) ;
	
	my $row = $dt_currmonth->day();
	$self->populateCashflowSheet (\@cashflow, $statMTD, 1, $dt_currmonth->day(), 'ACTUALS', $dt_currmonth, $ws_out, $currency_format, $date_format, $current_format_actuals);
	if ($dt_currmonth->day() < $dt_lastday->day() ) {
		$row = $self->pastExcelSheet ( $wb_out, $ws_out, $dt_currmonth->day()+1 );
	}
	
	# Write footer line
	@dataRow = (
	 [
		'',
		'',
		'',
		'',
		'',
		'',
		'Month bottom line:',
		'=SUM(C2:G'.($row+1).')'
	 ]
	);
	$self->displayDetailsDataRow ( $ws_out, $row+2, \@dataRow, $date_format, $currency_format ) ;
	
	$ws_out->set_column(0, 1,  10);	
	$ws_out->set_column(2, 2,  19);
	$ws_out->set_column(3, 3,  23);
	$ws_out->set_column(4, 5,  19);
	$ws_out->set_column(6, 6,  23);	
	$ws_out->set_column(7, 7,  10);	
	$ws_out->set_zoom(95);
}

sub generateVariationSheet {
	my ( $self, $statMTD, $wb_out, $currency_format, $date_format ) = @_;
	my $dt_currmonth =  $statMTD->getMonth();
	my $sheetName = 'Variation'.'-'.sprintf ("%4d-%02d-%02d", $dt_currmonth ->year, $dt_currmonth ->month, $dt_currmonth ->day );
	my $ws_out = $wb_out->add_worksheet( $sheetName );

	# Write header line
	my @dataRow = (
	 [
		'',
		'Actuals MTD',
		'Forecasted MTD',
		'Variation'
	 ]
	);
	$self->displayDetailsDataRow ( $ws_out, 0, \@dataRow, $date_format, $currency_format ) ;
	
	# Compute the planned balance at the current date in the cashflow forecast sheet
	my $plannedBalance = $self->computeForecastedBalancePRM ();
	
	# Get the actuals balance (read from bank website)
	my $ops = $statMTD->getOperations();
	my $currentBalance = @$ops[$#{$ops}]->{SOLDE};
	
	my $row = 1;
	@dataRow = (
	 [
		'BALANCE',
		$currentBalance,
		$plannedBalance,
		'=B'.($row+1).'-C'.($row+1)
	 ]
	);
	$self->displayDetailsDataRow ( $ws_out, $row, \@dataRow, $date_format, $currency_format ) ;
	
	my $pivotCredit = $statMTD->groupBy ('FAMILY', 'CREDIT');
	$row = 3;
	foreach my $fam ('MONTHLY INCOMES', 'EXCEPTIONAL INCOMES' ) {
		@dataRow = (
		 [
			$fam,
			@$pivotCredit[0]->{$fam},
			$self->sumForecastedOperationPerFamily($fam),
			'=B'.($row+1).'-C'.($row+1)
		 ]
		);
		$self->displayDetailsDataRow ( $ws_out, $row, \@dataRow, $date_format, $currency_format ) ;
		$row++;
	}
	my $pivotDebit = $statMTD->groupBy ('FAMILY', 'DEBIT');	
	$row++;
	foreach my $fam ('MONTHLY EXPENSES', 'WEEKLY EXPENSES', 'EXCEPTIONAL EXPENSES') {
		@dataRow = (
		 [
			$fam,
			@$pivotDebit[0]->{$fam},
			$self->sumForecastedOperationPerFamily($fam),
			'=B'.($row+1).'-C'.($row+1)
		 ]
		);
		$self->displayDetailsDataRow ( $ws_out, $row, \@dataRow, $date_format, $currency_format ) ;
		$row++;
	}
	$ws_out->set_column(0, 0,  23);	
	$ws_out->set_column(1, 3,  15);
}

sub populateCashflowSheet {
	my ( $self, $cashflow, $stat, $startDay, $endDay, $type, $dt_currmonth, $ws_out, $currency_format, $date_format, $current_format_actuals) = @_;
	for (my $d=$startDay; $d<=$endDay; $d++) {
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
		$record{'EXCEPTIONAL EXPENSES'} = undef;
		$record{'EXCEPTIONAL EXPENSES DETAILS'} = undef;
		$record{'EXCEPTIONAL INCOMES'} = undef;
		$record{'EXCEPTIONAL INCOMES DETAILS'} = undef;
		push ($cashflow, \%record);
	}
	my @where = ('FAMILY', 'MONTHLY EXPENSES');
	my $pivotDay = $stat->groupByWhere ('DAY', 'DEBIT', \@where);
	$self->populateCashflowMonthlyTransactions ( $stat, $cashflow, @$pivotDay[0], 'MONTHLY EXPENSES', 'DEBIT', $type);

	@where = ('FAMILY', 'MONTHLY INCOMES');
	$pivotDay = $stat->groupByWhere ('DAY', 'CREDIT', \@where);
	$self->populateCashflowMonthlyTransactions ( $stat, $cashflow, @$pivotDay[0], 'MONTHLY INCOMES', 'CREDIT', $type );

	@where = ('FAMILY', 'WEEKLY EXPENSES');
	$pivotDay = $stat->groupByWhere ('WDAY', 'DEBIT', \@where);
	$self->populateCashflowWeeklyTransactions ( $stat, $cashflow, @$pivotDay[0], 'WEEKLY EXPENSES', 'DEBIT', $type );

	if ($type eq 'ACTUALS') { # the EXCEPTIONAL expenses or incomes are displayed only for actuals, not for forecasted
		@where = ('FAMILY', 'EXCEPTIONAL EXPENSES');
		$pivotDay = $stat->groupByWhere ('DAY', 'DEBIT', \@where);
		$self->populateCashflowMonthlyTransactions ( $stat, $cashflow, @$pivotDay[0], 'EXCEPTIONAL EXPENSES', 'DEBIT', $type );
	
		@where = ('FAMILY', 'EXCEPTIONAL INCOMES');
		$pivotDay = $stat->groupByWhere ('DAY', 'CREDIT', \@where);
		$self->populateCashflowMonthlyTransactions ( $stat, $cashflow, @$pivotDay[0], 'EXCEPTIONAL INCOMES', 'CREDIT', $type );
	}
	
	foreach my $i ($startDay-1 .. $#{$cashflow}) {
		my @dataRow = ( 
		 [
			@$cashflow[$i]->{DATE},
			@$cashflow[$i]->{WDAYNAME},
			@$cashflow[$i]->{'MONTHLY INCOMES'},
			@$cashflow[$i]->{'EXCEPTIONAL INCOMES'},
			@$cashflow[$i]->{'MONTHLY EXPENSES'},
			@$cashflow[$i]->{'WEEKLY EXPENSES'},
			@$cashflow[$i]->{'EXCEPTIONAL EXPENSES'},
			'=H'.($i+1).'+SUM(C'.($i+2).':G'.($i+2).')'
		 ],
		 [ undef,
		   undef,
		   @$cashflow[$i]->{'MONTHLY INCOMES DETAILS'},
		   @$cashflow[$i]->{'EXCEPTIONAL INCOMES DETAILS'},
		   @$cashflow[$i]->{'MONTHLY EXPENSES DETAILS'},
		   @$cashflow[$i]->{'WEEKLY EXPENSES DETAILS'},
		   @$cashflow[$i]->{'EXCEPTIONAL EXPENSES DETAILS'},
		   undef,
		 ]
		);
		$self->displayDetailsDataRow ( $ws_out, $i+1, \@dataRow, $date_format, $currency_format, $current_format_actuals, $type ) ;
	}
	
}

sub displayPivotSumup {
	my( $self, $statement, $wb_out, $ws_out, $row, $col, $currency_format, $fx_out, $type ) = @_;
	my $rinit = $row;
	if (defined $statement->getOperations()) {
		my $categories = $statement->getCategories();
		my $pivot = $statement->groupBy ('CATEGORY', $type);
		my $found;
		foreach my $i (0 .. $#{$categories}) {
			if ( @$categories[$i]->{'TYPEOPE'} == (($type eq 'CREDIT') ? AccountStatement::Account::INCOME : AccountStatement::Account::EXPENSE) ) {
				$ws_out->write( $row, $col, @$categories[$i]->{'CATEGORY'}, $fx_out );
				$found = 0;
				foreach my $key ( keys @$pivot[0] ) {
					if ( $key eq @$categories[$i]->{'CATEGORY'} ) {
						$ws_out->write( $row, $col+1, @$pivot[0]->{$key}, $currency_format );
						$found = 1;
						last;
					}
				}
				if (!$found) {
					$ws_out->write( $row, $col+1, 0, $currency_format );
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
	} else {
		$ws_out->write ($row, $col, 'NO TRANSACTION', $fx_out);
		$row++;
	}
	return $row - $rinit;		
}

sub displayDetailsDataRow {
	my( $self, $ws_out, $row, $dataRow, $date_format, $currency_format, $current_format_actuals, $type) = @_;
	my $columnValueArray = @$dataRow[0];
	$type = !defined $type ? 'FORECASTED' : $type;

	foreach my $i (0 .. $#{$columnValueArray}) {
		if (defined @$columnValueArray[$i] && @$columnValueArray[$i]=~/^[+-]?\d+(\.\d+)?$/) { # currency column?
			if ($type eq 'ACTUALS') {
				$ws_out->write( $row, $i, @$columnValueArray[$i], $current_format_actuals );
			} else {
				$ws_out->write( $row, $i, @$columnValueArray[$i], $currency_format );
			}
		}
		elsif (defined @$columnValueArray[$i] && @$columnValueArray[$i] =~ qr[^(\d{1,2})/(\d{1,2})/(\d{4})$]) { #date column?
			my $date = sprintf "%4d-%02d-%02dT", $3, $2, $1;
			$ws_out->write_date_time($row, $i, $date, $date_format);
		}
		else {
			if ($type eq 'ACTUALS') {
				$ws_out->write( $row, $i, @$columnValueArray[$i], $current_format_actuals );
			} else {
				$ws_out->write( $row, $i, @$columnValueArray[$i] );
			}
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
	my( $self, $statement, $cashflow, $pivotDay, $family, $typeOpe, $type ) = @_;
	
	my $log = Helpers::Logger->new();
	$log->print ( "populateCashflowMonthlyTransactions :: Cashflow data", Helpers::Logger::DEBUG);
	$log->print ( Dumper $cashflow, Helpers::Logger::DEBUG);
	$log->print ( "populateCashflowMonthlyTransactions :: PivotDay data", Helpers::Logger::DEBUG);
	$log->print ( Dumper $pivotDay, Helpers::Logger::DEBUG);
	
	foreach my $day ( keys $pivotDay ) {
		my $found = 0;
		foreach my $i (0 .. $#{$cashflow}) {
			if (@$cashflow[$i]->{DAY} == $day) {
				@$cashflow[$i]->{$family} = $pivotDay->{$day};
				my @where = ('DAY', $day, 'FAMILY', $family);
				my $pivotCateg = $statement->groupByWhere ('CATEGORY', $typeOpe, \@where);
				@$cashflow[$i]->{$family.' DETAILS'} = $self->buildCategoryDetails ( @$pivotCateg[0] );
				$found = 1;
				last;
			}
		}
		if (!$found && $type ne 'ACTUALS') {
			# In case the current month is shorter than the previous month,
			# Example: january and february months.
			# Decision: All the transactions after the last day 
			# of the previous month are summed and populate the last day of the current month
			# Example: Transactions between 29/01 to 31/01 are all summed and populate the 28/02.
			
			if (defined @$cashflow[$#{$cashflow}]->{$family} ) {
				@$cashflow[$#{$cashflow}]->{$family} += $pivotDay->{$day};
			} else {
				@$cashflow[$#{$cashflow}]->{$family} = $pivotDay->{$day};
			}
			my @where = ('DAY', $day, 'FAMILY', $family);
			my $pivotCateg = $statement->groupByWhere ('CATEGORY', $typeOpe, \@where);
			if (defined @$cashflow[$#{$cashflow}]->{$family.' DETAILS'} ) {
				@$cashflow[$#{$cashflow}]->{$family.' DETAILS'} .= $self->buildCategoryDetails ( @$pivotCateg[0] );
			} else {
				@$cashflow[$#{$cashflow}]->{$family.' DETAILS'} = $self->buildCategoryDetails ( @$pivotCateg[0] );
			}
		}
	}
	
}

sub populateCashflowWeeklyTransactions {
	my( $self, $statement, $cashflow, $pivotDay, $family, $typeOpe, $type ) = @_;
	foreach my $i (0 .. $#{$cashflow}) {
		my $found = 0;
		foreach my $wday ( keys $pivotDay ) {
			if (@$cashflow[$i]->{WDAY} == $wday) {
				@$cashflow[$i]->{$family} = $pivotDay->{$wday};
				my @where = ('WDAY', $wday, 'FAMILY', $family);
				my $pivotCateg = $statement->groupByWhere ('CATEGORY', $typeOpe, \@where);
				@$cashflow[$i]->{$family.' DETAILS'} = $self->buildCategoryDetails ( @$pivotCateg[0] );
				$found = 1;
				last;
			}
		}
		if (!$found && $type ne 'ACTUALS') {
			# Happen when last week of current month ends after the previous month
			# Example: current month, the last day is a Friday and the previous month last day was Wednesday.
			# In other words, week days 4.4 and 4.5 does not exist in the previous month.
			# Decision: take the week days of the first week of the previous month for populating the same week day of
			# the last week of the current month.
			# Sample: the wday 4.4 and 4.5 of the current month are populated with the 0.4 and 0.5 of the previous month.
			my $wday = @$cashflow[$i]->{WDAY};
			$wday =~ s/\d\.(\d)/0.$1/;
			@$cashflow[$i]->{$family} = $pivotDay->{$wday};
			my @where = ('WDAY', $wday, 'FAMILY', $family);
			my $pivotCateg = $statement->groupByWhere ('CATEGORY', $typeOpe, \@where);
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

sub computeForecastedBalancePRM {
	my( $self ) = @_;
	
	my $statMTD = $self->getAccDataMTD;
	my $dt_currmonth =  $statMTD->getMonth();
	
	# Compute the forecasted balance recorded in the cashflow sheet
	my $workbook = Helpers::ExcelWorkbook->openExcelWorkbook( Helpers::MbaFiles->getClosingFilePath ( $self->getAccDataPRM ));	
	my $worksheet = $workbook->worksheet( 2 ); # cashflow sheet
	my $plannedBalance = $worksheet->get_cell( 0, 7 )->unformatted();
	for (my $row=1; $row <= $dt_currmonth->day(); $row++) {
		my $lineTot = 0;
		for (my $col = 2; $col <=6; $col ++) {
			my $cell = $worksheet->get_cell( $row, $col );
			next unless $cell;
			next unless length($cell);
			next unless $cell->unformatted() =~ /^[+-]?\d+(\.\d+)?$/; # is a amount?
			$lineTot += $worksheet->get_cell( $row, $col )->unformatted() ;
		}
		$plannedBalance += $lineTot;
	}
	return $plannedBalance;
}

sub controlBalance {
	my( $self, $wkday ) = @_;
	
	my $statMTD = $self->getAccDataMTD;
	my $dt_currmonth =  $statMTD->getMonth();

	my $log = Helpers::Logger->new();
	my $prop = Helpers::ConfReader->new("properties/app.txt");

	# Compute the planned balance at the current date in the cashflow forecast sheet
	my $plannedBalance = $self->computeForecastedBalancePRM ();
	
	# Get the actuals balance (read from bank website)
	my $ops = $statMTD->getOperations();
	my $currentBalance = @$ops[$#{$ops}]->{SOLDE};

	# Check whether a risk of bank overdraft is known from the actuals cashflow report
	my $risk = 0;
	my $overdraft = $prop->readParamValue('alert.overdraft.threshold');
	my $workbook = Helpers::ExcelWorkbook->openExcelWorkbook( Helpers::MbaFiles->getActualsFilePath ( $self->getAccDataMTD ));	
	my $worksheet = $workbook->worksheet( 1 ); # cashflow sheet
	my ( $row_min, $row_max ) = $worksheet->row_range();
	my $balanceRisk = $worksheet->get_cell( 0, 7 )->unformatted();
	for (my $row=1; $row <= $row_max; $row++) {
		my $lineTot = 0;
		for (my $col = 2; $col <=6; $col ++) {
			my $cell = $worksheet->get_cell( $row, $col );
			next unless $cell;
			next unless length($cell);
			next unless $cell->unformatted() =~ /^[+-]?\d+(\.\d+)?$/; # is a amount?
			$lineTot += $worksheet->get_cell( $row, $col )->unformatted() ;
		}
		$balanceRisk  += $lineTot;
		if ( $balanceRisk  < $overdraft and $row > $dt_currmonth->day() ) { # risk of bank overdraft in the future
			$risk = $row;
			last;
		}
	}

	# Check whether an alert is needed due to a too hight variation between actual and forecasted balance.
	my $threshold = $prop->readParamValue('alert.mondays.variation.threshold');
	my $var = abs ($currentBalance-$plannedBalance);
	if ( $var >= $threshold && $wkday == 1) { 
		my $subject = "Balance Variation Alert";
		$log->print ( "Email sending: $subject: Actuals:$currentBalance, Planned:$plannedBalance, Variation:$var", Helpers::Logger::INFO);
		my $mail = Helpers::SendMail->new(
			$subject." - ".sprintf ("%4d-%02d-%02d", $dt_currmonth->year(), $dt_currmonth->month(), $dt_currmonth->day()),
			"alert.body.template"
		);
		$mail->buildBalanceAlertBody ($self, $statMTD, $currentBalance, $plannedBalance);
		$mail->send();
	}
	else {
		$log->print ( "Account balance variation OK", Helpers::Logger::INFO);
	}
	if ($currentBalance < $overdraft ) { # Send an alert in case of actual bank overdraft.
		my $subject = "!!! Bank Overdraft Alert !!!";
		$log->print ( "Email sending: $subject: Actuals:$currentBalance", Helpers::Logger::INFO);
		my $mail = Helpers::SendMail->new(
			$subject." - ".sprintf ("%4d-%02d-%02d", $dt_currmonth->year(), $dt_currmonth->month(), $dt_currmonth->day()),
			"alert.overdraft.body.template"
		);
		$mail->buildOverdraftAlertBody ($self, $statMTD, $currentBalance, $dt_currmonth );
		$mail->send();
	} else {
		if ($risk > 0 ) { # Found a risk if bank overdraft before the end of the month
			my $subject = "Bank Overdraft Risk";
			$log->print ( "Email sending: $subject: forecasted:$balanceRisk on the $risk", Helpers::Logger::INFO);
			my $mail = Helpers::SendMail->new(
				$subject." - ".sprintf ("%4d-%02d-%02d", $dt_currmonth->year(), $dt_currmonth->month(), $dt_currmonth->day()),
				"alert.risk.overdraft.body.template"
			);
			$mail->buildOverdraftAlertBody ($self, $statMTD, $balanceRisk, $dt_currmonth->set_day($risk) );
			$mail->send();
		}
	}
}

sub sumForecastedOperationPerFamily {
	my( $self, $family ) = @_;
	my $statMTD = $self->getAccDataMTD;
	my $dt_currmonth =  $statMTD->getMonth();
	my $totFam = 0;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $workbook = Helpers::ExcelWorkbook->openExcelWorkbook( Helpers::MbaFiles->getClosingFilePath ( $self->getAccDataPRM ) );	
	my $worksheet = $workbook->worksheet(2); # cashflow sheet
	# Look for the family column (on the firs row)
	my ( $col_min, $col_max ) = $worksheet->col_range();
	my $colFam = -1;
	for (my $col=$col_min; $col<=$col_max; $col++ ) {
		my $cell = $worksheet->get_cell( 0, $col );
		next unless $cell;
		next unless (uc $cell->value eq uc $family);
		$colFam = $col;
	}
	if ($colFam > -1) {
		for (my $row=1; $row <= $dt_currmonth->day(); $row++) {
			my $cell = $worksheet->get_cell( $row, $colFam );
			next unless $cell;
			next unless ($cell->unformatted() =~ /^-?\d/); #is numeric?
			$totFam += $cell->unformatted();
		}
	}
	return $totFam;
}

sub copyCashflowExcelSheet {
	my ( $self, $wbPath, $wsNumber ) = @_;
	my $wb = Helpers::ExcelWorkbook->openExcelWorkbook($wbPath);
	my $ws = $wb->worksheet( $wsNumber );		

	my ( $row_min, $row_max ) = $ws->row_range();
	my ( $col_min, $col_max ) = $ws->col_range();
	
	my @tabSheet;

	for my $row ( 0 .. $row_max ) {
		for my $col ( 0 .. $col_max ) {
		my $cell = $ws->get_cell( $row, $col );	
		my %record;
			if (defined $cell) {	
				if ($col == $col_max) { # Formula cumul line
					%record = (
						'unformatted' => '=H'.($row).'+SUM(C'.($row+1).':G'.($row+1).')',
						'value' => '=H'.($row).'+SUM(C'.($row+1).':G'.($row+1).')',
						'format' => $cell->get_format(),
					);
				} else {
					%record = (
						'unformatted' => $cell->unformatted(),
						'value' => $cell->value(),
						'format' => $cell->get_format(),
					);
				}
				$tabSheet[$row][$col] = \%record;
			}
			else {
				$tabSheet[$row][$col] = undef;
			}
		}
	}
	$self->setSheetClipBoard(\@tabSheet);
	return $ws->get_name();
}

sub pastExcelSheet {
	my ( $self, $wb, $ws, $startRow, $endRow ) = @_;

	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $tab = $self->getSheetClipBoard();
	
	if (!defined $startRow) { $startRow = 0; }
	if (!defined $endRow) { $endRow = @$tab - 1; }
	for my $row ( $startRow .. $endRow ) {
		for my $col ( 0 .. $#{@$tab[$row]} ) {
			if (defined @$tab[$row]->[$col]) {
				my $font = Helpers::ExcelWorkbook->fontTranslator( @$tab[$row]->[$col]->{format}->{Font});
				my $shading = Helpers::ExcelWorkbook->cellFormatTranslator(@$tab[$row]->[$col]->{format});
				my $fx_out = $wb->add_format( %$font, %$shading);
				
				if (@$tab[$row]->[$col]->{value} =~ qr[^(\d{1,2})/(\d{1,2})/(\d{4})$]) { #date column?
					my $date = sprintf "%4d-%02d-%02dT", $3, $2, $1;
					$fx_out->set_num_format($prop->readParamValue('workbook.dashboard.date.format'));
					$ws->write_date_time($row, $col, $date, $fx_out);
				}				
				elsif ( @$tab[$row]->[$col]->{unformatted} =~ /^[+-]?\d+(\.\d+)?$/ ) { # currency column?
					$fx_out->set_num_format(eval($prop->readParamValue('workbook.dashboard.currency.format')));
					$ws->write( $row, $col, @$tab[$row]->[$col]->{unformatted}, $fx_out ); 
				}
				else {
					$ws->write( $row, $col, @$tab[$row]->[$col]->{value}, $fx_out );
				}
			}
		}
	}
	return $endRow;	
}

sub getAccDataPRM {
	my( $self) = @_;
	return $self->{_accDataPRM};		
}

sub getAccDataMTD {
	my( $self) = @_;
	return $self->{_accDataMTD};		
}

sub getSheetClipBoard {
	my( $self ) = @_;
	return $self->{_sheetClipBoard};	
}


sub setAccDataPRM {
	my( $self, $statement) = @_;
	$self->{_accDataPRM} = $statement;		
}

sub setAccDataMTD {
	my( $self, $statement) = @_;
	$self->{_accDataMTD} = $statement;		
}

sub setSheetClipBoard {
	my( $self, $tab) = @_;
	$self->{_sheetClipBoard} = $tab;		
}

1;
