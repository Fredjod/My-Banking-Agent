package WebConnector::CMWebConnector2;

use lib '../../lib';
use parent 'WebConnector::GenericWebConnector';

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Cookies;
use MIME::Base64;
use DateTime;
use Helpers::Logger;
use Helpers::ConfReader;
use URI::Encode;

use Data::Dumper;

sub new
{
	my ($class) = shift;
	return $class->SUPER::new(@_);
}

sub logIn
{
		
	my ( $self, $login, $password ) = @_;
	my $logger = Helpers::Logger->new();
	my $ua = $self->{_ua};
	my $url = $self->{_url};
	my $cookies = $self->{_cookie_jar};
	my $request = HTTP::Request->new();
	my $response;

	# Check whether the login is locked due to a past login error
	unless (! $self->isLoginLock() ) {
		$logger->print ( "The website login is locked. Check the auth config and delete the file lock.login.txt before retrying.", Helpers::Logger::ERROR);
		return 0;				
	}
	
	# Load Cookies from file if any
	$self->getStoredCookies($login);
	
	# Page acceuil
	$request->method('GET');
	$request->url('https://www.creditmutuel.fr/fr/authentification.html');
	$cookies->add_cookie_header($request);
	$response = $ua->request($request);

	#  Adding of RGPD consent cookie to the cookieJAR:
	my $rgpd_cookie = "lang=en-US; Path=/; Domain=www.creditmutuel.fr; eu-consent={\"/fr/\":{\"solutions\":{\"googleAnalytics\":true,\"ABTasty\":true,\"uxcustom\":true,\"DCLIC\":true,\"googleMarketingPlatform\":true,\"youtube\":true},\"expireDate\":\"2099-04-17T20:22:54.523Z\"}}; Max-Age=". 365*0.5*24*60*60;
	$cookies->add ( "https://www.creditmutuel.fr", $rgpd_cookie );
	
	# Login
	$request->method('POST');
	$request->url('https://www.creditmutuel.fr/fr/authentification.html');
	$request->header('Content-Type' => 'application/x-www-form-urlencoded');
	$request->content('_cm_user='.$login.'&flag=password&_charset_=UTF-8&_cm_pwd='.$password);
	$cookies->add_cookie_header($request);
	$response = $ua->request($request);
	$cookies->extract_cookies($response);

	if ($response->code() == '302' ) {
		$request->method('GET');
		$request->content('');
		$request->url($response->header( 'Location' ));
		$cookies->add_cookie_header($request);
		$response = $ua->request($request);
	}
	else {
		$logger->print ( "Login/password authentification failed!", Helpers::Logger::ERROR);
		$logger->print ( "The login is locked for avoiding intempstive errors and bank website locking.", Helpers::Logger::ERROR);
		$self->loginLock();
		return 0;
	}

	# Authentification forte
	unless ($response->content() !~ /<title>Authentification forte<\/title>/m) {
		
		if ($response->content() =~ (/href="\/fr\/banque\/validation.aspx\?_tabi=C&amp;(.+)&amp;_fid=SCA"/m)) {
			$logger->print ( "Strong Authentification page (1 month before warning):\n".$response->content(), Helpers::Logger::DEBUG);
			my $URIbody = $1 ;
			$URIbody =~ s/&amp;/&/g;
			$request->method('GET');
			$request->url('https://www.creditmutuel.fr/fr/banque/validation.aspx?_tabi=C&'.$URIbody.'&_fid=SCA');
			$cookies->add_cookie_header($request);
			$response = $ua->request($request);
		}
		# $logger->print ( "Strong Authentification page\n".$response->content(), Helpers::Logger::DEBUG);
	
		my $count = 40;
		my $ok = 1;
		my $transactionId = 0;
		my $nextURIpost = "";
		my $postValueHidden1 = "";
		my $postValueHidden2 = "";
		my $postValueHidden3 = "";
		my $postValueHidden4 = "";
		my $uri = URI::Encode->new( { encode_reserved => 0 } );
		
		if ($response->content() =~ /transactionId: '(.+)'/) {
			$transactionId = $1;
		}
		
		if ($response->content() =~ /form id="I0:P:F"\saction="(.+)"\smethod/) {
			$nextURIpost = $1;
		}
		$nextURIpost =~ s/&amp;/&/g;
		
		if ($response->content() =~ /name="otp_hidden"\svalue="(.+)"\s\/>/) {
			$postValueHidden1 = $1;
		}	
	
		if ($response->content() =~ /name="InputHiddenKeyInAppSendNew1"\svalue="(.+)"\s\/>/) {
			$postValueHidden2 = $1;
		}

		if ($response->content() =~ /name="InputHiddenKeyInAppSendNew2"\svalue="(.+)"\s\/>/) {
			$postValueHidden3 = $1;
		}

		if ($response->content() =~ /name="\$CPT"\stype="hidden"\svalue="(.+)"\s\/><input name=/) {
			$postValueHidden4 = $uri->encode($1, { encode_reserved => 1 } );
		}
	
		$logger->print ( "Login to website requires strong authentication with the transactionId: " . $transactionId . "! Waiting for 2 min...", Helpers::Logger::INFO);
		do {
			# Strong authentication validation URL
			sleep(3);
			$request->method('POST');
			$request->url('https://www.creditmutuel.fr/fr/banque/async/otp/SOSD_OTP_GetTransactionState.htm');
			$request->header('Content-Type' => 'application/x-www-form-urlencoded');
			$request->content('transactionId='.$transactionId);
			$response = $ua->request($request);
			$ok = ( ($count-- == 0) || ($response->content() !~ /<transactionState>PENDING<\/transactionState>/m) );
			$logger->print ( "XML content: ".$response->content(), Helpers::Logger::DEBUG);
		} while (!$ok );
		if ($response->content() !~ /<transactionState>VALIDATED<\/transactionState>/m) {
			$logger->print ( "The strong authentification for login: ".$login." failed after multiple tries!!!", Helpers::Logger::ERROR);
			$self->logOut($login);
			return 0;
		} else {
			$request->method('POST');
			my $validationURL='https://www.creditmutuel.fr'.$nextURIpost;
			# $logger->print ( "validation.aspx URL: ".$validationURL, Helpers::Logger::DEBUG);
			$request->url($validationURL);
			$request->header('Content-Type' => 'application/x-www-form-urlencoded');
			my $payload = 'otp_hidden='. $postValueHidden1 .'&InputHiddenKeyInAppSendNew1='. $postValueHidden2 .'&InputHiddenKeyInAppSendNew2='. $postValueHidden3 .'&$CPT='. $postValueHidden4 .'&_FID_DoValidate&_wxf2_cc=fr-FR';
			# $logger->print ( "validation.aspx payload: ".$payload, Helpers::Logger::DEBUG);
			$request->content($payload);
			$cookies->add_cookie_header($request);
			$response = $ua->request($request);	
			$cookies->extract_cookies($response);
		}			
	}
	
	# print "###### Dump cookies object ###########\n";
	# print Dumper $cookies->dump_cookies();
	 
	# Page perso
	sleep(1);
	$request->method('GET');
	$request->url('https://www.creditmutuel.fr/fr/banque/pageaccueil.html?referer=paci');
	$request->header('Content-Type' => 'text/plain');
	$request->content('');
	$cookies->add_cookie_header($request);
	
	# print "###### Dump request object ###########\n";
	# print Dumper $request;
	
	$response = $ua->request($request);	
	$cookies->extract_cookies($response);
	
	unless ($response->content() =~ /deconnexion\.cgi/m && $response->content() =~ /<title>Crédit Mutuel: Espace personnel<\/title>/m) {
		$logger->print ( "Login to website failed!", Helpers::Logger::ERROR);
		$logger->print ( "The login is locked for avoiding intempstive errors and bank website locking.", Helpers::Logger::ERROR);
		$self->loginLock();
		$logger->print ( "HTML content:\n".$response->content(), Helpers::Logger::DEBUG);
		return 0;				
	}
	
	$logger->print ( "Login to website v2 succeed", Helpers::Logger::INFO);
	$self->saveCookies($login);
	
	# Account statement download page
	sleep(1);
	$request->method('GET');
	$request->url('https://www.creditmutuel.fr/fr/banque/compte/telechargement.cgi');
	$request->header('Content-Type' => 'text/plain');
	$request->content('');
	$response = $ua->request($request);
	
	unless (${$response->content_ref} =~ /form id="P:F" action="(.+)"\smethod/) {
		$logger->print ( "Can't open download page", Helpers::Logger::ERROR);
		$logger->print ( "HTML content:\n".${$response->content_ref}, Helpers::Logger::DEBUG);
		return 0;				
	}
	$url .= $1;
	$url =~ s/&amp;/&/g;
	$self->{_url} = $url;
	$self->{_response} = $response;
	return 1;
}

sub logOut
{
	my ( $self, $login) = @_;
	my $logger = Helpers::Logger->new();
	my $ua = $self->{_ua};
	my $request = HTTP::Request->new();
	my $response;
	
	# Deconnexion
	$request->method('GET');
	$request->url('https://www.creditmutuel.fr/fr/deconnexion/deconnexion.cgi');
	$request->header('Content-Type' => 'text/plain');
	$request->content('');
	$response = $ua->request($request);
	$request->method('GET');
	$request->url('https://www.creditmutuel.fr/fr/identification/msg_deconnexion.html');
	$request->header('Content-Type' => 'application/x-www-form-urlencoded');
	$response = $ua->request($request);
	unless ($response->code() == '200') {
		$logger->print ( "Logout to website failed!", Helpers::Logger::ERROR);
		$logger->print ( "The login is locked for avoiding intempstive errors and bank website locking.", Helpers::Logger::ERROR);
		$self->loginLock();
		$logger->print ( "HTML content:\n".$response->content(), Helpers::Logger::DEBUG);
		return 0;				
	}
	return 1;

}

sub download
{
	my ( $self, $accountNumber, $dateFrom, $dateTo, $format ) = @_;
	my $logger = Helpers::Logger->new();
	my $correlationTable = Helpers::ConfReader->new("properties/correlation.txt");
	my $ua = $self->{_ua};
	my $url = $self->{_url};
	my $request = HTTP::Request->new();
	my $response = $self->{_response};
	if (!defined $format) {$format = 'csv';}
	
	my $accountNumberToUse = $accountNumber;
	my $correlatedAccountNumber = $correlationTable->readParamValue($accountNumber);
	unless ( !defined $correlatedAccountNumber ) {
		$accountNumberToUse = $correlatedAccountNumber;
		$logger->print ( "A correlation account found: $accountNumber -> $accountNumberToUse", Helpers::Logger::DEBUG);
	}
	
	my @arrayDateFrom = (sprintf("%02d", $dateFrom->day()), sprintf("%02d", $dateFrom->month()), $dateFrom->year());
	my @arrayDateTo = 	(sprintf("%02d", $dateTo->day()), sprintf("%02d", $dateTo->month()), $dateTo->year());
	unless ( $accountNumberToUse =~ /^(\d{5})\s(\d{9})\s(\d{2})$/ ) {
		$logger->print ( "Wrong account number format: $accountNumberToUse", Helpers::Logger::ERROR);
		return undef;
	}

	unless ( $response->content() =~ /CB:data_accounts_account_(.*)ischecked.+$accountNumberToUse/m ) {
		$logger->print ( "Account number: $accountNumberToUse can not be found", Helpers::Logger::ERROR);
		$logger->print ( "HTML content: \n".$response->content(), Helpers::Logger::DEBUG);
		return undef;	
	}
	my $checkedAccount = "CB%3Adata_accounts_account_$1ischecked=on";
	
	# File download 
	$request->method('POST');
	$request->url($url);
	$request->header('Referer' => 'https://www.creditmutuel.fr/fr/banque/compte/telechargement.cgi');
	$request->header('Host' => 'www.creditmutuel.fr');
	$request->header('Content-Type' => 'application/x-www-form-urlencoded');
	$request->content('data_formats_selected='.$format.'&data_formats_options_cmi_download=0&data_formats_options_ofx_format=7&Bool%3Adata_formats_options_ofx_zonetiers=false&CB%3Adata_formats_options_ofx_zonetiers=on&data_formats_options_qif_fileformat=6&data_formats_options_qif_dateformat=0&data_formats_options_qif_amountformat=0&data_formats_options_qif_headerformat=0&Bool%3Adata_formats_options_qif_zonetiers=false&CB%3Adata_formats_options_qif_zonetiers=on&data_formats_options_csv_fileformat=2&data_formats_options_csv_dateformat=0&data_formats_options_csv_fieldseparator=0&data_formats_options_csv_amountcolnumber=1&data_formats_options_csv_decimalseparator=1&'.$checkedAccount.'&data_daterange_value=range&%5Bt%3Adbt%253adate%3B%5Ddata_daterange_startdate_value='.$arrayDateFrom[0].'%2F'.$arrayDateFrom[1].'%2F'.$arrayDateFrom[2].'&%5Bt%3Adbt%253adate%3B%5Ddata_daterange_enddate_value='.$arrayDateTo[0].'%2F'.$arrayDateTo[1].'%2F'.$arrayDateTo[2].'&_FID_DoDownload.x=37&_FID_DoDownload.y=10&data_accounts_selection=10000000&data_formats_options_cmi_show=True&data_formats_options_qif_show=True&data_formats_options_excel_show=True&data_formats_options_excel_selected%255fformat=xl-2007&data_formats_options_csv_show=True');
	$response = $ua->request($request);
	return $response->content;
}

1;