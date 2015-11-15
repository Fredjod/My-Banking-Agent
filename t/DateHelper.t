use Test::More tests => 11;
#use Test::More qw( no_plan );
use lib '../lib';
use diagnostics;
use warnings;
use strict;
use Helpers::Date;

#do 'Helpers/Date.pm';
require_ok "Helpers::Date";
my $dt = DateTime->now(time_zone => 'local' );
$dt->set_day(21);
$dt->set_month(9);
$dt->set_year(2015);

my $helper = Helpers::Date->new ($dt);

my $dtPrevMonth = $helper->rollPreviousMonth();
is($dtPrevMonth->month(), 8, 'Month before September is August');

$dt->set_month(1);
$dt->set_year(2016);
$helper->setDate($dt);
$dtPrevMonth = $helper->rollPreviousMonth();
is($dtPrevMonth->month(), 12, 'Month before Jan is December');

$dt->set_day(22);
$dt->set_month(9);
$dt->set_year(2015);
$helper->setDate($dt);
my $dtPrevMonday = $helper->rollPreviousMonday();
is($dtPrevMonday->day(), 21, 'Monday before 22/09/2105 is 21/09/2105');

$dt->set_day(1);
$dt->set_month(6);
$helper->setDate($dt);
$dtPrevMonday = $helper->rollPreviousMonday();
is($dtPrevMonday->day(), 1, 'Monday before 01/06/2105 is 01/06/2105');

$dt->set_day(7);
$dt->set_month(6);
$helper->setDate($dt);
$dtPrevMonday = $helper->rollPreviousMonday();
is($dtPrevMonday->day(), 1, 'Monday before 07/06/2105 is 01/06/2105');

$dt->set_day(8);
$dt->set_month(6);
$helper->setDate($dt);
$dtPrevMonday = $helper->rollPreviousMonday();
is($dtPrevMonday->day(), 8, 'Monday before 08/06/2105 is 08/06/2105');

$dt->set_day(3);
$dt->set_month(7);
$helper->setDate($dt);
$dtPrevMonday = $helper->rollPreviousMonday();
is($dtPrevMonday->day(), 1, 'Monday before 03/07/2105 is 01/07/2105');

$dt->set_day(5);
$dt->set_month(7);
$helper->setDate($dt);
$dtPrevMonday = $helper->rollPreviousMonday();
is($dtPrevMonday->day(), 1, 'Monday before 05/07/2105 is 01/07/2105');

$dt->set_day(10);
$dt->set_month(7);
$helper->setDate($dt);
$dtPrevMonday = $helper->rollPreviousMonday();
is($dtPrevMonday->day(), 6, 'Monday before 10/07/2105 is 06/07/2105');

$dt->set_day(10);
$dt->set_month(8);
$helper->setDate($dt);
$dtPrevMonday = $helper->rollPreviousMonday();
is($dtPrevMonday->day(), 10, 'Monday before 10/08/2105 is 10/08/2105');