#!/usr/bin/perl

use lib './lib';
use strict;
use warnings;
use HTTPServer::MBAWebServer;
use Helpers::Logger;

# start the server on port 8080
my $server = HTTPServer::MBAWebServer->new(8080);
my $logger = Helpers::Logger->new();
$logger->print ( "MBA server is running", Helpers::Logger::DEBUG);
my $wpid = $server->run();
$logger->print ( "Use 'kill $wpid' to stop server.", Helpers::Logger::DEBUG);