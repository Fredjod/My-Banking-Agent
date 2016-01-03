package AccountStatement::SavingAccount;

use lib '../../lib';
use parent 'AccountStatement::Account';

use strict;
use warnings;
use DateTime;
use Helpers::ConfReader;
use utf8;
use Helpers::Logger;
use Helpers::Date;
use Helpers::ExcelWorkbook;
use Spreadsheet::ParseExcel;


sub new
{ }

1;