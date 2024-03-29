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
use AccountStatement::PlannedOperation;
use Data::Dumper;


sub new
{
    my ($class, $statPRM, $statMTD ) = @_;
        
    my $self = {
    	_accDataPRM => $statPRM, # Previous month (1er to last day of previous month)
    	_accDataMTD => $statMTD, # Current month (1er to now)
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
	
	$self->generateSummarySheet($self->getAccDataPRM(), $wb_out, $currency_format, $date_format);
	$self->generateDetailsSheet($self->getAccDataPRM(), $wb_out, $currency_format, $date_format);
}

sub createYearlyClosingReport {
	my( $self, $YTDStat) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $wb_out = Helpers::ExcelWorkbook->createWorkbook ( Helpers::MbaFiles->getYearlyClosingFilePath ( $YTDStat ) );
	my $currency_format = $wb_out->add_format( num_format => eval($prop->readParamValue('workbook.dashboard.currency.format')));
	my $date_format = $wb_out->add_format(num_format => $prop->readParamValue('workbook.dashboard.date.format'));
	
	$self->generateSummarySheet($YTDStat, $wb_out, $currency_format, $date_format);
	$self->generateMonthyYTDSheet($YTDStat, $wb_out, $currency_format, $date_format);
	$self->generateDetailsSheet($YTDStat, $wb_out, $currency_format, $date_format);

}

sub createForecastedCashflowReport {
	
	my( $self) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $wb_out = Helpers::ExcelWorkbook->createWorkbook ( Helpers::MbaFiles->getForecastedFilePath( $self->getAccDataMTD ) );
	my $currency_format = $wb_out->add_format( num_format => eval($prop->readParamValue('workbook.dashboard.currency.format')));
	my $date_format = $wb_out->add_format(num_format => $prop->readParamValue('workbook.dashboard.date.format'));
	my $current_format_actuals = $wb_out->add_format();
	$current_format_actuals->copy($currency_format);
	$current_format_actuals->set_pattern(17);
	
	$self->generateCashflowSheet( $self->getAccDataMTD(), $self->getAccDataPRM(), $wb_out, $currency_format, $date_format, $current_format_actuals);
}

sub createActualsReport {
	
	my( $self) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $wb_out = Helpers::ExcelWorkbook->createWorkbook( Helpers::MbaFiles->getActualsFilePath ( $self->getAccDataMTD ) );
	my $currency_format = $wb_out->add_format( num_format => eval($prop->readParamValue('workbook.dashboard.currency.format')));
	my $date_format = $wb_out->add_format(num_format => $prop->readParamValue('workbook.dashboard.date.format'));
	my $current_format_actuals = $wb_out->add_format();
	$current_format_actuals->copy($currency_format);
	$current_format_actuals->set_pattern(17);
	
	$self->generateDetailsSheet($self->getAccDataMTD(), $wb_out, $currency_format, $date_format);
	$self->generateCashflowSheet( $self->getAccDataMTD(), $self->getAccDataPRM(), $wb_out, $currency_format, $date_format, $current_format_actuals, "ActualReport");
	$self->generateVariationSheet ( $self->getAccDataMTD(), $wb_out, $currency_format, $date_format );
}

sub generateJSONWebreport {
	my( $self) = @_;
	$self->generateBudgetJSON();
	$self->generateDetailsJSON();
	$self->generateCashflowJSON();
}

sub computeCurrentMonthBudgetObjective {
	my( $self) = @_;
	my %currentMonthBudgetObjective;
	my $previousMonthObjective = Helpers::MbaFiles->readBudgetObjectiveCacheFile(Helpers::MbaFiles->getPreviousMonthCacheObjectiveFilePath ( $self->getAccDataPRM ) );
	my $monthlyBudgetObjective = $self->getAccDataMTD->getMontlyBudgetObjective();
	my $categoryToFollow = $self->getAccDataMTD->getCategoriesBudgetToFollow();
	my $logger = Helpers::Logger->new();
	
	my $totalObjectiveAchivement=0;
	foreach my $category (@$categoryToFollow) {
		my $a = $monthlyBudgetObjective->{$category};
		my $b = $a;
		if ( defined($previousMonthObjective) ) { $b = $previousMonthObjective->{$category} }	
		my @where = ('CATEGORY', $category);
		my $result = $self->getAccDataPRM->groupByWhere ('CATEGORY', 'DEBIT', \@where);
		my $c = abs(@$result[1]); # total en valeur absolue
		$totalObjectiveAchivement += ($c - $b);
	}
	my $nbrOfCategorie=scalar @$categoryToFollow;
	foreach my $category (@$categoryToFollow) {
		my $a = $monthlyBudgetObjective->{$category};
		$currentMonthBudgetObjective{$category} = $a - sprintf("%.2f", $totalObjectiveAchivement/$nbrOfCategorie);
	} 
    $logger->print ( "Writing current month objective cache file: ".Helpers::MbaFiles->getCurrentMonthCacheObjectiveFilePath ($self->getAccDataMTD), Helpers::Logger::DEBUG);
	Helpers::MbaFiles->writeBudgetObjectiveCacheFile(Helpers::MbaFiles->getCurrentMonthCacheObjectiveFilePath ($self->getAccDataMTD), \%currentMonthBudgetObjective);
}
	
sub generateBudgetJSON {
	my( $self) = @_;
	my %jsonRecord;
	# Date field
	$jsonRecord{'date'} = sprintf("%2d/%02d/%04d", $self->getAccDataMTD->getMonth->day(), $self->getAccDataMTD->getMonth->month(), $self->getAccDataMTD->getMonth->year() );
	my $logger = Helpers::Logger->new();
	
	# Labels fied
	my $categoryToFollow = $self->getAccDataMTD->getCategoriesBudgetToFollow();
	my @labels = @$categoryToFollow;
	push(@labels, "Total");
	$jsonRecord{'labels'} = \@labels;
	
	# Objectives current month objective and expected month to date
	my @dataObjecif;
	my @dataExpected;
	my $total=0;
	my $dtd = $self->getAccDataMTD->getMonth->day();
	my $currentMonthObjective = Helpers::MbaFiles->readBudgetObjectiveCacheFile(Helpers::MbaFiles->getCurrentMonthCacheObjectiveFilePath ( $self->getAccDataMTD ) );
	foreach my $category (@$categoryToFollow) {
		push(@dataObjecif, $currentMonthObjective->{$category});
		push(@dataExpected, sprintf("%.2f", $currentMonthObjective->{$category}*$dtd/31));
		$total += $currentMonthObjective->{$category};
	}
	push(@dataObjecif, $total);
	push(@dataExpected, sprintf("%.2f", $total*$dtd/31));
	$jsonRecord{'data_objectif'} = \@dataObjecif;
	$jsonRecord{'data_attendu'} = \@dataExpected;
	
	# Expenses by category
	my @dataExpenses;
	$total=0;

	foreach my $category (@$categoryToFollow) {
		my @where = ('CATEGORY', $category);
		my $result = $self->getAccDataMTD->groupByWhere ('CATEGORY', 'DEBIT', \@where);
		push(@dataExpenses, abs( @$result[1]) );
		$total += abs (@$result[1]);
	}
	push(@dataExpenses, $total);
	$jsonRecord{'data_depenses'} = \@dataExpenses;

	$logger->print ( "Writing JSON file budget.json" , Helpers::Logger::DEBUG);	
	Helpers::MbaFiles->writeJSONFile("budget.json", \%jsonRecord);
}

sub generateDetailsJSON {
	my( $self) = @_;
	my $operations = $self->getAccDataMTD->getOperations();
	my $categoryToFollow = $self->getAccDataMTD->getCategoriesBudgetToFollow();
	my @jsonOpsFiltered;
	my $logger = Helpers::Logger->new();

	if (defined $operations) {
		foreach my $category (@$categoryToFollow) {
			@jsonOpsFiltered = ();
			foreach my $op (@$operations ) {
				if ($op->{'CATEGORY'} eq $category) {
					my %record;
					$record{'Date'} = $op->{'DATE'};
					$record{'€'} = sprintf ("%.2f", abs($op->{'DEBIT'}) );
					$record{'Description '.$category} = $op->{'LIBELLE'};
					push(@jsonOpsFiltered, \%record);
			   }
			}
			$logger->print ( "Writing JSON file ".$category."_details.json" , Helpers::Logger::DEBUG);	
			Helpers::MbaFiles->writeJSONFile($category.'_details.json', \@jsonOpsFiltered);
		}
	}
	else {
		$logger->print ( "Can not generate Details.json because no operation yet this month" , Helpers::Logger::DEBUG);	
	}
	
}

sub generateCashflowJSON {
	my( $self) = @_;
	my $data;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $logger = Helpers::Logger->new();
	my %jsonRecord;

	my $workbook = Helpers::ExcelWorkbook->openExcelWorkbook( Helpers::MbaFiles->getActualsFilePath ( $self->getAccDataMTD ));	
	my $worksheet = $workbook->worksheet(1); # cashflow sheet	
	$data = Helpers::ExcelWorkbook->readFromExcelSheetDetails ($worksheet);

	if (defined $data) {

		# Date field
		$jsonRecord{'date'} = sprintf("%2d/%02d/%04d", $self->getAccDataMTD->getMonth->day(), $self->getAccDataMTD->getMonth->month(), $self->getAccDataMTD->getMonth->year() );


		# Labels JSON field (days of the month)
		my @labels;
		push (@labels, "00"); # To have the balance at the end of previous month
		for my $row ( 1 .. $#{$data} ) { # skipping the first line containing the column headers
			if (defined @$data[$row]->[0]) {
				if (@$data[$row]->[0]->{value} =~ qr[^(\d{1,2})/(\d{1,2})/(\d{4})$]) { #date column?
					push(@labels, $1);
				} else { next; }
			} else { next; }
		}
		$jsonRecord{'labels'} = \@labels;
		
		# data_attendu JSON field (balance per day real and expected expenses/incomes till the end of the month)
		my @balancePerDay;
		push (@balancePerDay, $self->getAccDataPRM()->getBalance() ); # start with the balance at the end of the previous month
		for my $row ( 1 .. $#{$data} ) { # skipping the first line containing the column headers
			my $totalLine = 0;
			for my $col ( 1 .. $#{@$data[$row]}-1 ) { # skipping the first colum containing the date and the last column containing the balance excel formula.
				if (defined @$data[$row]->[$col]) {
					if ( @$data[$row]->[$col]->{unformatted} =~ /^[+-]?\d+(\.\d+)?$/ ) { # currency column?
						$totalLine += @$data[$row]->[$col]->{unformatted}; 
					} else { next; }			
				} else { next; }
			}
			push (@balancePerDay, $balancePerDay[$#balancePerDay]+$totalLine); # sum the total of expenses/incomes of the day with the balance of day before
		}
		$jsonRecord{'data_attendu'} = \@balancePerDay;
		
		# data_depenses JSON field (balance month to date, based only on real expenes / incomes)
		my @balanceMTD;
		for my $i (0 .. $self->getAccDataMTD->getMonth->day() ) { # Go from 0 to the balance of the current day (last day of the month)
			push(@balanceMTD, $balancePerDay[$i]);
		}
		$jsonRecord{'data_depenses'} = \@balanceMTD;
		$logger->print ( "Writing JSON file cashflow.json", Helpers::Logger::DEBUG);	
		Helpers::MbaFiles->writeJSONFile("cashflow.json", \%jsonRecord);
	}
	else {
		$logger->print ( "Can not generate cashflow.json because no operation yet this month", Helpers::Logger::DEBUG);
	}
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
	$ws_out->set_column(0, 0,  25);
	$ws_out->set_column(2, 3,  25);
	$ws_out->set_column(1, 1,  20);
	$ws_out->set_column(4, 4,  15);
	$ws_out->set_zoom(85);
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
	$ws_out->set_column(3, 4,  22);
	$ws_out->set_column(5, 5,  52);
	$ws_out->set_column(6, 6,  10);
	$ws_out->set_zoom(85);
}

sub generateMonthyYTDSheet
{
	my ( $self, $statement, $wb_out, $currency_format, $date_format) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $wb_tpl = Helpers::ExcelWorkbook->openExcelWorkbook($prop->readParamValue("workbook.dashboard.template.path"));
	my $log = Helpers::Logger->new();
	
	### YTD sheet
	my $ws_tpl = $wb_tpl->worksheet( 3 );		
	my $ws_out = $wb_out->add_worksheet( $ws_tpl->get_name() );
	my $ops = $statement->getOperations();	
	
	if (defined $ops) {
		
		my $categories = $statement->getCategories();
		my $month = 1;
		my $row = 1;
		my $breakFam = "";
				
		my $fx_breakFam = $wb_out->add_format();
	    $fx_breakFam->set_bold();
	    my $fx_breakFam_tot_incomes = $wb_out->add_format();
	    $fx_breakFam_tot_incomes->set_bold();
	    my $fx_breakFam_tot_expenses = $wb_out->add_format();
	    $fx_breakFam_tot_expenses->set_bold();
	    
	    # First column : family and categories labels
	    $row = $self->displayYTDSheetHeaderCategories($statement, $wb_out, $ws_out, $row, 'CREDIT', $fx_breakFam);
	    $row+=1;
		$fx_breakFam_tot_incomes->set_bg_color('lime');
		$ws_out->write( $row, 0, 'TOTAL INCOMES', $fx_breakFam_tot_incomes );
	    $row+=2;
	    $row = $self->displayYTDSheetHeaderCategories($statement, $wb_out, $ws_out, $row, 'DEBIT', $fx_breakFam);
	    $row+=1;
	    $fx_breakFam_tot_expenses->set_bg_color('cyan');
		$ws_out->write( $row, 0, 'TOTAL EXPENSES', $fx_breakFam_tot_expenses );
	    $row+=2;
		$ws_out->write( $row, 0, 'MONTHLY RESULT', $fx_breakFam );
	    $row+=1;
		$ws_out->write( $row, 0, 'EOM BALANCE', $fx_breakFam );		
		
		my $col =1;
		
		# Sum of transaction amount per month colum and per category
		foreach $month (1 .. $statement->getDateTo()->month()) {
			$row = 1;
			my $monthyResult = 0;
			my $result = $self->displayYTDSheetData ($statement, $wb_out, $ws_out, $row, $col, $month, 'CREDIT', $currency_format );
			$row = @$result[0];
			$monthyResult += @$result[1];
			$row+=2;
			$result = $self->displayYTDSheetData ($statement, $wb_out, $ws_out, $row, $col, $month, 'DEBIT', $currency_format );
			$row = @$result[0];
			$monthyResult += @$result[1];
			$row+=2;
			$ws_out->write( $row, $col, $monthyResult, $currency_format );
			my $EOMBalance = 0;
			for (my $i=0; $i<$#{$ops}+1; $i++) {
				if (@$ops[$i]->{'MONTH'} == $month ) {
					$EOMBalance = @$ops[$i]->{'SOLDE'};
				}
				if (@$ops[$i]->{'MONTH'} > $month ) {
					last;
				}
			}
			$row+=1;
			$ws_out->write( $row, $col, $EOMBalance, $currency_format );
			$col++;
		}
		$ws_out->set_column(0, 0,  25);
		$ws_out->set_column(1, $col,  11);
		$ws_out->set_zoom(85);
	}

}

sub displayYTDSheetHeaderCategories {
	my( $self, $statement, $wb_out, $ws_out, $row, $type, $fx_breakFam ) = @_;
	
	my $categories = $statement->getCategories();
	my $breakFam = "";
	
			
	my $fx_out = $wb_out->add_format();
    
    # First column : family and categories labels
	foreach my $i (0 .. $#{$categories}) {
		if ( @$categories[$i]->{'TYPEOPE'} == (($type eq 'CREDIT') ? AccountStatement::Account::INCOME : AccountStatement::Account::EXPENSE) ) {

			if ( $breakFam ne @$categories[$i]->{'FAMILY'}) {
				$ws_out->write( $row, 0, @$categories[$i]->{'FAMILY'}, $fx_breakFam );
				$breakFam = @$categories[$i]->{'FAMILY'};
				$row++;
			}
			$ws_out->write( $row, 0, @$categories[$i]->{'CATEGORY'}, $fx_out );
			$row++;
		}
	}
	return $row;
}

sub displayYTDSheetData {
	my( $self, $statement, $wb_out, $ws_out, $row, $col, $month, $type, $currency_format ) = @_;
	
	my $categories = $statement->getCategories();
	my $found = 0;
	my $breakFam = "";
	my $totalType = 0;
	my @months = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
			
	my $fx_out = $wb_out->add_format();
	my $fx_breakFam = $wb_out->add_format();
    $fx_breakFam->set_bold();
	
	$ws_out->write( 0, $col, $months[$month-1] , $fx_out );
	
	foreach my $i (0 .. $#{$categories}) {
		if ( @$categories[$i]->{'TYPEOPE'} == (($type eq 'CREDIT') ? AccountStatement::Account::INCOME : AccountStatement::Account::EXPENSE) ) {

			# Jumping the row containing the breaking line
			if ( $breakFam ne @$categories[$i]->{'FAMILY'}) {
				$breakFam = @$categories[$i]->{'FAMILY'};
				$row++;
			}
			my @where = ('MONTH', $month, 'FAMILY', @$categories[$i]->{'FAMILY'});
			my $result = $statement->groupByWhere ('CATEGORY', ( (@$categories[$i]->{'TYPEOPE'}==AccountStatement::Account::INCOME) ? 'CREDIT' : 'DEBIT' ), \@where);
			$found = 0;
			my $pivot = @$result[0];
			foreach my $key ( keys %{$pivot} ) {
				if ( $key eq @$categories[$i]->{'CATEGORY'} ) {
					$ws_out->write( $row, $col, $pivot->{$key}, $currency_format );
					$totalType += $pivot->{$key};
					$found = 1;
					last;
				}
			}
			if (!$found) {
				$ws_out->write( $row, $col, 0, $currency_format );
			}
			$row++;
		}
	}
	$row+=1;
	my $currency_format_tot = $wb_out->add_format();
	$currency_format_tot->copy($currency_format);
	my $bg_color = ($type eq 'CREDIT') ? 'lime' : 'cyan'; 
	$currency_format_tot->set_bg_color($bg_color);
	$ws_out->write( $row, $col, $totalType, $currency_format_tot );
	return [$row, $totalType];
}

sub generateCashflowSheet
{
	my ( $self, $statMTD, $statPRM, $wb_out, $currency_format, $date_format, $current_format_actuals, $caller) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $wb_tpl = Helpers::ExcelWorkbook->openExcelWorkbook($prop->readParamValue("workbook.dashboard.template.path"));
	if (!defined $caller) { $caller = "notdefined"; }
	my $dt_currmonth = $statMTD->getMonth()->clone();
	
	my $dt_lastday =  DateTime->last_day_of_month( year => $dt_currmonth->year(), month => $dt_currmonth->month() );
	my $ws_tpl = $wb_tpl->worksheet( 2 );		
	my $ws_out = $wb_out->add_worksheet( $ws_tpl->get_name().'-'.sprintf ("%4d-%02d-%02d", $dt_currmonth->year, $dt_currmonth->month, $dt_currmonth->day ) );
	my $balance = 0;
	my $ops = $statPRM->getOperations();
	if (defined $ops) {
		$balance = @$ops[$#{$ops}]->{SOLDE};
	}
	
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
	
	my $startDay = 1;
	my @cashflow = ();

	$self->populateCashflowData (\@cashflow, $statMTD, $startDay , $dt_currmonth->day(), 'ACTUALS', $dt_currmonth );
	if ($dt_currmonth->day() < $dt_lastday->day() ) { # The current month is not ended.
		$startDay = $dt_currmonth->day()+1;
		$self->populateCashflowData (\@cashflow, $statPRM, $startDay, $dt_lastday->day(), 'FORECASTED', $dt_currmonth );
	
		# Add to forecasted cashflow section, the known planned operations
		my $plannedOpsObj = AccountStatement::PlannedOperation->new( $self->getAccDataMTD() );
		my $planOps = $plannedOpsObj->getPlannedOperations();
		my %isPlannedUpdated;
		for my $plan ( @$planOps ) {
			
			next unless ( not $plan->{'FOUND'} );
			
			my ($d,$m,$y) = $plan->{'DATE'} =~ /^([0-9]{2})\/([0-9]{2})\/([0-9]{4})\z/;
			my $planDate = DateTime->new(
		   		year      => $y,
		   		month     => $m,
		   		day       => $d,
		   		time_zone => 'local',
			);
			
			next unless ( (DateTime->compare( $planDate, $dt_lastday ) <= 0 ) );
			
			my $pday = $planDate->day();
			if (DateTime->compare( $planDate, $statMTD->getMonth() ) <= 0 ) { # The plan operation is before the last operation of the current month
				$pday = $statMTD->getMonth()->day() + 1;					  # the plan operation should be added to the family at the last current day+1
			}
			# Keep in memory (for later merging purpose with forecasted) the valule of the falimy.
			my $key = ($pday-1).$plan->{'FAMILY'};
			if (!defined $cashflow[$pday-1]->{ $plan->{'FAMILY'} }) {
				$isPlannedUpdated{$key} = 0;
				$cashflow[$pday-1]->{ $plan->{'FAMILY'} } = $plan->{'AMOUNT'};
			} else {
				if (!defined $isPlannedUpdated{$key}) { # keeping in memory the initial family value only
					$isPlannedUpdated{$key} = $cashflow[$pday-1]->{ $plan->{'FAMILY'} };
				}
				$cashflow[$pday-1]->{ $plan->{'FAMILY'} } += $plan->{'AMOUNT'};
			}
	
			my $comment = $plan->{'CATEGORY'};
			if (defined $plan->{'COMMENT'} && $plan->{'COMMENT'} ne "") { $comment = $plan->{'COMMENT'}; } 
			if (!defined $cashflow[$pday-1]->{ $plan->{'FAMILY'}." DETAILS" }) {
				$cashflow[$pday-1]->{ $plan->{'FAMILY'}." DETAILS" } = $comment."=".$plan->{'AMOUNT'};
			} else {
				$cashflow[$pday-1]->{ $plan->{'FAMILY'}." DETAILS" } .= "\n".$comment."=".$plan->{'AMOUNT'};
			}
		}
		
		# If the caller of this method is the ActualReport, do a merge with the forecasted report
		# Srategy merge: refer to the merge specification
		if ($caller eq "ActualReport") {
			my $workbook = Helpers::ExcelWorkbook->openExcelWorkbook( Helpers::MbaFiles->getForecastedFilePath ( $self->getAccDataMTD ));	
			my $worksheet = $workbook->worksheet( 0 ); # cashflow sheet
			my ( $row_min, $row_max ) = $worksheet->row_range();
			# Go throw each single cell of Forecasted report
			for (my $row=$startDay; $row <= $dt_lastday->day(); $row++) {
				for (my $col = 2; $col <=6; $col ++) {
					my $cell = $worksheet->get_cell( $row, $col );
					
					# Merge strategy is based on the comparison of 3 values : forecasted, isPlanned and actual.
					my $forecasted = undef;
					if (defined $cell) {
						if (length($cell) &&  $cell->unformatted() =~ /^[+-]?\d+(\.\d+)?$/ ) {$forecasted = $cell->unformatted() }
					}
					my $key = ($row-1).$worksheet->get_cell( 0, $col )->value(); # key for the isPlannedUpdated
					my $actual = $cashflow[$row-1]->{ $worksheet->get_cell( 0, $col )->value() };
					my $comment = $cashflow[$row-1]->{ $worksheet->get_cell( 0, $col )->value(). " DETAILS" };
					
					# Execute the merge strategy. Refer to the merge_specifications file for details.
					# case ID 2
					if (defined $forecasted && defined $isPlannedUpdated{$key} && defined $actual ) {
						if ($forecasted != $isPlannedUpdated{$key} && $forecasted != $actual) {
							$actual = $forecasted + ($actual - $isPlannedUpdated{$key});
							if (defined $comment) {$comment .= "\nMerge CaseID 2";} else { $comment = "Merge CaseID 2"; }
						}
					}
					# case ID 3
					if (defined $forecasted && !defined $isPlannedUpdated{$key} && !defined $actual ) { 
						$actual = $forecasted;
						$comment = "Merge CaseID 3";
					}
					# case ID 5
					if (!defined $forecasted && !defined $isPlannedUpdated{$key} && defined $actual ) { 
						$actual = undef;
						$comment = "Merge CaseID 5";
					}
					# case ID 6
					if (!defined $forecasted && defined $isPlannedUpdated{$key} && defined $actual ) {
						if ($isPlannedUpdated{$key} != 0) {
							$actual = $actual - $isPlannedUpdated{$key};
							if (defined $comment) {$comment .= "\nMerge CaseID 6";} else { $comment = "Merge CaseID 6"; }
						}
					}
					# case ID 7
					if (defined $forecasted && !defined $isPlannedUpdated{$key} && defined $actual ) {
						if ($forecasted != $actual) {
							$actual = $forecasted;
							$comment = "Merge CaseID 7";
						}
					}
					
					$cashflow[$row-1]->{ $worksheet->get_cell( 0, $col )->value()} = $actual;
					$cashflow[$row-1]->{ $worksheet->get_cell( 0, $col )->value(). " DETAILS" } = $comment;
				}
			}
		}
	}
	
	# Write the core sheet data
	foreach my $i (0 .. $#cashflow) {
		@dataRow = ( 
		 [
			$cashflow[$i]->{DATE},
			$cashflow[$i]->{WDAYNAME},
			$cashflow[$i]->{'MONTHLY INCOMES'},
			$cashflow[$i]->{'EXCEPTIONAL INCOMES'},
			$cashflow[$i]->{'MONTHLY EXPENSES'},
			$cashflow[$i]->{'WEEKLY EXPENSES'},
			$cashflow[$i]->{'EXCEPTIONAL EXPENSES'},
			'=H'.($i+1).'+SUM(C'.($i+2).':G'.($i+2).')'
		 ],
		 [ undef,
		   undef,
		   $cashflow[$i]->{'MONTHLY INCOMES DETAILS'},
		   $cashflow[$i]->{'EXCEPTIONAL INCOMES DETAILS'},
		   $cashflow[$i]->{'MONTHLY EXPENSES DETAILS'},
		   $cashflow[$i]->{'WEEKLY EXPENSES DETAILS'},
		   $cashflow[$i]->{'EXCEPTIONAL EXPENSES DETAILS'},
		   undef,
		 ]
		);
		my $type = 'FORECASTED';
		if ($i < $statMTD->getMonth()->day()) {
			$type = 'ACTUALS';
		}
		$self->displayDetailsDataRow ( $ws_out, $i+1, \@dataRow, $date_format, $currency_format, $current_format_actuals, $type ) ;	
	}
	
	# Write footer line
	my $row = $dt_lastday->day();
	@dataRow = (
	 [
		'',
		'',
		'',
		'',
		'',
		'',
		'Month Total Cashflow:',
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
	$ws_out->set_zoom(85);
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
	$ws_out->set_zoom(85);
}

sub populateCashflowData {
	my ( $self, $cashflow, $stat, $startDay, $endDay, $type, $dt_currmonth) = @_;
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
		push (@{$cashflow}, \%record);
	}
	my @where = ('FAMILY', 'MONTHLY EXPENSES');
	my $pivotDay = $stat->groupByWhere ('DAY', 'DEBIT', \@where);
	$self->populateCashflowMonthlyTransactions ( $stat, $cashflow, $startDay, $endDay, @$pivotDay[0], 'MONTHLY EXPENSES', 'DEBIT', $type);

	@where = ('FAMILY', 'MONTHLY INCOMES');
	$pivotDay = $stat->groupByWhere ('DAY', 'CREDIT', \@where);
	$self->populateCashflowMonthlyTransactions ( $stat, $cashflow, $startDay, $endDay, @$pivotDay[0], 'MONTHLY INCOMES', 'CREDIT', $type );

	@where = ('FAMILY', 'WEEKLY EXPENSES');
	$pivotDay = $stat->groupByWhere ('WDAY', 'DEBIT', \@where);
	$self->populateCashflowWeeklyTransactions ( $stat, $cashflow, $startDay, @$pivotDay[0], 'WEEKLY EXPENSES', 'DEBIT', $type );

	if ($type eq 'ACTUALS') { # the EXCEPTIONAL expenses or incomes are displayed only for actuals, not for forecasted
		@where = ('FAMILY', 'EXCEPTIONAL EXPENSES');
		$pivotDay = $stat->groupByWhere ('DAY', 'DEBIT', \@where);
		$self->populateCashflowMonthlyTransactions ( $stat, $cashflow, $startDay, $endDay, @$pivotDay[0], 'EXCEPTIONAL EXPENSES', 'DEBIT', $type );
	
		@where = ('FAMILY', 'EXCEPTIONAL INCOMES');
		$pivotDay = $stat->groupByWhere ('DAY', 'CREDIT', \@where);
		$self->populateCashflowMonthlyTransactions ( $stat, $cashflow, $startDay, $endDay, @$pivotDay[0], 'EXCEPTIONAL INCOMES', 'CREDIT', $type );
	}
}

sub displayPivotSumup {
	my( $self, $statement, $wb_out, $ws_out, $row, $col, $currency_format, $fx_out, $type ) = @_;
	my $rinit = $row;
	if (defined $statement->getOperations()) {
		
		my $categories = $statement->getCategories();
		my $found;
		my $breakFam = "";
				
		my $fx_breakFam = $wb_out->add_format();
	    $fx_breakFam->copy($fx_out);
	    $fx_breakFam->set_bold();

		
		foreach my $i (0 .. $#{$categories}) {
			if ( @$categories[$i]->{'TYPEOPE'} == (($type eq 'CREDIT') ? AccountStatement::Account::INCOME : AccountStatement::Account::EXPENSE) ) {
				my @where = ('FAMILY', @$categories[$i]->{'FAMILY'});
				my $result = $statement->groupByWhere ('CATEGORY', $type, \@where);
				if ( $breakFam ne @$categories[$i]->{'FAMILY'}) {
					$ws_out->write( $row, $col, @$categories[$i]->{'FAMILY'}, $fx_breakFam );
					$breakFam = @$categories[$i]->{'FAMILY'};
					$row++;
				}
				$ws_out->write( $row, $col, @$categories[$i]->{'CATEGORY'}, $fx_out );
				$found = 0;
				my $pivot = @$result[0];
				foreach my $key ( keys %{$pivot} ) {
					if ( $key eq @$categories[$i]->{'CATEGORY'} ) {
						$ws_out->write( $row, $col+1, $pivot->{$key}, $currency_format );
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
		$ws_out->write( $row, $col, 'TOTAL', $fx_tot ); 	
		$ws_out->write( $row+1, $col+1, '=SUM('.xl_rowcol_to_cell( $rinit, $col+1 ).':'.xl_rowcol_to_cell( $row-1, $col+1 ).')', $fx_sum );
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
	my( $self, $statement, $cashflow, $startDay, $endDay, $pivotDay, $family, $typeOpe, $type ) = @_;
	
	foreach my $day ( keys %{$pivotDay} )  { 
		if ( $day >= $startDay && $day <= $endDay) {
			@$cashflow[$day-1]->{$family} = $pivotDay->{$day};
			my @where = ('DAY', $day, 'FAMILY', $family);
			my $pivotCateg = $statement->groupByWhere ('CATEGORY', $typeOpe, \@where);
			@$cashflow[$day-1]->{$family.' DETAILS'} = $self->buildCategoryDetails ( @$pivotCateg[0] );
			
		} elsif ($day > $endDay && $type eq 'FORECASTED') {
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
	my( $self, $statement, $cashflow, $startDay, $pivotDay, $family, $typeOpe, $type ) = @_;
	
	my @pivotKeys = sort keys %{$pivotDay};
	my $lastWday = $pivotKeys[$#pivotKeys];
	foreach my $i ($startDay - 1 .. $#{$cashflow}) {
		my $wday = @$cashflow[$i]->{WDAY};
		if ( defined $pivotDay->{$wday} ) {
			@$cashflow[$i]->{$family} = $pivotDay->{$wday};
			my @where = ('WDAY', $wday, 'FAMILY', $family);
			my $pivotCateg = $statement->groupByWhere ('CATEGORY', $typeOpe, \@where);
			@$cashflow[$i]->{$family.' DETAILS'} = $self->buildCategoryDetails ( @$pivotCateg[0] );
		}
		elsif ($type eq 'FORECASTED' ) { #and $wday > $lastWday
			# Happen when last week of current month ends after the previous month
			# Example: current month, the last day of the week is a Tuesday and the previous month last day was Friday.
			# In other words, week days 4.1 and 4.2 does not exist in the previous month because ended at 3.7
			# Decision: take the week days of the first week of the previous month for populating the same week day of
			# the last week of the current month.
			# Sample: the wday 4.1 and 4.2 of the current month are populated with the 0.1 and 0.2 of the previous month.
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
	foreach my $categItem ( keys %{$categHash} ) {
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
	my $workbook = Helpers::ExcelWorkbook->openExcelWorkbook( Helpers::MbaFiles->getForecastedFilePath ( $self->getAccDataMTD ));	
	my $worksheet = $workbook->worksheet( 0 ); # cashflow sheet
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
	
	my $dth = Helpers::Date->new();	
	if (! defined $wkday) { $wkday = $dth->getDate()->wday(); }
	else {$wkday = 1;}
	
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
	my $forecastedEOMCashflow = 0;
	my $forecastedEOMBalance = 0;
	my $balanceRisk = 0;

	my $overdraft = $prop->readParamValue('alert.overdraft.threshold');
	my $workbook = Helpers::ExcelWorkbook->openExcelWorkbook( Helpers::MbaFiles->getActualsFilePath ( $self->getAccDataMTD ));	
	my $worksheet = $workbook->worksheet( 1 ); # cashflow sheet
	my ( $row_min, $row_max ) = $worksheet->row_range();
	my $initBalance = $worksheet->get_cell( 0, 7 )->unformatted();
	for (my $row=1; $row <= $row_max; $row++) {
		my $lineTot = 0;
		for (my $col = 2; $col <=6; $col ++) {
			my $cell = $worksheet->get_cell( $row, $col );
			next unless $cell;
			next unless length($cell);
			next unless $cell->unformatted() =~ /^[+-]?\d+(\.\d+)?$/; # is a amount?
			$lineTot += $worksheet->get_cell( $row, $col )->unformatted() ;
		}
		$forecastedEOMCashflow += $lineTot;
		if ( $risk == 0 ) { # no risk found yet
			$balanceRisk = $forecastedEOMCashflow + $initBalance;
			if ( $balanceRisk < $overdraft and $row > $dt_currmonth->day() ) { # 1st risk of bank overdraft in the future is detected
				$risk = $row;
			}
		}
		$forecastedEOMBalance = $forecastedEOMCashflow + $initBalance;
	}

	# Send the Monday report, if activated.
	my $mondayReport = $prop->readParamValue('mondays.report.active');
	my $var = $currentBalance-$plannedBalance;
	if ( $mondayReport eq "yes" && $wkday == 1) { 
		my $subject = "Balance Control Report";
		$log->print ( "Email sending: $subject: Actuals:$currentBalance, Planned:$plannedBalance, Variation:$var", Helpers::Logger::INFO);
		my $mail = Helpers::SendMail->new(
			$subject." - ".sprintf ("%4d-%02d-%02d", $dt_currmonth->year(), $dt_currmonth->month(), $dt_currmonth->day()),
			"alert.body.template"
		);
		$mail->buildBalanceAlertBody ($self, $statMTD, $initBalance, $currentBalance, $plannedBalance, $forecastedEOMBalance, $forecastedEOMCashflow);
		$mail->send();
	}

	if ($currentBalance < $overdraft ) { # Send an alert in case of current bank overdraft.
		my $subject = "!!!ALERT!!! Bank Overdraft is Ongoing";
		$log->print ( "Email sending: $subject: Actuals:$currentBalance", Helpers::Logger::INFO);
		my $mail = Helpers::SendMail->new(
			$subject." - ".sprintf ("%4d-%02d-%02d", $dt_currmonth->year(), $dt_currmonth->month(), $dt_currmonth->day()),
			"alert.overdraft.body.template"
		);
		$mail->buildOverdraftAlertBody ($self, $statMTD, $currentBalance, $dt_currmonth );
		$mail->send();
		
	} elsif ($risk > 0 ) { # Found a risk if bank overdraft before the end of the month
		my $subject = "!Warning! Risk of Bank Overdraft is detected";
		$log->print ( "Email sending: $subject: forecasted:$balanceRisk on the $risk", Helpers::Logger::INFO);
		my $mail = Helpers::SendMail->new(
			$subject." - ".sprintf ("%4d-%02d-%02d", $dt_currmonth->year(), $dt_currmonth->month(), $dt_currmonth->day()),
			"alert.risk.overdraft.body.template"
		);
		$mail->buildOverdraftAlertBody ($self, $statMTD, $balanceRisk, $dt_currmonth->set_day($risk) );
		$mail->send();
	}
}

sub sumForecastedOperationPerFamily {
	my( $self, $family ) = @_;
	my $statMTD = $self->getAccDataMTD;
	my $dt_currmonth =  $statMTD->getMonth();
	my $totFam = 0;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $workbook = Helpers::ExcelWorkbook->openExcelWorkbook( Helpers::MbaFiles->getForecastedFilePath ( $self->getAccDataMTD ) );	
	my $worksheet = $workbook->worksheet(0); # cashflow sheet
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

sub getAccDataPRM {
	my( $self) = @_;
	return $self->{_accDataPRM};		
}

sub getAccDataMTD {
	my( $self) = @_;
	return $self->{_accDataMTD};		
}

1;
