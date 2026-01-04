#!/usr/bin/perl

use lib './lib';
use strict;
use warnings;
use Helpers::Logger;
use Helpers::ConfReader;

my $logger = Helpers::Logger->new();
my $count = 0;
my $prop = Helpers::ConfReader->new("properties/app.txt");
my $triggerFile = $prop->readParamValue("owncloudsync.trigger.file");

open my $fh, '>', $triggerFile or $logger->print ( "$triggerFile can't be written", Helpers::Logger::ERROR);
close ($fh);

$logger->print ( "Owncloud file scan is triggered: $triggerFile", Helpers::Logger::DEBUG);
do {
	sleep 1;
	$count++;	
}
while ( -e $triggerFile && $count < 120 ); # wait 2 minutes max for owncloud file scan result
$logger->print ( "Owncloud file scan ended", Helpers::Logger::DEBUG);