use Test::More tests => 4;
use lib '../lib';
use Data::Dumper;
use diagnostics;
use warnings;
use strict;
use Helpers::ConfReader;
use Helpers::Statement;
use Helpers::MbaFiles;

require_ok "AccountStatement::PlannedOperation";
# Loading of an testing account
require_ok "AccountStatement::CheckingAccount";

my $dt = DateTime->new(
	   year      => 2015,
	   month     => 5,
	   day       => 31,
	   time_zone => 'local',
	);
	
my $statement = Helpers::Statement->buildCurrentMonthStatement( "./accounts/config.0303900020712303.xls", $dt );
###

my $planned = AccountStatement::PlannedOperation->new( $statement, "./reporting/0303900020712303/dist.planned_operations.xls" );
my $ops = $planned->getPlannedOperations();
is(@$ops[1]->{FAMILY}, 'EXCEPTIONAL EXPENSES', 'Test the sorting and the transcoding of Family');
is(@$ops[0]->{FOUND}, 1, 'Match 1 planned operation with the current operations');

#print Dumper $planned->getPlannedOperations(), "\n";
