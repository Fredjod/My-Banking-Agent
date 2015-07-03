use Test::More tests => 22;
# use Test::More qw( no_plan );
use lib '../lib';
use Data::Dumper;
use diagnostics;
use warnings;
use strict;
use WebConnector::GenericWebConnector;

#do 'Helpers/ConfReader.pm';
require_ok "AccountStatement::AccountData";
my $data = AccountStatement::AccountData->new ();
is($data->getBankName(), 'CREDIT MUTUEL', 'Get bank name from t.categrories.xls');
is($data->getAccountNumber(), '033033050050029', 'Get Account number from t.categrories.xls');
is($data->getAccountDesc(), 'Jacques & Sophie joint account', 'Get Account description from t.categrories.xls');
my $categories = $data->getCategories();
# print Dumper $categories, "\n";
is(@$categories[0]->{FAMILY}, 'EXCEPTIONAL INCOMES', 'Get the family of default income category in t.categrories.xls');
is(@$categories[1]->{FAMILY}, 'WEEKLY EXPENSES', 'Get the family of default expense category in t.categrories.xls');
is(@$categories[2]->{CATEGORY}, 'Jacques', 'Get the first user category in t.categrories.xls');
is(@$categories[2]->{FAMILY}, 'MONTHLY INCOMES', 'Get the family of this first category');
is(@$categories[2]->{TYPEOPE}, 1, 'Get the operation type of this first category');
is_deeply(@$categories[2]->{KEYWORDS}, ['ADP GESTION DES PAIEMENT'], 'Get the keywords of this first category');
is(@$categories[$#{$categories}]->{CATEGORY}, 'Divers', 'Get the last user category in t.categrories.xls');

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
$parser->forwardBalanceCompute ( $bankData, $balance );

my $operations = $data->parseBankStatement($bankData);
# print Dumper $operations, "\n";


# CM testing
open $in, "<", "t.cm.bankdata.ofx" or die "Can't open file t.cm.bankdata.ofx file!\n";
read $in, $ofx, -s $in;
close $in;	

open $in, "<", "t.cm.bankdata.qif" or die "Can't open file t.cm.bankdata.qif file!\n";
read $in, $qif, -s $in;
close $in;

$parser = WebConnector::GenericWebConnector->new();
$balance = $parser->parseOFXforBalance($ofx, '.');
$bankData = $parser->parseQIF ($qif, '([0-9]{2})\/([0-9]{2})\/([0-9]{2})', 0, ',', '.');
$parser->backwardBalanceCompute ( $bankData, $balance );

$operations = $data->parseBankStatement($bankData);
is(@$operations[0]->{FAMILY}, "WEEKLY EXPENSES", 'Check whether the 1st operation family');
is(@$operations[29]->{TYPEOP}, 1, 'Check whether the 30th operation is requlifed as incomes (insurrance return)');
is(@$operations[29]->{FAMILY}, "EXCEPTIONAL INCOMES", 'Check whether the 30th operation is requlifed as exceptional incomes');
is(@$operations[52]->{DEBIT}, -17.51, 'Check whether the 51st operation expenses value');
is(@$operations[$#{$operations}]->{SOLDE}, 7949.07, 'Check the solde of the last operation');

# print Dumper $operations, "\n";

my $pivot1 = $data->groupBy ('CATEGORY', 'CREDIT');
# print Dumper @$pivot1[0], "\n";
# print "total: ", @$pivot1[1],"\n";
is(@$pivot1[0]->{'Jacques'}, 1733, 'Check Jacques total category');
is(@$pivot1[0]->{'Autres'}, 1651.23, 'Check Autres total category');
is(@$pivot1[1], 4395.9, 'Check total credits');

my $pivot2 = $data->groupBy ('CATEGORY', 'DEBIT');
# print Dumper @$pivot2[0], "\n";
# print "total: ", @$pivot2[1],"\n";
is(@$pivot2[0]->{'Assurance'}, -97.3, 'Check Assurance total category');
is(@$pivot2[0]->{'Depenses courantes'}, -1421.49, 'Check Depenses courantes total category');
is(@$pivot2[1], -3813.95, 'Check total debits');

$data->generateDashBoard();

