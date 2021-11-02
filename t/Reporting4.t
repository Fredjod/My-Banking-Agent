use Test::More tests => 2;
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
$logger->print ( "###### Test the reporting process for JSON web-report", Helpers::Logger::INFO);

my $accountConfigFilePath = "./accounts/config.0303900020712303.xls";

require_ok "AccountStatement::Reporting";
require_ok "AccountStatement::CheckingAccount";

my $dt = DateTime->new(
	   year      => 2015,
	   month     => 6,
	   day       => 20,
	   time_zone => 'local',
	);
my $statPRM = Helpers::Statement->buildPreviousMonthStatement($accountConfigFilePath, $dt);
my $statMTD = Helpers::Statement->buildCurrentMonthStatement($accountConfigFilePath, $dt);

# Check the balance Integrity

my $reportProcessor = AccountStatement::Reporting->new($statPRM, $statMTD);
$reportProcessor->computeCurrentMontBudgetObjective();
$reportProcessor->generateBudgetJSON();