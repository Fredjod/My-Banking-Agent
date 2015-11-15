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
use Helpers::Logger;
use Encode;


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

sub download {
	# Parameters: Accountnumber, dateFrom, dateTo, $format
	# Need to be implelented per bank website
	# return the dowloaded file with the given format (ofx, qif)
	# or return undef in case of any issue happened.
	return undef;
}

sub downloadBankStatement {
	# Parameters: Accountnumber, dateFrom, dateTo
	# Need to be implelented per bank website
	# Return an array of hashes. Each hash is a transaction with the following info and format:
	# [ 
	#	{
    #      'DATE' => 'DD/MM/YYYY',
    #      'AMOUNT' => -NNNN.NN,
   	#      'DETAILS' => 'A string describing the transaction',
    #      'BALANCE' => -NNNN.NN,
    #    },
    #    {
    #		...
	#	 }
    # ]
    # The year is formatted with 4 digits
    # Amount and balance decimal separator is the point (.)
    #
    # This array is built wit the OFX format for reading the balance value
    # and the QIf format for reading the transaction info (date, amount and details)
	return ();
}

sub loginLock {
	my ($self) = @_;
	my $now = DateTime->now(time_zone => 'local' );	
	open LOCK, ">", "login.lock.txt" or die "Couldn't open file lock file\n";
	print LOCK "Lock datetime: ".$now;
	close LOCK;
}

sub isLoginLock {
	my ($self) = @_;
	return (-e "login.lock.txt");
}

sub parseOFXforBalance {
	my ( $self, $OFXdata, $decimalSep ) = @_;
	my $logger = Helpers::Logger->new();
	if ( !defined $decimalSep ) { $decimalSep = '.' }
	
	unless ($OFXdata =~ /<BALAMT>([-]?\d+$decimalSep\d+|\d+$decimalSep|$decimalSep\d+)/ ) {
		$logger->print ( "Can't read balance value in OFX data", Helpers::Logger::ERROR);
		$logger->print ( "OFX Data: $OFXdata", Helpers::Logger::DEBUG);
		die ("Can't read balance value in OFX data");
	}
	my $balance = $1;
	$balance =~ s/,/./;
	return $balance;
}

sub parseQIF {
	my ( $self, $QIFdata, $dateFormat, $USdate, $thousandSep, $decimalSep ) = @_;
	my $logger = Helpers::Logger->new();

	my @records = split ('\^', $QIFdata);
	my @bankData;
	
	foreach my $i (0 .. $#records-1) {
		my %item;
		# parse date value of the transaction: DD/MM/YYYY
		unless ($records[$i] =~ /^D$dateFormat/m) {
			$logger->print ( "Can't read date value in QIF file", Helpers::Logger::ERROR);
			$logger->print ( "Can't read date value: $records[$i]", Helpers::Logger::DEBUG);			
			die ("Can't read date value in QIF file");
		}
		my $date;
		if ($USdate) { $date = "$2/$1/" } else { $date = "$1/$2/" }
		my $year = $3;
		if ($year =~ /[0-9]{4}/) { $date .= $year; } else { $date .= "20$year"; }
		$item{DATE} = $date;
		
		# parse amount transaction value: NNNNN.NN
		$records[$i] =~ s/$thousandSep//;
		unless ($records[$i] =~ /^T([-]?\d+$decimalSep\d+|\d+$decimalSep|$decimalSep\d+)/m) {
			$logger->print ( "Can't read amount value in QIF file", Helpers::Logger::ERROR);
			$logger->print ( "Can't read amount value: $records[$i]", Helpers::Logger::DEBUG);			
			die ("Can't read amount value in QIF file");
		}
		$item{AMOUNT} = $1;

		# parse details transaction info		
		unless ($records[$i] =~ /^P(.*)/m) {
			$logger->print ( "Can't read details value in QIF file", Helpers::Logger::ERROR);
			$logger->print ( "Can't read details value: $records[$i]", Helpers::Logger::DEBUG);			
			die ("Can't read details value in QIF file");
		}
		my $val = $1;
		$val =~ s/\r|\n//g;
		$item{DETAILS} = encode("UTF-8", $val);

		# balance set to 0 at this point			
		$item{BALANCE} = 0;
		
		push (@bankData, \%item);
	}
	return \@bankData;
}

sub backwardBalanceCompute {
	my ( $self, $bankData, $balance ) = @_;
	@$bankData[$#{$bankData}]->{BALANCE} = $balance;
	for ( my $i = $#{$bankData} - 1; $i>=0; $i-- ) {
		$balance -= @$bankData[$i+1]->{AMOUNT};
		@$bankData[$i]->{BALANCE} = sprintf("%.2f", $balance);
	}
	return $bankData;
}

sub forwardBalanceCompute {
	my ( $self, $bankData, $balance ) = @_;
	@$bankData[0]->{BALANCE} = $balance;
	for ( my $i = 1; $i<=$#{$bankData}; $i++ ) {
		$balance -= @$bankData[$i-1]->{AMOUNT};
		@$bankData[$i]->{BALANCE} = sprintf("%.2f", $balance);
	}
	return $bankData;
}

1;
