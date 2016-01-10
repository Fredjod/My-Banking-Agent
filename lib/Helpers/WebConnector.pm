package Helpers::WebConnector;

use lib "../../lib/";

use warnings;
use strict;

use Helpers::Logger;
use Helpers::ConfReader;

sub buildWebConnectorObject {
	my ($class, $bankname) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $logger = Helpers::Logger->new();
	
	# Use the Web connector of the account bank
	my $connectorClass = 'WebConnector::'.$prop->readParamValue( 'connector.'.$bankname );
	eval "use $connectorClass";
	if( $@ ){
		$logger->print ( "Cannot load $connectorClass: $@", Helpers::Logger::ERROR);
		die("Cannot load $connectorClass: $@");
	}
	my $connector = $connectorClass->new( $prop->readParamValue( 'website.'.$bankname ));
	die $connectorClass.' is a wrong web connector class. Must inherite from WebConnector::GenericWebConnector'
		unless $connector->isa('WebConnector::GenericWebConnector');
	return $connector;
}

sub getLogin {
	my ($class, $authKey) = @_;
	require "auth.pl";
	our %auth;
	return $auth{$authKey}[0];
}

sub getPwd {
	my ($class, $authKey) = @_;
	require "auth.pl";
	our %auth;
	return $auth{$authKey}[1];

}

1;