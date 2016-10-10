use Test::More tests => 21;
use lib '../lib';
use Data::Dumper;
use diagnostics;
use warnings;
use strict;
use WebConnector::GenericWebConnector;
use Helpers::MbaFiles;
use Helpers::ConfReader;
use Helpers::Date;
use Helpers::Logger;

my $logger = Helpers::Logger->new();
$logger->print ( "###### Test the Saving reporting and merging of previous month", Helpers::Logger::INFO);


require_ok "AccountStatement::SavingAccount";

my $dt = DateTime->new(
	   year      => 2015,
	   month     => 6,
	   day       => 15,
	   time_zone => 'local',
	);

my $saving = AccountStatement::SavingAccount->new( );
my ($qif, $ofx, $balance, $bankData);
my $parser = WebConnector::GenericWebConnector->new();

# Delete from disk the previous reporting test output if exists.
my $dth = Helpers::Date->new ($dt);
my $dt_from = $dth->rollPreviousMonth();
if (-e Helpers::MbaFiles->getSavingFilePath ( $dt_from )) {
	unlink glob Helpers::MbaFiles->getSavingFilePath ( $dt_from );
}

$saving->generateLastMonthSavingReport($dt);

$dth = Helpers::Date->new ($dt); #if $dt is undef, return the current date.
$dt_from = $dth->rollPreviousMonth();
my $XLSfile = Helpers::MbaFiles->getSavingFilePath ( $dt_from );
my $wb = Helpers::ExcelWorkbook->openExcelWorkbook($XLSfile);
my $ws = $wb->worksheet( 0 ); # Balance
is( $ws->get_cell( 1, 0 )->unformatted(), "000 207 12307", 'Saving::Balance Cell A2 value?');
is( $ws->get_cell( 0, 2 )->unformatted(), 5, 'Saving::Balance Cell C1 value?');
is( $ws->get_cell( 1, 2 )->unformatted(), 313.02, 'Saving::Balance Cell C2 value?');
is( $ws->get_cell( 3, 2 )->unformatted(), 5249.36, 'Saving::Balance Cell C4 value?');

$ws = $wb->worksheet( 1 ); # Details ops
is( $ws->get_cell( 1, 1 )->unformatted(), -300, 'Saving::Details Cell B2 value?');
is( $ws->get_cell( 4, 5 )->unformatted(), "VIR BREAK MARC", 'Saving::Details Cell F5 value?');
is( $ws->get_cell( 6, 2 )->unformatted(), 0, 'Saving::Details Cell C7 value?');
is( $ws->get_cell( 10, 2 )->unformatted(), 1100, 'Saving::Details Cell C11 value?');

# ==================
$dt = DateTime->new(
	   year      => 2015,
	   month     => 7,
	   day       => 15,
	   time_zone => 'local',
	);

# Delete from disk the previous reporting test output if exists.
$dth = Helpers::Date->new ($dt);
$dt_from = $dth->rollPreviousMonth();
if (-e Helpers::MbaFiles->getSavingFilePath ( $dt_from )) {
	unlink glob Helpers::MbaFiles->getSavingFilePath ( $dt_from );
}

$saving = AccountStatement::SavingAccount->new( );
$saving->generateLastMonthSavingReport($dt);

$dth = Helpers::Date->new ($dt);
$dt_from = $dth->rollPreviousMonth();
$XLSfile = Helpers::MbaFiles->getSavingFilePath ( $dt_from );
$wb = Helpers::ExcelWorkbook->openExcelWorkbook($XLSfile);
$ws = $wb->worksheet( 0 ); # Balance
is( $ws->get_cell( 1, 0 )->unformatted(), "000 207 12307", 'Saving::Balance Cell A2 value?');
is( $ws->get_cell( 0, 2 )->unformatted(), 6, 'Saving::Balance Cell C1 value?');
is( $ws->get_cell( 1, 2 )->unformatted(), 314.02, 'Saving::Balance Cell C2 value?');
is( $ws->get_cell( 3, 2 )->unformatted(), 5250.36, 'Saving::Balance Cell C4 value?');
is( $ws->get_cell( 0, 3 )->unformatted(), 5, 'Saving::Balance Cell D1 value?');
is( $ws->get_cell( 1, 3 )->unformatted(), 313.02, 'Saving::Balance Cell D2 value?');
is( $ws->get_cell( 3, 3 )->unformatted(), 5249.36, 'Saving::Balance Cell D4 value?');

$ws = $wb->worksheet( 1 ); # Details ops
is( $ws->get_cell( 1, 1 )->unformatted(), -300, 'Saving::Details Cell B2 value?');
is( $ws->get_cell( 4, 5 )->unformatted(), "VIR BREAK MARC", 'Saving::Details Cell F5 value?');
is( $ws->get_cell( 6, 2 )->unformatted(), 0, 'Saving::Details Cell C7 value?');
is( $ws->get_cell( 10, 2 )->unformatted(), 450, 'Saving::Details Cell C11 value?');
is( $ws->get_cell( 21, 2 )->unformatted(), 1100, 'Saving::Details Cell C22 value?');

