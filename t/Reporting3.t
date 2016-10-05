use Test::More tests => 11;
# use Test::More qw( no_plan );
use lib '../lib';
use Data::Dumper;
use diagnostics;
use warnings;
use strict;
use Helpers::ConfReader;
use Helpers::MbaFiles;
use Helpers::Statement;
use Helpers::Date;
use Helpers::Logger;

my $logger = Helpers::Logger->new();
$logger->print ( "###### Test the merge strategy between manual updated forecasted file and Planned Operations files", Helpers::Logger::INFO);

require_ok "AccountStatement::Reporting";
require_ok "AccountStatement::CheckingAccount";

my $dt = DateTime->new(
	   year      => 2015,
	   month     => 6,
	   day       => 15,
	   time_zone => 'local',
	);

my $statPRM = Helpers::Statement->buildPreviousMonthStatement("./accounts/config.0303900020712303.xls", $dt);
my $statMTD = Helpers::Statement->buildCurrentMonthStatement("./accounts/config.0303900020712303.xls", $dt);
my $reportProcessor = AccountStatement::Reporting->new($statPRM, $statMTD);

if (-e "./reporting/0303900020712303/2015-06_forecasted.xls") { rename "./reporting/0303900020712303/2015-06_forecasted.xls", "./reporting/0303900020712303/2015-06_forecasted.backup.xls"; }
rename "./reporting/0303900020712303/planned_operations.xls", "./reporting/0303900020712303/planned_operations.backup.xls";
rename "./reporting/0303900020712303/2015-06_forecasted.manual.xls", "./reporting/0303900020712303/2015-06_forecasted.xls";
rename "./reporting/0303900020712303/planned_operations.manual.xls", "./reporting/0303900020712303/planned_operations.xls";

$reportProcessor->createActualsReport();
my $XLSfile = Helpers::MbaFiles->getActualsFilePath($statMTD);
my $wb = Helpers::ExcelWorkbook->openExcelWorkbook($XLSfile);
my $ws = $wb->worksheet( 1 ); # Cashflow

is( $ws->get_cell( 16, 6 )->unformatted(), -520, 'Actuals::Cashflow: Cell G17 value?');
is( $ws->get_cell( 18, 4 )->unformatted(), -308.80, 'Actuals::Cashflow: Cell E19 value?');
is( $ws->get_cell( 19, 5 )->unformatted(), -50, 'Actuals::Cashflow: Cell F20 value?');
is( $ws->get_cell( 21, 2 ), undef, 'Actuals::Cashflow: Cell C22 value?');
is( $ws->get_cell( 24, 5 )->unformatted(), -270, 'Actuals::Cashflow: Cell F25 value?');
is( $ws->get_cell( 26, 5 )->unformatted(), -220, 'Actuals::Cashflow: Cell F27 value?');
is( $ws->get_cell( 26, 2 )->unformatted(), 169.85, 'Actuals::Cashflow: Cell C27 value?');

is( $ws->get_cell( 12, 6 )->unformatted(), -262.80, 'Actuals::Cashflow: Cell G13 value?');
is( $ws->get_cell( 5, 2 )->unformatted() + 
	$ws->get_cell( 5, 4 )->unformatted() +
	$ws->get_cell( 5, 6 )->unformatted(),
	-1240.62, 'Actuals::Cashflow: Sum of C6:E6?');


rename "./reporting/0303900020712303/planned_operations.xls", "./reporting/0303900020712303/planned_operations.manual.xls";
rename "./reporting/0303900020712303/2015-06_forecasted.xls", "./reporting/0303900020712303/2015-06_forecasted.manual.xls";
rename "./reporting/0303900020712303/planned_operations.backup.xls", "./reporting/0303900020712303/planned_operations.xls";
if (-e "./reporting/0303900020712303/2015-06_forecasted.backup.xls") { rename "./reporting/0303900020712303/2015-06_forecasted.backup.xls", "./reporting/0303900020712303/2015-06_forecasted.xls"; }

