package WebConnector::CMWebConnector3;

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
	my $request = HTTP::Request->new();
	my $response;

	# Check whether the login is locked due to a past login error
	unless (! $self->isLoginLock() ) {
		$logger->print ( "The website login is locked. Check the auth config and delete the file lock.login.txt before retrying.", Helpers::Logger::ERROR);
		return 0;				
	}
	
	#  Adding of RGPD consent cookie to the cookieJAR:
	my $cookies = $self->{_cookies};
	$cookies->{'eu-consent'} = '%7B%22%2Ffr%2F%22%3A%7B%22solutions%22%3A%7B%22ABTasty%22%3Afalse%2C%22uxcustom%22%3Afalse%2C%22persado%22%3Afalse%2C%22DCLIC%22%3Afalse%2C%22googleMarketingPlatform%22%3Afalse%2C%22commanders_act%22%3Afalse%2C%22meta%22%3Afalse%2C%22bing%22%3Afalse%2C%22youtube%22%3Afalse%2C%22ivs%22%3Afalse%2C%22googleMaps%22%3Afalse%7D%2C%22expireDate%22%3A%222026-06-22T02%3A50%3A49.787Z%22%2C%22version%22%3A%224.0%22%7D%7D';

	# Check whether already logged in to resuse the current access
	# Page perso
	sleep(1);
	$request->method('GET');
	$request->url('https://www.creditmutuel.fr/fr/banque/pageaccueil.html');
	$request->header('Content-Type' => 'text/plain');
	$request->content('');
	$response = $self->requestCall($request, 1);

	
	unless ($response->content() =~ /deconnexion\.cgi/m && $response->content() =~ /<title>Crédit Mutuel: Espace personnel<\/title>/m) {
		# Page authentification
		$request->method('GET');
		$request->url( 'https://www.creditmutuel.fr/fr/authentification.html' );
		$response = $self->requestCall($request, 2);
		
		# Login
		$request->method('POST');
		$request->url('https://www.creditmutuel.fr/fr/authentification.html');
		$request->header('Content-Type' => 'application/x-www-form-urlencoded');
		$request->content('_cm_user='.$login.'&flag=password&_charset_=UTF-8&_cm_pwd='.$password);
		$cookies = $self->{_cookies};
		$cookies->{'lastCnx'} = 'password';
		$response = $self->requestCall($request, 3);
	
		# Authentification forte
		unless ($response->content() !~ /<title>Authentification forte<\/title>/m) {
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
				$response = $self->requestCall($request, 4);
				$ok = ( ($count-- == 0) || ($response->content() !~ /<transactionState>PENDING<\/transactionState>/m) );
				$logger->print ( "XML content: ".$response->content(), Helpers::Logger::DEBUG);
			} while (!$ok );
			if ($response->content() !~ /<transactionState>VALIDATED<\/transactionState>/m) {
				$logger->print ( "The strong authentification for login: ".$login." failed after multiple tries!!!", Helpers::Logger::ERROR);
				$self->logOut($login);
				return 0;
			} else {
				$request->method('POST');
				$request->url('https://www.creditmutuel.fr'.$nextURIpost); # /fr/banque/validation.aspx?...
				$request->header('Referer' => 'https://www.creditmutuel.fr/fr/banque/validation.aspx');	
				$request->header('Content-Type' => 'application/x-www-form-urlencoded'); 
				$request->content('otp_hidden='. $postValueHidden1.
								  '&InputHiddenKeyInAppSendNew1='. $postValueHidden2.
								  '&InputHiddenKeyInAppSendNew2='. $postValueHidden3.
								  '&$CPT='. $postValueHidden4.
								  '&_FID_DoValidate&_wxf2_cc=fr-FR'
								 );
				$cookies = $self->{_cookies};
				$cookies->{'initially_requested_url'} = '/fr/banque/pageaccueil.html';
				$cookies->{'rid'} = '616';
				$response = $self->requestCall($request, 5);
			}			
		}
		
		$request->method('GET');
		$request->url( 'https://www.creditmutuel.fr/fr/banque/pageaccueil.html' );
		$response = $self->requestCall($request, 51);
		
		unless ($response->content() =~ /deconnexion\.cgi/m && $response->content() =~ /<title>Crédit Mutuel: Espace personnel<\/title>/m) {
			$logger->print ( "Login to website failed!", Helpers::Logger::ERROR);
			$logger->print ( "The login is locked for avoiding intempstive errors and bank website locking.", Helpers::Logger::ERROR);
			$self->loginLock();
			$logger->print ( "HTML content:\n".$response->content(), Helpers::Logger::DEBUG);
			return 0;				
		}
		
		$logger->print ( "Login to website v3 succeed", Helpers::Logger::INFO);
	}

	# Account statement download page
	sleep(1);
	$request->method('GET');
	$request->url('https://www.creditmutuel.fr/fr/banque/compte/telechargement.cgi');
	$request->header('Content-Type' => 'text/plain');
	$request->content('');
	$response = $self->requestCall($request, 6);
	
	unless ($response->content() =~ /form id="C:P:F" action="(.+)"\smethod/) {
		$logger->print ( "Can't open download page", Helpers::Logger::ERROR);
		$logger->print ( "The login is locked for avoiding intempstive errors and bank website locking.", Helpers::Logger::ERROR);
		$self->loginLock();
		$logger->print ( "HTML content:\n".$response->content(), Helpers::Logger::DEBUG);
		return 0;			
	}
	$logger->print ( "Loading of download page succeed", Helpers::Logger::INFO);
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
	$response = $self->requestCall($request, 8);
	
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
	my $boolAccount = "Bool%3Adata_accounts_account_$1ischecked=true";
	
	my $idStatment=undef;
	if ( defined $1 ) {
		if ( $1 ne '') {
			$idStatment = substr($1, 0, 1);
		}
	}

	my $boolFalse = '';
	for (my $i=1; $i<14; $i++) {
		if ($i == 1) { 
			if (defined $idStatment ) {
				$boolFalse = "&Bool%3Adata_accounts_account_ischecked=false";
			}
		}
		else {
			if ( defined $idStatment) {
				if ($idStatment ne $i ) {
					$boolFalse .= "&Bool%3Adata_accounts_account_".$i."__ischecked=false";
				}
			}
		}
	}

	my $selectedStatment = '';
	if ( defined $idStatment ) {
		$selectedStatment = '0';
	}
	else {
		$selectedStatment = '1';
	}
	for (my $i=2; $i<14; $i++) {
		if ( !defined $idStatment ) {
			$selectedStatment .= '0';
		}
		else {
			if ( $idStatment ne $i ) {
				$selectedStatment .= '0';
			}
			else {
				$selectedStatment .= '1';
			}
		}
	}
	
	my $CPT="";
	my $uri = URI::Encode->new( { encode_reserved => 0 } );
	if ($response->content() =~ /name="\$CPT"\stype="hidden"\svalue="(.+)"\s\/><input name=/) {
		$CPT = "%24CPT=".$uri->encode($1, { encode_reserved => 1 } );
	}

	# File download
	$request->method('POST');
	$request->url($url);
	$request->header('Referer' => 'https://www.creditmutuel.fr/fr/banque/compte/telechargement.cgi');
	$request->header('Host' => 'www.creditmutuel.fr');
	$request->header('Content-Type' => 'application/x-www-form-urlencoded');
	$request->content(
		'data_formats_selected='.$format.'&data_formats_options_cmi_download=0'.
		'&data_formats_options_ofx_format=7'.
		'&Bool%3Adata_formats_options_ofx_zonetiers=false'.
		'&data_formats_options_qif_fileformat=6'.
		'&data_formats_options_qif_dateformat=0'.
		'&data_formats_options_qif_amountformat=0'.
		'&data_formats_options_qif_headerformat=0'.
		'&Bool%3Adata_formats_options_qif_zonetiers=true'.
		'&CB%3Adata_formats_options_qif_zonetiers=on'.
		'&data_formats_options_csv_fileformat=2'.
		'&data_formats_options_csv_dateformat=0'.
		'&data_formats_options_csv_fieldseparator=0'.
		'&data_formats_options_csv_amountcolnumber=1'.
		'&data_formats_options_csv_decimalseparator=0'.
		'&Bool%3Adata_formats_options_csv_includebudgetanalysisinfos=false'.
		'&'.$boolAccount.
		'&'.$checkedAccount.
		 $boolFalse.
		'&data_daterange_value=range'.
		'&%5Bt%3Adbt%253adate%3B%5Ddata_daterange_startdate_value='.$arrayDateFrom[0].'%2F'.$arrayDateFrom[1].'%2F'.$arrayDateFrom[2].
		'&%5Bt%3Adbt%253adate%3B%5Ddata_daterange_enddate_value='.$arrayDateTo[0].'%2F'.$arrayDateTo[1].'%2F'.$arrayDateTo[2].
		'&%5Bt%3Axsd%253astring%3B%5Ddata_accounts_selection='.$selectedStatment.
		'&%5Bt%3Axsd%253astring%3B%5Ddata_accounts_account_webid=64cd03a2b9ae0974fba985c7b8f3179963a25f2dae1c47361ec9bd99ffb4c699&data_accounts_account_is%255fcard=&%5Bt%3Axsd%253astring%3B%5Ddata_accounts_account_2__webid=0e4482e278c5d121f2091b91db34dc38ae2ac8289f10c59ef08ac508136b787f&data_accounts_account_2__is%255fcard=&%5Bt%3Axsd%253astring%3B%5Ddata_accounts_account_3__webid=633334cecb22a1bafec7658db015d99fa349db947d8c3f70f6f58257b3037d81&data_accounts_account_3__is%255fcard=&%5Bt%3Axsd%253astring%3B%5Ddata_accounts_account_4__webid=a322851c2464141ee4da170b62cd3f43167156f920e5339fbc635d283b15e4bd&data_accounts_account_4__is%255fcard=&%5Bt%3Axsd%253astring%3B%5Ddata_accounts_account_5__webid=b377a082df2b4d55a01a431d912ebd06212ef8b90b9bcd486d1dc5019d943bd4&data_accounts_account_5__is%255fcard=&%5Bt%3Axsd%253astring%3B%5Ddata_accounts_account_6__webid=0f3df3ee288b3c77f55a5f89f7a2cdf4049bd00aba99c32f79338865df52eb2f&data_accounts_account_6__is%255fcard=&%5Bt%3Axsd%253astring%3B%5Ddata_accounts_account_7__webid=d65553398e0c238b08811edf74123f304a6be87b36bf82cc072aad7701734a57&data_accounts_account_7__is%255fcard=&%5Bt%3Axsd%253astring%3B%5Ddata_accounts_account_8__webid=8820205a7580d6c8a406b1a096cc23341b06d2a2d3abff4ccb771433b2ebc372&data_accounts_account_8__is%255fcard=&%5Bt%3Axsd%253astring%3B%5Ddata_accounts_account_9__webid=c46e781adcccb8742915ee8b1f70ebb1eb6292b77f2d930e5a8e65bdfd7da7e3&data_accounts_account_9__is%255fcard=&%5Bt%3Axsd%253astring%3B%5Ddata_accounts_account_10__webid=18dafb5f11fc15907afc5f1d8baf61f323d84f2e4c935a0b9ae6b6f41bf60699&data_accounts_account_10__is%255fcard=&%5Bt%3Axsd%253astring%3B%5Ddata_accounts_account_11__webid=0e1008e70673d1c2274793bf6ed431e90eb6ea0faca75ac2c5790590d45a949d&data_accounts_account_11__is%255fcard=&%5Bt%3Axsd%253astring%3B%5Ddata_accounts_account_12__webid=26d5a9269549d6bc4bf454ffc1c04198b94d3ba26028d2f386d7d96e5003c7a0&data_accounts_account_12__is%255fcard=&%5Bt%3Axsd%253astring%3B%5Ddata_accounts_account_13__webid=b0e8e156ba4196f8d91ae42fffdd88068cf5583bb3c0f658548621a46529d667&data_accounts_account_13__is%255fcard='.
		'&'.$CPT.
		'&_wxf2_cc=fr-FR'.
		'&_FID_DoDownload='
	);
	my $cookies = $self->{_cookies};
	$cookies->{'msgs-authent-state'} = 'true';

	$response = $self->requestCall($request, 7);
	return $response->content;
}

1;