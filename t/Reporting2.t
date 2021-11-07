use Test::More tests => 14;
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

my $accountConfigFilePath = "./accounts/config.0303900020712303.xls";

require_ok "AccountStatement::Reporting";
require_ok "AccountStatement::CheckingAccount";

my $dt = DateTime->new(
	   year      => 2015,
	   month     => 7,
	   day       => 2,
	   time_zone => 'local',
	);
my $statPRM = Helpers::Statement->buildPreviousMonthStatement($accountConfigFilePath, $dt);
my $statMTD = Helpers::Statement->buildCurrentMonthStatement($accountConfigFilePath, $dt);

# Check the balance Integrity
$statPRM = Helpers::Statement->checkBalanceIntegrity($accountConfigFilePath, $statMTD, $statPRM );

my $reportProcessor = AccountStatement::Reporting->new($statPRM, $statMTD);

$reportProcessor->createPreviousMonthClosingReport();
my $accountYTD = Helpers::Statement->buildYTDStatement($accountConfigFilePath, $statPRM);
$reportProcessor->createYearlyClosingReport($accountYTD);

my $XLSfile = Helpers::MbaFiles->getClosingFilePath( $statPRM );
my $wb = Helpers::ExcelWorkbook->openExcelWorkbook($XLSfile);
my $ws = $wb->worksheet( 0 ); # Summary
is( $ws->get_cell( 13, 1 )->unformatted(), -17.97, 'NoOperationInCurrentMonth::Closing::Summary: Cell B14 value?');
is( $ws->get_cell( 9, 1 )->unformatted(), -647.22, 'NoOperationInCurrentMonth::Closing::Summary: Cell B10 value?');
is( $ws->get_cell( 12, 4 )->unformatted(), 130, 'NoOperationInCurrentMonth::Closing::Summary: Cell E13 value?');
$ws = $wb->worksheet( 1 ); # Details
is( $ws->get_cell( 3, 4 )->unformatted(), 'Sophie', 'NoOperationInCurrentMonth::Closing::Details: Cell E4 value?');
is( $ws->get_cell( 8, 2 )->unformatted(), 129.35, 'NoOperationInCurrentMonth::Closing::Details: Cell C9 value?');
is( $ws->get_cell( 20, 6 )->unformatted(), 8774.52, 'NoOperationInCurrentMonth::Closing::Details: Cell G21 value?');

$XLSfile = Helpers::MbaFiles->getYearlyClosingFilePath( $statPRM );
$wb = Helpers::ExcelWorkbook->openExcelWorkbook($XLSfile);
$ws = $wb->worksheet( 0 ); # Yearly Summary
is( $ws->get_cell( 10, 4 )->unformatted(), 2777.55, 'YealyReport::Summary:: Cell E11 value?');
$ws = $wb->worksheet( 1 ); # Details Summary
is( $ws->get_cell( 143, 2 )->unformatted(), 340, 'YealyReport::Details:: Cell C144 value?');

$reportProcessor->createForecastedCashflowReport();
$XLSfile = Helpers::MbaFiles->getForecastedFilePath( $statMTD );
$wb = Helpers::ExcelWorkbook->openExcelWorkbook($XLSfile);
$ws = $wb->worksheet( 0 ); # Cashflow
is( $ws->get_cell( 5, 5 )->unformatted(), -15, 'NoOperationInCurrentMonth::Forecasted::Cashflow: Cell F6 value?');
is( $ws->get_cell( 30, 5 )->unformatted(), -40, 'NoOperationInCurrentMonth::Forecasted::Cashflow: Cell F31 value?');
is( $ws->get_cell( 5, 4 )->unformatted(), -1301.02, 'NoOperationInCurrentMonth::Forecasted::Cashflow:Cell E6 value?');
is( $ws->get_cell( 3, 6 )->unformatted(), -320, 'NoOperationInCurrentMonth::Forecasted::Cashflow:Cell G4 value?');

