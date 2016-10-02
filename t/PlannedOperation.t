use Test::More tests => 4;
use lib '../lib';
use Data::Dumper;
use diagnostics;
use warnings;
use strict;
use WebConnector::GenericWebConnector;
use Helpers::MbaFiles;
use Helpers::ConfReader;
use Helpers::Date;

require_ok "AccountStatement::PlannedOperation";
# Loading of an testing account
require_ok "AccountStatement::CheckingAccount";
my @config = Helpers::MbaFiles->getAccountConfigFilesName();
my $dth = Helpers::Date->new ();
my $data = AccountStatement::CheckingAccount->new( $config[0], $dth->getDate() );
open my $in, "<", "t.cm.bankdata.ofx" or die "Can't open file t.cm.bankdata.ofx file!\n";
read $in, my $ofx, -s $in;
close $in;	
open $in, "<", "t.cm.bankdata_june.qif" or die "Can't open file t.cm.bankdata_june.qif file!\n";
read $in, my $qif, -s $in;
close $in;
my $parser = WebConnector::GenericWebConnector->new();
my $balance = $parser->parseOFXforBalance($ofx, '.');
my $bankData = $parser->parseQIF ($qif, '([0-9]{2})\/([0-9]{2})\/([0-9]{2})', 0, ',', '.');
$parser->backwardBalanceCompute ( $bankData, $balance );
my $operations = $data->parseBankStatement($bankData);
###

my $planned = AccountStatement::PlannedOperation->new( $data, "./reporting/0303900020712303/dist.planned_operations.xls" );
my $ops = $planned->getPlannedOperations();
is(@$ops[1]->{FAMILY}, 'EXCEPTIONAL EXPENSES', 'Test the sorting and the transcoding of Family');
is(@$ops[0]->{FOUND}, 1, 'Match 1 planned operation with the current operations');

#print Dumper $planned->getPlannedOperations(), "\n";
