package AccountStatement::AccountData;

use lib '../../lib';
use strict;
use warnings;
use DateTime;
use Helpers::ExcelWorkbook;
use Spreadsheet::ParseExcel;
use Spreadsheet::XLSX;
use Helpers::ConfReader;

use constant INCOME		=> 1;
use constant EXPENSE	=> 2;

sub new
{
    my ($class) = @_;
    
    my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $bankAccountNumber = initAccountNumber($prop); # return the bank account number and the row number position
    my $self = {
    	_accountNumber =>	$bankAccountNumber,
    	_categories => 	initCategoriesDefinition($prop),
    	_operations => undef
    };
    if ( !defined $self->{_accountNumber} ) { die "bank account number value not found!"; }
    bless $self, $class;
    return $self;
}

sub initAccountNumber {
	my ($prop) = @_;
	my $workbook = Helpers::ExcelWorkbook->openExcelWorkbook($prop->readParamValue("workbook.categories.path"));	
	my $worksheet = $workbook->worksheet($prop->readParamValue("worksheet.categories.name"));		
	my ( $row_min, $row_max ) = $worksheet->row_range();
	my $bankAccountNumber;
	my $row;
	for $row ( $row_min .. $row_max ) {
		my $cell = $worksheet->get_cell( $row, 0 );
		next unless $cell && uc $cell->value() eq $prop->readParamValue("account.number.label");
		$bankAccountNumber = $worksheet->get_cell( $row, 1 )->value();
		last;
	}
	return $bankAccountNumber;	
	
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

sub loadExtendedOperation {
	my( $self, $csvBankData) = @_;
	# The raw bank data should be a CSV string.
	# Expected columns are: [0]Date d'opŽration;[1]Date de valeur;[2]DŽbit;[3]CrŽdit;[4]LibellŽ;[5]Solde
	
	my $categories = $self->getCategories();
	my @fields;
	my @operations;

	my @lines = map {   
		s/\r|\n//g;
		$_ 
	} split '\n', $csvBankData;

	foreach my $line (@lines) {
		@fields = split(';', $line);
		my $default = 1;
		my $i;
		for ($i=2; $i<$#{$categories}+1; $i++) {
			my $keywords = @$categories[$i]->{KEYWORDS};
			foreach my $keyword (@$keywords) {
				if ($keyword ne '' && $fields[4] =~ /$keyword/) {
					$default = 0;
					last;
				}
			}
			if (not $default) { last; }
		}
		if (not $default) {
			# Check the consistency of operation type and category family
			if ( ($fields[2] =~ /\d+/ && @$categories[$i]->{TYPEOPE} == EXPENSE)
			  || ($fields[3] =~ /\d+/ && @$categories[$i]->{TYPEOPE} == INCOME) ) {
				push (@operations, buildExtendedRecord(\@fields, @$categories[$i]));
			}
			else {
				# TODO: log this unexpected case
				# warn "Inconsistency: ", $fields[4], "-", $fields[2], "/", @$categories[$i]->{TYPEOPE}, "/", $fields[3], "/","\n";
				$default = 1; #for managing inconsistency, requalify the operation as a defaut one
			}
		}
		if ($default) {
			if ($fields[2] =~ /\d+/) { # It's an expense
				push (@operations, buildExtendedRecord(\@fields, @$categories[1]));
			}
			elsif ($fields[3] =~ /\d+/) { # It's an income {
				push (@operations, buildExtendedRecord(\@fields, @$categories[0]));
			} else {
				# TODO: log this unexpected case
				# warn "Inconsistency: ", $fields[4], " is neither an income nor an expense\n";
				next; #skip this line of CSV string which is neither an expense nor an income
			}
		}
	}
	$self->{_operations} = \@operations;
	return \@operations;
}

sub buildExtendedRecord {
	my( $fields, $categoryRecord) = @_;
	my %operationRecord;
	
	$operationRecord{DATEOPE}	= @$fields[0];
	$operationRecord{DATEVALUE}	= @$fields[1];
	$operationRecord{DEBIT}		= @$fields[2];
	$operationRecord{CREDIT}	= @$fields[3];
	$operationRecord{TYPEOP}	= $categoryRecord->{TYPEOPE};
	$operationRecord{FAMILY}	= $categoryRecord->{FAMILY};
	$operationRecord{CATEGORY}	= $categoryRecord->{CATEGORY};
	$operationRecord{LIBELLE}	= @$fields[4];		
	$operationRecord{SOLDE}		= @$fields[5];	
	
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

sub dumpOperations {
	my( $self, $filePath ) = @_;
	open CSV, ">", $filePath or die "Couldn't open file $filePath\n";
	my $ope = $self->getOperations();
	print CSV 	'DATEOPE', ",",
				'DATEVALUE',",",
				'DEBIT', ",",
				'CREDIT', ",",
				'TYPEOP', ",",
				'FAMILY', ",",
				'CATEGORY', ",",
				'LIBELLE', ",",		
				'SOLDE', ",",
			"\n";

	for (my $i=0; $i<$#{$ope}+1; $i++) {
		print CSV 	@$ope[$i]->{DATEOPE}, ",",
					@$ope[$i]->{DATEVALUE},",",
					@$ope[$i]->{DEBIT}, ",",
					@$ope[$i]->{CREDIT}, ",",
					@$ope[$i]->{TYPEOP}, ",",
					@$ope[$i]->{FAMILY}, ",",
					@$ope[$i]->{CATEGORY}, ",",
					@$ope[$i]->{LIBELLE}, ",",		
					@$ope[$i]->{SOLDE}, ",",
				"\n";
	}
	close CSV;		
}

sub getAccountNumber {
	 my( $self ) = @_;
	return $self->{_accountNumber};
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