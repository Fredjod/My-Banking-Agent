use Test::More tests => 16;
# use Test::More qw( no_plan );
use lib '../lib';
use Data::Dumper;
use diagnostics;
use warnings;
use strict;
use WebConnector::GenericWebConnector;
use Helpers::ConfReader;
use Helpers::MbaFiles;
use Helpers::Date;

#do 'Helpers/ConfReader.pm';
require_ok "AccountStatement::Reporting";
require_ok "AccountStatement::AccountData";
my @config = Helpers::MbaFiles->getAccountConfigFilesName();
my $dth = Helpers::Date->new ();
my $data = AccountStatement::AccountData->new( $config[0], $dth->getDate() );
my $report = AccountStatement::Reporting->new();

open my $in, "<", "t.cm.bankdata.ofx" or die "Can't open file t.cm.bankdata.ofx file!\n";
read $in, my $ofx, -s $in;
close $in;	

open $in, "<", "t.cm.bankdata.qif" or die "Can't open file t.cm.bankdata.qif file!\n";
read $in, my $qif, -s $in;
close $in;

my $parser = WebConnector::GenericWebConnector->new();
my $balance = $parser->parseOFXforBalance($ofx, '.');
my $bankData = $parser->parseQIF ($qif, '([0-9]{2})\/([0-9]{2})\/([0-9]{2})', 0, ',', '.');
$parser->backwardBalanceCompute ( $bankData, $balance );

$data->parseBankStatement($bankData);

$report->setAccDataMTD($data);
$report->setAccDataPRM($data);

$report->createPreviousMonthClosingReport();
my $XLSfile = Helpers::MbaFiles->getClosingFilePath( $data );
my $wb = Helpers::ExcelWorkbook->openExcelWorkbook($XLSfile);
my $ws = $wb->worksheet( 0 );
is( $ws->get_cell( 9, 1 )->unformatted(), -1186.82, 'Cell B10 value?');
is( $ws->get_cell( 16, 1 )->unformatted(), -102.74, 'Cell B17 value?');
is( $ws->get_cell( 11, 4 )->unformatted(), 223.1, 'Cell E12 value?');
$ws = $wb->worksheet( 1 );
is( $ws->get_cell( 3, 4 )->unformatted(), 'Sophie', 'Cell E4 value?');
is( $ws->get_cell( 8, 2 )->unformatted(), 129.35, 'Cell C9 value?');
is( $ws->get_cell( 20, 6 )->unformatted(), 10610.39, 'Cell G21 value?');


$report->createActualsReport();

my $prop = Helpers::ConfReader->new("properties/app.txt");
# $XLSfile = Helpers::MbaFiles->getActualsFilePath($data);
$XLSfile = './reporting/033033050050029/05-31_actuals.xls';
$wb = Helpers::ExcelWorkbook->openExcelWorkbook($XLSfile);
$ws = $wb->worksheet( 0 );
is( $ws->get_cell( 3, 4 )->unformatted(), 'Sophie', 'Cell E4 value?');
is( $ws->get_cell( 8, 2 )->unformatted(), 129.35, 'Cell C9 value?');
is( $ws->get_cell( 20, 6 )->unformatted(), 10610.39, 'Cell G21 value?');

$ws = $wb->worksheet( 1 );
#is( $ws->get_cell( 12, 6 )->unformatted(), 6.9, 'Cell G13 value?');

#is( $ws->get_cell( 4, 2 )->unformatted() + 
#	$ws->get_cell( 4, 3 )->unformatted() +
#	$ws->get_cell( 4, 4 )->unformatted() +
#	$ws->get_cell( 4, 5 )->unformatted(),
#	982.27, 'Sum of C5:F5?');
is( $ws->get_cell( 5, 2 )->unformatted() + 
	$ws->get_cell( 5, 3 )->unformatted() +
	$ws->get_cell( 5, 4 )->unformatted(),
	-1523.7, 'Sum of C6:E6?');
#is( $ws->get_cell( 19, 4 )->unformatted() +
#	$ws->get_cell( 19, 5 )->unformatted(),
#	-495, 'Sum of E20:F20?');	

$XLSfile = Helpers::MbaFiles->getClosingFilePath( $data );
$report->copyCashflowExcelSheet ($XLSfile, 2 );

$wb = Spreadsheet::WriteExcel->new( 'copypast.t.xls');
$ws = $wb->add_worksheet( 'past1' );	
$report->pastExcelSheet ( $wb, $ws, 5, 10 );
$ws = $wb->add_worksheet( 'past2' );	
$report->pastExcelSheet ( $wb, $ws );