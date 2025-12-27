package WebConnector::GenericWebConnector;
# This is an abstract class, must never be instanciated!
# This is the super class of all the web connectors.

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
use Path::Tiny;
use Data::Dumper;


sub new
{
    my ($class, $url) = @_;
    my $self = {
        _ua 		=> LWP::UserAgent->new(),
        _cookies	=> {},
        _url 		=> $url,
        _response 	=> undef,
    };
    my $ua = $self->{_ua};
    
	$ua->ssl_opts( 'verify_hostname' => 0 );
	$ua->agent('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.37');
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
	# parameters: login (for cookies management per bank login
	# Need to be implelented per bank website
	# Have to store the cookies in a file
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

sub downloadBalance {
	my ( $self, $accountNumber, $dateFrom, $dateTo ) = @_;	
	my $OFX = $self->download($accountNumber, $dateFrom, $dateTo, 'ofx');
	return $self->parseOFXforBalance ($OFX, '.');
}

sub downloadOperations {
	my ( $self, $accountNumber, $dateFrom, $dateTo ) = @_;	
	my $QIF = $self->download($accountNumber, $dateFrom, $dateTo, 'qif');
	return $self->parseQIF ( $QIF, '([0-9]{2})\/([0-9]{2})\/([0-9]{2})', 0, ',', '.' );	
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
    
	my ( $self, $account, $dateFrom, $dateTo ) = @_;

	my ( $bankData, $balance );
	my $logger = Helpers::Logger->new();
	# Get the operations from website
	$logger->print ( "Log in to ".$account->getBankName()." website", Helpers::Logger::INFO);
	if ( $self->logIn( Helpers::WebConnector->getLogin ($account->getAccountAuth), Helpers::WebConnector->getPwd ($account->getAccountAuth) ) ) {
		$logger->print ( "Download and parse bank statement for account ".$account->getAccountNumber()." for month ".$dateTo->month(), Helpers::Logger::INFO);
		$balance = $self->downloadBalance ( $account->getAccountNumber(), $dateFrom, $dateTo );
		$bankData = $self->downloadOperations ( $account->getAccountNumber(), $dateFrom, $dateTo );
		if ($#{$bankData} > -1) {
			$self->backwardBalanceCompute ( $bankData, $balance );
		}
	}
	$logger->print ( "Log out", Helpers::Logger::INFO);
	$self->logOut( Helpers::WebConnector->getLogin ($account->getAccountAuth) );
	return $bankData;
}


sub downloadMultipleBankStatement {
	my ( $self, $AccountList, $dateFrom, $dateTo ) = @_;
	my $logger = Helpers::Logger->new();
	my @result;
	
	return \@result unless $#{$AccountList} > -1;
	
	my $bankname = @$AccountList[0]->{'BANK'};
	my $authKey = @$AccountList[0]->{'KEY'};
	$logger->print ( "Log in to ".$bankname." website with key ".$authKey, Helpers::Logger::INFO);
	if ( $self->logIn(  Helpers::WebConnector->getLogin ($authKey),  Helpers::WebConnector->getPwd ($authKey) ) ) {
		for my $info ( @$AccountList ) {
			# As input a array of hashes:
			my $desc = 	$info->{'DESC'};
			my $number = $info->{'NUMBER'};
			my %record;
			$logger->print ( "Download and parse bank statement for account ".$desc." for month ".$dateFrom->month()."...", Helpers::Logger::INFO);
			# As output an array of hashes:
			$record{'BALANCE'} = $self->downloadBalance ( $number, , $dateFrom, $dateTo );
			$record{'BANKOPE'} = $self->downloadOperations ( $number, $dateFrom, $dateTo );
			$record{'NUMBER'} = $number;
			$record{'DESC'} = $desc;
			push (@result, \%record);
		}
	}
	$logger->print ( "Log out", Helpers::Logger::INFO);
	$self->logOut( Helpers::WebConnector->getLogin ($authKey) );
	return \@result;
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

#sub getStoredCookies {
#	my ( $self, $login ) = @_;
#	my $filename = $login.'.cookies.txt';
#	if (-e $filename) {
#		# $self->{_cookie_jar}->load ( path($filename)->lines );
# 		$self->{_cookie_jar}->load ( $filename );
# 		$self->{_ua}->cookie_jar( $self->{_cookie_jar} );
#	}
#}

#sub saveCookies {
#	my ( $self, $login ) = @_;
#	my $filename = $login.'.cookies.txt';
#	$self->{_cookie_jar} = $self->{_ua}->cookie_jar;
#	$self->{_cookie_jar}->save( $filename );
#	#path($filename)->spew( join "\n", $self->{_cookie_jar}->save ( { persistent => 1 } ) );
#}

sub requestCall {
	my ($self, $request, $id) = @_;
	my $ua = $self->{_ua};
	my %cookies;
	my $response;
	my $logger = Helpers::Logger->new('logs.http.output');
	
	$response = $self->httpCallnTrace ($request, $id);
	
	while ( $response->code() == '302' ) {
		$request->method('GET');
		$request->content('');
		$request->url($response->header( 'Location' ));
		$response = $self->httpCallnTrace ($request, $id.'-302');
	}
	if ($response->previous()) {
		my $prevResponse = $response->previous();
		my @setcookie;
		do {
			@setcookie = $prevResponse->header('set-cookie');

			$logger->print ( "################################# HTTP Call $id-prev: ####################################", Helpers::Logger::DEBUG );
			$logger->print ( $prevResponse->request->as_string(), Helpers::Logger::DEBUG);
			$logger->print ( "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< HTTP Response $id-prev:", Helpers::Logger::DEBUG);
			$logger->print ( $prevResponse->code()." - ".$prevResponse->message(), Helpers::Logger::DEBUG);	
			$logger->print ( "Set-Cookie: ".join( '; ', @setcookie ), Helpers::Logger::DEBUG);
			$logger->print ( "Location: ".$prevResponse->header('location'), Helpers::Logger::INFO);
			$logger->print ( "Content-Type: ".$prevResponse->header('content-type'), Helpers::Logger::INFO);	
			# $logger->print ( "Content: ".$prevResponse->content(), Helpers::Logger::INFO);
			$logger->print ( "##########################################################################################", Helpers::Logger::DEBUG );
			
			%cookies = ( %{$self->{_cookies}}, parseCookies(\@setcookie) );
			$self->{_cookies} = \%cookies;
			$prevResponse = $prevResponse->previous();			
		} while ($prevResponse)
	}
	return $response;
}

sub httpCallnTrace {
	
	my ($self, $request, $id) = @_;
	my $ua = $self->{_ua};
	my %cookies;
	my $response;
	my $logger = Helpers::Logger->new('logs.http.output');
	
	$request->header( 'Cookie' => $self->buildCookieString() );
	$logger->print ( "###################################### HTTP Call $id ####################################", Helpers::Logger::DEBUG );
	$logger->print ( $request->as_string(), Helpers::Logger::DEBUG);
	$response = $ua->request($request);
	$logger->print ( "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< HTTP Response $id:", Helpers::Logger::DEBUG);
	$logger->print ( $response->code()." - ".$response->message(), Helpers::Logger::DEBUG);
	my @setcookie = $response->header('set-cookie');
	$logger->print ( "Set-Cookie: ".join( '; ', @setcookie), Helpers::Logger::DEBUG);
	$logger->print ( "Location: ".$response->header('location'), Helpers::Logger::INFO);
	$logger->print ( "Content-Type: ".$response->header('content-type'), Helpers::Logger::INFO);
	# $logger->print ( "Content: ".$response->content(), Helpers::Logger::INFO);
	$logger->print ( "#########################################################################################", Helpers::Logger::DEBUG );				

	%cookies = ( %{$self->{_cookies}}, parseCookies(\@setcookie) );
	$self->{_cookies} = \%cookies;
	return $response;
}
	

sub parseCookies {
	my ($allCookies) = @_;
	my %result;
	foreach my $cookie (@$allCookies) {
		my @cookieItems = split(/; /, $cookie);
		my @keypair = split(/=/, $cookieItems[0]);
		my $cookieName = $keypair[0];
		my $cookieValue = '';
		for my $i (1 .. $#keypair) {
			$cookieValue .= $keypair[$i];
		}
		$result{$cookieName} = $cookieValue;
		
	}
	return %result;
}

sub buildCookieString {
	my ($self) = @_;
	my $result='';
	my $cookies = $self->{_cookies};

	my $i = 0;
	foreach my $key (keys %{$cookies}) {
		if ($i>0) { $result .= "; " }
		if (defined $cookies->{$key}) { 
			$result .= $key.'='.$cookies->{$key};
		}
		else  {
			$result .= $key.'='; #empty value
		}
		$i++;
	}
	return $result;
}

1;
