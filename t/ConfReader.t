use Test::More tests => 7;
#use Test::More qw( no_plan );
use lib '../lib';
use diagnostics;
use warnings;
use strict;
use Helpers::ConfReader;

#do 'Helpers/ConfReader.pm';
require_ok "Helpers::ConfReader";
my $params = Helpers::ConfReader->new ('t.param.txt');
is($params->readParamValue('param0'), undef, 'Get a param not defined');
is($params->readParamValue('param1'), 'value1', 'Get a param returning a simple value');
is($params->readParamValue('param2'), 'value2', 'Get a param returning a simple value with spaces to trim before the key and around the value');
is($params->readParamValue('param3'), undef, 'Try to get a commented param, should return undef');
is_deeply($params->readParamValueList('param4'), ['value4.1', 'value4.2', 'value4.3'], 'Get a param as a list of values (array)');
is_deeply($params->readParamValueList('param5'), ['value 5.1', 'value 5.2', 'value 5.3'], 'Get a param as an array with spaces to trim at the beginning and end of values');