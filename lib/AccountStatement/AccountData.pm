package AccountStatement::AccountData;

use lib '../../lib';
use strict;
use warnings;
use DateTime;
use Helpers::ConfReader;
use utf8;
use Helpers::Logger;
use Helpers::Date;
use Helpers::ExcelWorkbook;
use Spreadsheet::ParseExcel;


use constant INCOME		=> 1;
use constant EXPENSE	=> 2;

sub new
{
    my ($class, $configFilePath, $dtMonth) = @_;
    
    my $prop = Helpers::ConfReader->new("properties/app.txt");
    my $logger = Helpers::Logger->new();
 
    
    my $self = {
    	_bankName => initBankName($prop, $configFilePath),
    	_accountNumber =>	initAccountNumber($prop, $configFilePath),
    	_accountDesc =>	initAccountDesc($prop, $configFilePath),
    	_accountAuth => initAccountAuth ($prop, $configFilePath),
    	_categories => 	initCategoriesDefinition($prop, $configFilePath),
    	_operations => undef,
    	_month => $dtMonth,
    };
    if ( !defined $self->{_accountNumber} ) { $logger->print (  "bank account number value not found!", Helpers::Logger::ERROR); die; }
    bless $self, $class;
    return $self;
}

sub initAccountDesc {
	my ($prop, $configFilePath) = @_;
	return lookForPairKeyValue($prop, $prop->readParamValue("account.desc.label"), $configFilePath);	
}

sub initAccountNumber {
	my ($prop, $configFilePath) = @_;
	return lookForPairKeyValue($prop, $prop->readParamValue("account.number.label"), $configFilePath);
}

sub initBankName {
	my ($prop, $configFilePath) = @_;
	return lookForPairKeyValue($prop, $prop->readParamValue("bank.name.label"), $configFilePath);	
	
}

sub initAccountAuth {
	my ($prop, $configFilePath) = @_;
	return lookForPairKeyValue($prop, $prop->readParamValue("account.user.auth"), $configFilePath);	
}

sub lookForPairKeyValue {
	my ($prop, $key, $configFilePath) = @_;
	my $workbook = Helpers::ExcelWorkbook->openExcelWorkbook( $configFilePath );	
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
	my ($prop, $configFilePath) = @_;
	my $workbook = Helpers::ExcelWorkbook->openExcelWorkbook( $configFilePath );	
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
	my( $self, $bankData ) = @_;
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
    #

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
	
	my ($d,$m,$y) = $operations[$#operations]->{DATE} =~ /^([0-9]{2})\/([0-9]{2})\/([0-9]{4})\z/;
	my $date = DateTime->new(
	   year      => $y,
	   month     => $m,
	   day       => $d,
	   time_zone => 'local',
	);	
	
	$self->{_month} = $date;
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

sub getAccountAuth {
	 my( $self ) = @_;
	return $self->{_accountAuth};
}

sub getCategories {
	my( $self) = @_;
	return $self->{_categories};	
}

sub getOperations {
	my( $self) = @_;
	return $self->{_operations};		
}

sub getMonth {
	my( $self) = @_;
	return $self->{_month};		
}

1;