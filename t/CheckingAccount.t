use Test::More tests => 24;
# use Test::More qw( no_plan );
use lib '../lib';
use Data::Dumper;
use diagnostics;
use warnings;
use strict;
use WebConnector::GenericWebConnector;
use Helpers::Statement;
use DateTime;

#do 'Helpers/ConfReader.pm';
require_ok "AccountStatement::CheckingAccount";

my $dt = DateTime->new(
	   year      => 2015,
	   month     => 5,
	   day       => 31,
	   time_zone => 'local',
	);
	
my $statement = Helpers::Statement->buildCurrentMonthStatement("./accounts/config.0303900020712303.xls", $dt );

is($statement->getBankName(), 'CREDITMUTUEL_MOCK', 'Get bank name from t.categrories.xls');
is($statement->getAccountNumber(), '03039 000207123 03', 'Get Account number from t.categrories.xls');
is($statement->getAccountDesc(), 'Marc & Sophie joint account', 'Get Account description from t.categrories.xls');
my $categories = $statement->getCategories();

# print Dumper $categories, "\n";
# print Dumper $statement->getDefault(), "\n";

is(@$categories[0]->{CATEGORY}, 'Marc', 'Get the first user category in t.categrories.xls');
is(@$categories[0]->{FAMILY}, 'MONTHLY INCOMES', 'Get the family of this first category');
is(@$categories[0]->{TYPEOPE}, 2, 'Get the operation type of this first category');
is_deeply(@$categories[0]->{KEYWORDS}, ['ADP GESTION DES PAIEMENT'], 'Get the keywords of this first category');
is(@$categories[$#{$categories}]->{CATEGORY}, 'Divers', 'Get the last user category in t.categrories.xls');

=cut
# Citibank testing
open my $in, "<", "t.citibank.bankdata.ofx" or die "Can't open file t.citibank.bankdata.ofx file!\n";
read $in, my $ofx, -s $in;
close $in;	

open $in, "<", "t.citibank.bankdata.qif" or die "Can't open file t.citibank.bankdata.qif file!\n";
read $in, my $qif, -s $in;
close $in;

my $parser = WebConnector::GenericWebConnector->new();
my $balance = $parser->parseOFXforBalance($ofx, '.');
my $bankData = $parser->parseQIF ($qif, '([0-9]{2})-([0-9]{2})-([0-9]{4})', 1, '', '.');
# $parser->forwardBalanceCompute ( $bankData, $balance );

my $operations = $statement->parseBankStatement($bankData);
# print Dumper $operations, "\n";
=cut

# CM testing

my $operations = $statement->getOperations();

is(@$operations[0]->{FAMILY}, "EXCEPTIONAL EXPENSES", 'Check whether the 1st operation family is a Exceptional Expenses');
is(@$operations[34]->{TYPE}, 2, 'Check whether the 34th operation is qualifed as income');
is(@$operations[83]->{FAMILY}, "MONTHLY INCOMES", 'Check whether the 30th operation is requlifed as exceptional incomes');
is(@$operations[89]->{DEBIT}, '-46.80', 'Check whether the 51st operation expenses value');
is(@$operations[$#{$operations}]->{SOLDE}, 8075.14, 'Check the solde of the last operation');
is(@$operations[63]->{SOLDE}, 8375.17, 'Check the solde at the 63th operation');

# print Dumper $operations, "\n";

my $pivot1 = $statement->groupBy ('CATEGORY', 'CREDIT');
# print Dumper @$pivot1[0], "\n";
# print "total: ", @$pivot1[1],"\n";
is(@$pivot1[0]->{'Marc'}, 2757, 'Check Marc total category');
is(@$pivot1[0]->{'Laper'}, 130, 'Check Laper total category');
is(@$pivot1[1], 4945.8, 'Check total credits');

my $pivot2 = $statement->groupBy ('CATEGORY', 'DEBIT');
# print Dumper @$pivot2[0], "\n";
# print "total: ", @$pivot2[1],"\n";
is(@$pivot2[0]->{'Assurance'}, -127.3, 'Check Assurance total category');
is(@$pivot2[0]->{'Depenses courantes'}, -1243.43, 'Check Depenses courantes total category');
is(@$pivot2[1], -7870.73, 'Check total debits');

my $date = $statement->getMonth();
is($date->month(), 5, 'Month of the statement is May');

my %line;
	#	{
    #      'DATE' => 'DD/MM/YYYY',
    #      'AMOUNT' => -NNNN.NN,
   	#      'DETAILS' => 'A string describing the transaction',
    #      'BALANCE' => -NNNN.NN,
    #    },
$line{'DATE'} = '12/05/15';
$line{'AMOUNT'} = -230.50;
$line{'DETAILS'} = 'NATURALIA';
$line{'BALANCE'} = 0;
my $id = $statement->findOperationsCatagoryId(\%line);
is(@$categories[$id]->{FAMILY}, 'WEEKLY EXPENSES', 'Find a fictive operation familly, NATURALIA = WEEKLY EXPENSES');

$line{'DATE'} = '12/05/15';
$line{'AMOUNT'} = 230.50;
$line{'DETAILS'} = 'NATURALIA';
$line{'BALANCE'} = 0;
$id = $statement->findOperationsCatagoryId(\%line);
is(@$categories[$id]->{FAMILY}, 'EXCEPTIONAL INCOMES', 'Find a fictive operation familly, Inconsistence converted to EXCEPTIONAL INCOMES');



