use Test::More tests => 12;
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
$logger->print ( "###### Test the reporting process when the current month is empty", Helpers::Logger::INFO);

require_ok "AccountStatement::Reporting";
require_ok "AccountStatement::CheckingAccount";

my $dt = DateTime->new(
	   year      => 2015,
	   month     => 7,
	   day       => 2,
	   time_zone => 'local',
	);
my $statPRM = Helpers::Statement->buildPreviousMonthStatement("./accounts/config.0303900020712303.xls", $dt);
my $statMTD = Helpers::Statement->buildCurrentMonthStatement("./accounts/config.0303900020712303.xls", $dt);

my $reportProcessor = AccountStatement::Reporting->new($statPRM, $statMTD);

$reportProcessor->createPreviousMonthClosingReport();
my $XLSfile = Helpers::MbaFiles->getClosingFilePath( $statPRM );
my $wb = Helpers::ExcelWorkbook->openExcelWorkbook($XLSfile);
my $ws = $wb->worksheet( 0 ); # Summary
is( $ws->get_cell( 9, 1 )->unformatted(), -17.97, 'NoOperationInCurrentMonth::Closing::Summary: Cell B10 value?');
is( $ws->get_cell( 16, 1 )->unformatted(), -647.22, 'NoOperationInCurrentMonth::Closing::Summary: Cell B17 value?');
is( $ws->get_cell( 11, 4 )->unformatted(), 130, 'NoOperationInCurrentMonth::Closing::Summary: Cell E12 value?');
$ws = $wb->worksheet( 1 ); # Details
is( $ws->get_cell( 3, 4 )->unformatted(), 'Sophie', 'NoOperationInCurrentMonth::Closing::Details: Cell E4 value?');
is( $ws->get_cell( 8, 2 )->unformatted(), 129.35, 'NoOperationInCurrentMonth::Closing::Details: Cell C9 value?');
is( $ws->get_cell( 20, 6 )->unformatted(), 8774.52, 'NoOperationInCurrentMonth::Closing::Details: Cell G21 value?');

$reportProcessor->createForecastedCashflowReport();
$XLSfile = Helpers::MbaFiles->getForecastedFilePath( $statMTD );
$wb = Helpers::ExcelWorkbook->openExcelWorkbook($XLSfile);
$ws = $wb->worksheet( 0 ); # Cashflow
is( $ws->get_cell( 5, 5 )->unformatted(), -15, 'NoOperationInCurrentMonth::Forecasted::Cashflow: Cell F6 value?');
is( $ws->get_cell( 30, 5 )->unformatted(), -40, 'NoOperationInCurrentMonth::Forecasted::Cashflow: Cell F31 value?');
is( $ws->get_cell( 5, 4 )->unformatted(), -1301.02, 'NoOperationInCurrentMonth::Forecasted::Cashflow:Cell E6 value?');
is( $ws->get_cell( 3, 6 )->unformatted(), -320, 'NoOperationInCurrentMonth::Forecasted::Cashflow:Cell G4 value?');