package AccountStatement::CheckingAccount;

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
use Spreadsheet::ParseExcel;


sub new
{
    my ($class, $configFilePath, $dt_to ) = @_;
    my $prop = Helpers::ConfReader->new("properties/app.txt");
    my $logger = Helpers::Logger->new();
    $logger->print ( "Opening account config file: $configFilePath", Helpers::Logger::DEBUG);
    
    my $self = {
    	_bankName => initBankName($prop, $configFilePath),
    	_accountNumber =>	initAccountNumber($prop, $configFilePath),
    	_accountDesc =>	initAccountDesc($prop, $configFilePath),
    	_accountAuth => initAccountAuth ($prop, $configFilePath),
    	_categories => 	undef,
    	_default => undef,
    	_operations => undef,
    	_balance => 0,
    	_dt_to => $dt_to,
    };
    if ( !defined $self->{_accountNumber} ) { $logger->print (  "bank account number value not found!", Helpers::Logger::ERROR); die; }
    bless $self, $class;
    initCategoriesAndDefault($self, $prop, $configFilePath);
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

sub initCategoriesAndDefault {
	my ($self, $prop, $configFilePath) = @_;
	my $workbook = Helpers::ExcelWorkbook->openExcelWorkbook( $configFilePath );	
	my $worksheet = $workbook->worksheet($prop->readParamValue("worksheet.categories.name"));		
	my ( $row_min, $row_max ) = $worksheet->row_range();
	my @categories;
	my @default;
	
	my $id = 0;
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
		if ($#{$record{KEYWORDS}} == -1) { # no keyword defiened for this category.
			$categories[$id++] = \%record;
		} else {
			my $defaultKey = ($prop->readParamValue("operation.keyword.default"));
			if ( ${$record{KEYWORDS}}[0] =~ m/$defaultKey/i ) {
				addDefault (\@default, $1, $record{TYPEOPE}, $id);
			}
			$categories[$id++] = \%record;
		}
	}
	$self->{_categories} = \@categories;
	@default = sort { $a->{LIMIT} <=> $b->{LIMIT} || $a->{TYPE} <=> $b->{TYPE} } @default;
	$self->{_default} = \@default;
}

sub validateFamily {
	# validate if the family exists and whether its a income or an expense family.
	# Return 0 for unknown family, return INCOME for an income family, EXPENSE for expense family.
	my( $prop, $family ) = @_;
	my $operationType = 0;
	my $incomeFamilies = $prop->readParamValueList("income.families");
	foreach my $item (@$incomeFamilies) {
		next unless uc $item eq uc $family;
		$operationType = AccountStatement::Account::INCOME;
		last;
	}
	if ($operationType == 0) {
		my $expenseFamilies = $prop->readParamValueList("expense.families");
		foreach my $item (@$expenseFamilies) {
			next unless uc $item eq uc $family;
			$operationType = AccountStatement::Account::EXPENSE;
			last;
		}
	}
	return $operationType;
}

sub trim {
	my ($str) = @_;
	return $str =~ s/^\s+|\s+$//gr;
}

sub addDefault {
	my( $default, $limit, $type, $index ) = @_;
	
 	# Default data structure (_default):
	# [ 
	#	{
    #      'TYPE' => 'INCOME / EXPENSE',  # Is this a default for income or expense
    #      'INDEX' => 0...N,		  # This is the category index in the arry _categories
   	#      'LIMIT' => 'NNN',			  # Allow several default category for income or expense. 
   	# 										Assign an operation to this category if its amount is >= NNN   
    #    },
    #    {
    #		...
	#	 }
    # ]
		
	my %record;
	$record{TYPE} = $type;
	$record{INDEX} = $index;
	if ($type == AccountStatement::Account::EXPENSE) {$limit = -$limit; }
	$record{LIMIT} = $limit;
	push ($default, \%record);	
}

sub isCategDefault {
	my ($self,  $id ) = @_;
	my $default = $self->{_default};
	for (my $i=0; $i<$#{$default}+1; $i++) {
		if (@$default[$i]->{INDEX} == $id) {
			return 1;
		}
	}
	return 0;
}

sub findDefaultCategId {
	my( $self, $amount, $type ) = @_;
	my $default = $self->{_default};
	my $id0;
	# Find the index of DEFAULT-O for EXPENSE or for INCOME in the default array
	if ($type == AccountStatement::Account::EXPENSE ) {
		$id0 = 0;
		while (@$default[$id0]->{TYPE} == $type ) { $id0++; }
	}
	else {
		$id0 = $#{$default};
		while (@$default[$id0]->{TYPE} == $type ) { $id0--; }		
	}
	# Find the index for which the 
	my $id;
	if ( $type == AccountStatement::Account::EXPENSE ) {
		$id = 0;
		while ( $id < $id0 && $amount > @$default[$id]->{LIMIT} ) {
			$id++;
		}
	} else {
		$id = $#{$default};
		while ( $id > $id0 && $amount < @$default[$id]->{LIMIT} ) {
			$id--;
		}		
	}
	return @$default[$id]->{INDEX};

}

sub findOperationsCatagoryId {
	my( $self, $line ) = @_;
	my $logger = Helpers::Logger->new();
	my $categories = $self->getCategories();
	my $default = 1;
	my $i=0;
	for ($i=0; $i<$#{$categories}+1; $i++) {
		if ( not isCategDefault( $self, $i ) ) {
			my $keywords = @$categories[$i]->{KEYWORDS};
			foreach my $keyword (@$keywords) {
				if ($keyword ne '' && $line->{DETAILS} =~ /$keyword/) {
					$default = 0;
					last;
				}
			}
			if (not $default) { last; }
		}
	}
	# Check the consistency of operation type and category family
	if (not $default) {
		if ( ($line->{AMOUNT} >= 0 && @$categories[$i]->{TYPEOPE} == AccountStatement::Account::EXPENSE)
			|| ($line->{AMOUNT} < 0 && @$categories[$i]->{TYPEOPE} == AccountStatement::Account::INCOME) ) {
				$logger->print ( "Inconsistency: $line->{DETAILS} / $line->{AMOUNT} / @$categories[$i]->{TYPEOPE}", Helpers::Logger::INFO);
				$default = 1; #for managing inconsistency, requalify the operation as a defaut one
		}
	}
	
	if ($default) {
		if ($line->{AMOUNT} < 0) { # It's an expense
			$i = findDefaultCategId ($self, $line->{AMOUNT}, AccountStatement::Account::EXPENSE);
		}
		else { # It's an income
			$i = findDefaultCategId ($self, $line->{AMOUNT}, AccountStatement::Account::INCOME);
		}
	}
	return $i;
	
}

sub findOperationsFamily {
	my( $self, $line ) = @_;
	my $categories = $self->getCategories();
	return @$categories[$self->findOperationsCatagoryId($line)]->{FAMILY};
	
}

sub findOperationsCategory {
	my( $self, $line ) = @_;
	my $categories = $self->getCategories();
	return @$categories[$self->findOperationsCatagoryId($line)]->{CATEGORY};
	
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
    
    if ($#{$bankData} < 0) {return undef;} # No operation has been downloaded...
    
	my $categories = $self->getCategories();
	my @operations;

	foreach my $line (@$bankData) {
		push (@operations, buildExtendedRecord($line, @$categories[$self->findOperationsCatagoryId($line)]));
	}
	$self->{_operations} = \@operations;
	
	my ($d,$m,$y) = $operations[$#operations]->{DATE} =~ /^([0-9]{2})\/([0-9]{2})\/([0-9]{4})\z/;
	my $date = DateTime->new(
	   year      => $y,
	   month     => $m,
	   day       => $d,
	   time_zone => 'local',
	);	
	
	$self->{_dt_to} = $date;
	$self->{_balance} = @$bankData[$#{$bankData}]->{'BALANCE'};
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
	$operationRecord{WDAYNAME}	= $date->day_name();		
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
	my %pivot = ();
	my $tot = 0;
	if (defined $ope) {
		for (my $i=0; $i<$#{$ope}+1; $i++) {
			if (defined @$ope[$i]->{$value} && @$ope[$i]->{$value} ne '') {
				$pivot{@$ope[$i]->{$key}} += @$ope[$i]->{$value};
				$tot += @$ope[$i]->{$value};
			}
		}
	}
	return [\%pivot, $tot];
}

sub groupByWhere {
	my( $self, $key, $value, $where ) = @_;
	my $ope = $self->getOperations();
	my %pivot = ();
	my $tot = 0;
	
	if (defined $ope) {
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
	}
	return [\%pivot, $tot];
}

sub saveBankData {
	my( $self ) = @_;
	my $ops = $self->getOperations ();
	my $logger = Helpers::Logger->new();
	my $opsTxt="";
	for my $record (@$ops) {
		my $amount = ( defined $record->{CREDIT} ) ? $record->{CREDIT} : $record->{DEBIT};
		$opsTxt .= $record->{DATE}.';'.$amount.';'.$record->{LIBELLE}.';'.$record->{SOLDE}."\n";
	}
	open OUT, ">", Helpers::MbaFiles->getPreviousMonthCacheFilePath ( $self ) or
		$logger->print ( "File ".Helpers::MbaFiles->getPreviousMonthCacheFilePath ( $self )." cant't be written!", Helpers::Logger::ERROR);
	print OUT $opsTxt;
	close OUT;
}

sub loadBankData {
	my( $self ) = @_;
	my @bankData;
	my $logger = Helpers::Logger->new();
	open IN, "<", Helpers::MbaFiles->getPreviousMonthCacheFilePath ( $self ) or do {
		$logger->print ( "File ".Helpers::MbaFiles->getPreviousMonthCacheFilePath ( $self )." cant't be opened!", Helpers::Logger::INFO);
		return 0;
	};
	while ( my $line = <IN> ) {
		$line =~ s/\r|\n//g;
		my @recTxt = split (';', $line);
		my %record;
		$record{'DATE'} = $recTxt[0];
		$record{'AMOUNT'} = $recTxt[1];
		$record{'DETAILS'} = $recTxt[2];
		$record{'BALANCE'} =$recTxt[3];
		push (@bankData, \%record);
	}
	close IN;
	$self->parseBankStatement(\@bankData);
	return 1;
	
}	

sub mergeWithAnotherStatement {
	my( $self, $otherStat ) = @_;
	my $ops = $self->getOperations();
	my $otherOps = $otherStat->getOperations();
	
	if (defined $ops) {
		my $record;
		foreach $record (@$otherOps) {
			push (@$ops, $record);
		}
		$self->{_balance} = $otherStat->getBalance();
		$self->{_dt_to} = $otherStat->getMonth();
	} else {
		$self->{_operations} = $otherOps;
		$self->{_balance} = $otherStat->getBalance();
		$self->{_dt_to} = $otherStat->getMonth();
	}
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
	return $self->{_dt_to};		
}

sub getDateTo {
	my( $self) = @_;
	return $self->{_dt_to};		
}

sub getDefault {
	my( $self) = @_;
	return $self->{_default};		
}

sub getBalance {
	my( $self) = @_;
	return $self->{_balance};		
}

1;
