use Test::More tests => 4;
use lib '../lib';
use Data::Dumper;
use diagnostics;
use warnings;
use strict;
use Helpers::ConfReader;
use Helpers::MbaFiles;
use Helpers::Statement;
use Helpers::Date;


my $logger = Helpers::Logger->new();
$logger->print ( "###### Test the reporting process for JSON web-report", Helpers::Logger::INFO);

my $accountConfigFilePath = "./accounts/config.0303900020712303.xls";

require_ok "AccountStatement::Reporting";
require_ok "AccountStatement::CheckingAccount";

# Generate June JSON file
my $dt1 = DateTime->new(
	   year      => 2015,
	   month     => 6,
	   day       => 15,
	   time_zone => 'local',
	);
my $statPRM = Helpers::Statement->buildPreviousMonthStatement($accountConfigFilePath, $dt1);
my $statMTD = Helpers::Statement->buildCurrentMonthStatement($accountConfigFilePath, $dt1);
my $reportProcessor = AccountStatement::Reporting->new($statPRM, $statMTD);

$reportProcessor->computeCurrentMonthBudgetObjective();
$reportProcessor->generateJSONWebreport();

my $json=Helpers::MbaFiles->readJSONFile("budget.json");
is($json->{'data_objectif'}[2], 2760, 'Total budget objective for june is 2 760');

# Generate Jully JSON file
my $dt2 = DateTime->new(
	   year      => 2015,
	   month     => 7,
	   day       => 2,
	   time_zone => 'local',
	);
$statPRM = Helpers::Statement->buildPreviousMonthStatement($accountConfigFilePath, $dt2);
$statMTD = Helpers::Statement->buildCurrentMonthStatement($accountConfigFilePath, $dt2);
$reportProcessor = AccountStatement::Reporting->new($statPRM, $statMTD);

$reportProcessor->computeCurrentMonthBudgetObjective();
$reportProcessor->generateBudgetJSON();
$json=Helpers::MbaFiles->readJSONFile("budget.json");
is($json->{'data_objectif'}[2], 3948.66, 'Total budget objective for july is 3 948.66');
