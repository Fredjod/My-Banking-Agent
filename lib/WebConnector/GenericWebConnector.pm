package WebConnector::GenericWebConnector;
# This is an abstract class, must never be instanciated!
# This is the super class of all the web connectors.
# The web connectors have to implement 3 methods: logIn(user, password), logOut() and downloadCSV(accountnumber, dateFrom, dateTo)

use lib '../../lib';
use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Cookies;
use MIME::Base64;
use DateTime;

sub new
{
    my ($class, $url) = @_;
    my $self = {
        _ua =>			LWP::UserAgent->new(),
        _cookie_jar =>	HTTP::Cookies->new(),
         _url =>		$url,
         _response => undef,
    };
    my $ua = $self->{_ua};
	$ua->ssl_opts( 'verify_hostname' => 0 );
	$ua->agent('Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:35.0) Gecko/20100101 Firefox/35.0');
	$ua->default_header(
		'Accept' => 'text/html,application/xhtml+xml,application/xml,application/x-excel;q=0.9,*/*;q=0.8',
		'Accept-Charset' => 'iso-8859-1,*,utf-8',
		'Accept-Language' => 'fr,fr-fr;q=0.8,en-us;q=0.5,en;q=0.3'
	);
    bless $self, $class;
    return $self;
}



sub logIn {
	# parameters: login, password
	# Need to be implelented per bank website
	# Generate the sequence of HTTP request till the download page
	# Return 1 if download page is displayed
	return 1;
}

sub logOut {
	# No parameter
	# Need to be implelented per bank website
	# Return 1 if logout succeeds
	return 1;	
}

sub downloadCSV {
	# Parameters: Accountnumber, dateFrom and dateTo
	# Need to be implelented per bank website
	# Return the CSV file as a string.
	return "";
}
1;
