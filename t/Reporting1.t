use Test::More tests => 30;

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
$logger->print ( "###### Test the Closing, Forecasted and Actual generation, with and w/o last month operation cache file", Helpers::Logger::INFO);

#do 'Helpers/ConfReader.pm';
require_ok "AccountStatement::Reporting";
require_ok "AccountStatement::CheckingAccount";
   
my $dt = DateTime->new(
	   year      => 2015,
	   month     => 6,
	   day       => 15,
	   time_zone => 'local',
	);
# delete previous month cache file
my $dth = Helpers::Date->new($dt);
my $dt_prev = $dth->rollPreviousMonth();
my $stat = AccountStatement::CheckingAccount->new ("./accounts/config.0303900020712303.xls", $dt_prev);
my $cacheFilePath = Helpers::MbaFiles->getPreviousMonthCacheFilePath ( $stat );
if (-e $cacheFilePath ) {
	unlink glob $cacheFilePath;
	$logger->print ( "Cache file deleted: $cacheFilePath", Helpers::Logger::DEBUG);
}

# delete yearly report
my $yearlyReportPath = Helpers::MbaFiles->getYearlyClosingFilePath ( $stat );
if (-e $yearlyReportPath ) {
	unlink glob $yearlyReportPath;
	$logger->print ( "Yearly report deleted: $yearlyReportPath", Helpers::Logger::DEBUG);
}

my $statPRM = Helpers::Statement->buildPreviousMonthStatement("./accounts/config.0303900020712303.xls", $dt);
my $statMTD = Helpers::Statement->buildCurrentMonthStatement("./accounts/config.0303900020712303.xls", $dt);

my $reportProcessor = AccountStatement::Reporting->new($statPRM, $statMTD);

$reportProcessor->createPreviousMonthClosingReport();
my $accountYTD = Helpers::Statement->buildYTDStatement("./accounts/config.0303900020712303.xls", $statPRM);
$reportProcessor->createYearlyClosingReport($accountYTD);

my $XLSfile = Helpers::MbaFiles->getClosingFilePath( $statPRM );
my $wb = Helpers::ExcelWorkbook->openExcelWorkbook($XLSfile);
my $ws = $wb->worksheet( 0 ); # Summary
is( $ws->get_cell( 5, 1 )->unformatted(), 8075.14, 'Closing::Summary: Cell B6 value?');
is( $ws->get_cell( 9, 1 )->unformatted(), -17.97, 'Closing::Summary: Cell B10 value?');
is( $ws->get_cell( 16, 1 )->unformatted(), -1006.82, 'Closing::Summary: Cell B17 value?');
is( $ws->get_cell( 11, 4 )->unformatted(), 130, 'Closing::Summary: Cell E12 value?');
$ws = $wb->worksheet( 1 ); # Details
is( $ws->get_cell( 3, 4 )->unformatted(), 'Sophie', 'Closing::Details: Cell E4 value?');
is( $ws->get_cell( 8, 2 )->unformatted(), 129.35, 'Closing::Details: Cell C9 value?');
is( $ws->get_cell( 20, 6 )->unformatted(), 10270.39, 'Closing::Details: Cell G21 value?');
is( $ws->get_cell( 93, 6 )->unformatted(), 8075.14, 'Closing::Details: Cell G94 value?');

$reportProcessor->createForecastedCashflowReport();
$XLSfile = Helpers::MbaFiles->getForecastedFilePath( $statMTD );
$wb = Helpers::ExcelWorkbook->openExcelWorkbook($XLSfile);
$ws = $wb->worksheet( 0 ); # Cashflow
is( $ws->get_cell( 5, 5 )->unformatted(), -282.08, 'Forecasted::Cashflow: Cell F6 value?');
is( $ws->get_cell( 30, 5 )->unformatted(), -283.08, 'Forecasted::Cashflow: Cell F31 value?');
is( $ws->get_cell( 30, 4 )->unformatted(), -325.40, 'Forecasted::Cashflow:Cell E31 value?');

$reportProcessor->createActualsReport();
$XLSfile = Helpers::MbaFiles->getActualsFilePath($statMTD);
$wb = Helpers::ExcelWorkbook->openExcelWorkbook($XLSfile);
$ws = $wb->worksheet( 0 );
is( $ws->get_cell( 3, 4 )->unformatted(), 'Sophie', 'Actuals::Details: Cell E4 value?');
is( $ws->get_cell( 8, 2 )->unformatted(), 129.35, 'Actuals::Details: Cell C9 value?');
is( $ws->get_cell( 20, 6 )->unformatted(), 8774.52, 'Actuals::Details: Cell G21 value?');

$ws = $wb->worksheet( 1 );
is( $ws->get_cell( 12, 6 )->unformatted(), -262.80, 'Actuals::Cashflow: Cell G13 value?');
is( $ws->get_cell( 24, 5 )->unformatted(), -100, 'Actuals::Cashflow: Cell F25 value?');
is( $ws->get_cell( 16, 6 )->unformatted(), -320, 'Actuals::Cashflow: Cell G17 value?');
is( $ws->get_cell( 5, 2 )->unformatted() + 
	$ws->get_cell( 5, 4 )->unformatted() +
	$ws->get_cell( 5, 6 )->unformatted(),
	-1240.62, 'Actuals::Cashflow: Sum of C6:E6?');

my $statPRMCache = Helpers::Statement->buildPreviousMonthStatement("./accounts/config.0303900020712303.xls", $dt);
$statMTD = Helpers::Statement->buildCurrentMonthStatement("./accounts/config.0303900020712303.xls", $dt);
$reportProcessor = AccountStatement::Reporting->new($statPRM, $statMTD);

$reportProcessor->createPreviousMonthClosingReport();
$XLSfile = Helpers::MbaFiles->getClosingFilePath( $statPRMCache );
$wb = Helpers::ExcelWorkbook->openExcelWorkbook($XLSfile);
$ws = $wb->worksheet( 0 ); # Summary
is( $ws->get_cell( 5, 1 )->unformatted(), 8075.14, 'Closing::Summary: Cell B6 value?');
is( $ws->get_cell( 9, 1 )->unformatted(), -17.97, 'CacheData::Closing::Summary: Cell B10 value?');
is( $ws->get_cell( 16, 1 )->unformatted(), -1006.82, 'CacheData::Closing::Summary: Cell B17 value?');
is( $ws->get_cell( 11, 4 )->unformatted(), 130, 'CacheData::Closing::Summary: Cell E12 value?');
$ws = $wb->worksheet( 1 ); # Details
is( $ws->get_cell( 3, 4 )->unformatted(), 'Sophie', 'CacheData::Closing::Details: Cell E4 value?');
is( $ws->get_cell( 8, 2 )->unformatted(), 129.35, 'CacheData::Closing::Details: Cell C9 value?');
is( $ws->get_cell( 20, 6 )->unformatted(), 10270.39, 'CacheData::Closing::Details: Cell G21 value?');

$reportProcessor->createForecastedCashflowReport();
$XLSfile = Helpers::MbaFiles->getForecastedFilePath( $statMTD );
$wb = Helpers::ExcelWorkbook->openExcelWorkbook($XLSfile);
$ws = $wb->worksheet( 0 ); # Cashflow
is( $ws->get_cell( 5, 5 )->unformatted(), -282.08, 'CacheData::Forecasted::Cashflow: Cell F6 value?');
is( $ws->get_cell( 30, 5 )->unformatted(), -283.08, 'CacheData::Forecasted::Cashflow: Cell F31 value?');
is( $ws->get_cell( 30, 4 )->unformatted(), -325.40, 'CacheData::Forecasted::Cashflow:Cell E31 value?');

# Testing the "mondays" reporting.
# Update your email address in app.txt properties
# uncomment line below
# $reportProcessor->controlBalance(1);

