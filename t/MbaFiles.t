use Test::More tests => 5;
use lib '../lib';
use diagnostics;
use warnings;
use strict;
use Helpers::Date;

require_ok "Helpers::MbaFiles";
my @files = Helpers::MbaFiles->getAccountConfigFilesName();
is( $files[0], "./accounts/config.033033050050029.xls", '1st file is config.033033050050029.xls');
is( $files[1], "./accounts/config.12345.xls", '2nd file is config.12345.xls');
is( $files[2], "./accounts/config.6789.xls", '2nd file is config.6789.xls');
is ($#files, 2, "There are 3 interesting files only");
