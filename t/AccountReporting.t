use Test::More tests => 15;
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
require_ok "AccountStatement::CheckingAccount";
my @config = Helpers::MbaFiles->getAccountConfigFilesName();
my $dth = Helpers::Date->new ();
my $dataMTD = AccountStatement::CheckingAccount->new( $config[0], $dth->getDate() );
my $dataPRM = AccountStatement::CheckingAccount->new( $config[0], $dth->getDate() );
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

$dataPRM->setBalance($balance);
if ($#{$bankData} > 0) {
	$parser->backwardBalanceCompute ( $bankData, $balance );
	$dataPRM->parseBankStatement($bankData);
}

$report->setAccDataPRM($dataPRM);

open $in, "<", "t.cm.bankdata.ofx" or die "Can't open file t.cm.bankdata.ofx file!\n";
read $in, $ofx, -s $in;
close $in;	

open $in, "<", "t.cm.bankdata_june.qif" or die "Can't open file t.cm.bankdata.qif file!\n";
read $in, $qif, -s $in;
close $in;

$parser = WebConnector::GenericWebConnector->new();
$balance = $parser->parseOFXforBalance($ofx, '.');
$bankData = $parser->parseQIF ($qif, '([0-9]{2})\/([0-9]{2})\/([0-9]{2})', 0, ',', '.');

$dataMTD->setBalance($balance);
if ($#{$bankData} > 0) {
	$parser->backwardBalanceCompute ( $bankData, $balance );
	$dataMTD->parseBankStatement($bankData);
}


$report->setAccDataMTD($dataMTD);

$report->createPreviousMonthClosingReport();

my $XLSfile = Helpers::MbaFiles->getClosingFilePath( $dataPRM );
my $wb = Helpers::ExcelWorkbook->openExcelWorkbook($XLSfile);
my $ws = $wb->worksheet( 0 );
is( $ws->get_cell( 9, 1 )->unformatted(), -17.97, 'Cell B10 value?');
is( $ws->get_cell( 16, 1 )->unformatted(), -1006.82, 'Cell B17 value?');
is( $ws->get_cell( 11, 4 )->unformatted(), 130, 'Cell E12 value?');
$ws = $wb->worksheet( 1 );
is( $ws->get_cell( 3, 4 )->unformatted(), 'Sophie', 'Cell E4 value?');
is( $ws->get_cell( 8, 2 )->unformatted(), 129.35, 'Cell C9 value?');
is( $ws->get_cell( 20, 6 )->unformatted(), 10270.39, 'Cell G21 value?');


$report->createActualsReport();

my $prop = Helpers::ConfReader->new("properties/app.txt");
# $XLSfile = Helpers::MbaFiles->getActualsFilePath($data);
$XLSfile = './reporting/0303900020712303/06-15_actuals.xls';
$wb = Helpers::ExcelWorkbook->openExcelWorkbook($XLSfile);
$ws = $wb->worksheet( 0 );
is( $ws->get_cell( 3, 4 )->unformatted(), 'Sophie', 'Cell E4 value?');
is( $ws->get_cell( 8, 2 )->unformatted(), 129.35, 'Cell C9 value?');
is( $ws->get_cell( 20, 6 )->unformatted(), 8774.52, 'Cell G21 value?');

$ws = $wb->worksheet( 1 );
is( $ws->get_cell( 12, 6 )->unformatted(), -262.80, 'Cell G13 value?');
is( $ws->get_cell( 24, 5 )->unformatted(), -100, 'Cell F25 value?');
if ( defined $ws->get_cell( 16, 6 )) { 
	is( $ws->get_cell( 16, 6 )->unformatted(), -120, 'Cell G17 value?');
}

is( $ws->get_cell( 5, 2 )->unformatted() + 
	$ws->get_cell( 5, 4 )->unformatted() +
	$ws->get_cell( 5, 6 )->unformatted(),
	-1240.62, 'Sum of C6:E6?');

