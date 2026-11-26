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
	$self->getStoredCookies($login);
	
	# Check whether already logged in to resuse the current access
	# Page perso
	sleep(1);
	$request->method('GET');
	$request->url('https://www.creditmutuel.fr/fr/banque/pageaccueil.html');
	$request->header('Content-Type' => 'text/plain');
	$request->content('');
	$response = $self->requestCall($request, 1);

	
	unless ($response->content() =~ /deconnexion\.cgi/m && $response->content() =~ /<title>Crédit Mutuel: Espace personnel<\/title>/m) {
		%{$cookies} = (); # clear cookies store
		$self->{_cookies} = $cookies;
		$cookies->{'eu-consent'} = '%7B%22%2Ffr%2F%22%3A%7B%22solutions%22%3A%7B%22ABTasty%22%3Afalse%2C%22uxcustom%22%3Afalse%2C%22persado%22%3Afalse%2C%22DCLIC%22%3Afalse%2C%22googleMarketingPlatform%22%3Afalse%2C%22commanders_act%22%3Afalse%2C%22meta%22%3Afalse%2C%22bing%22%3Afalse%2C%22youtube%22%3Afalse%2C%22ivs%22%3Afalse%2C%22googleMaps%22%3Afalse%7D%2C%22expireDate%22%3A%222026-06-22T02%3A50%3A49.787Z%22%2C%22version%22%3A%224.0%22%7D%7D';

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
		#$cookies->{'mba-session'} = encode_base64($login);
		$self->saveCookies($login);
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

	my $idStatment=undef;
	if ( defined $1 ) {
		if ( $1 ne '') {
			if (length($1) == 3) {
				$idStatment = substr($1, 0, 1);
			}
			else {
				$idStatment = substr($1, 0, 2);
			}
		}
	}

	my $boolAccount = '';
	if (!defined $idStatment) {
		$boolAccount = "Bool%3Adata_accounts_account_ischecked=true";
		$boolAccount .= "&CB%3Adata_accounts_account_ischecked=on";
	}
	else {
		$boolAccount = "Bool%3Adata_accounts_account_ischecked=false";
	}
	for (my $i=2; $i<14; $i++) {
		if (!defined $idStatment) {
			$boolAccount .= "&Bool%3Adata_accounts_account_".$i."__ischecked=false";
		}
		else {		
			if ($idStatment ne $i ) {
				$boolAccount .= "&Bool%3Adata_accounts_account_".$i."__ischecked=false";
			}
			else {
				$boolAccount .= "&Bool%3Adata_accounts_account_".$i."__ischecked=true";
				$boolAccount .= "&CB%3Adata_accounts_account_".$i."__ischecked=on";
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

	my $uri = URI::Encode->new( { encode_reserved => 1 } );
	
    my @pairs;
	my $html = $response->content();

	while ($html =~ /<input\b([^>]*)>/sig) {
        my $attrs = $1;
        
        # Extraction du name
        my ($nd, $ns) =
            $attrs =~ /\bname\s*=\s*(?:"([^"]*)"|'([^']*)')/is;

        my $name = defined($nd) ? $nd : $ns;
        next unless defined $name;

        # Filtrage des champs recherchés
        next unless $name =~ /data_accounts_account_/i;
        next unless $name =~ /(?:webid|is%5fcard)/i;

        # Extraction du value
        my ($vd, $vs) =
            $attrs =~ /\bvalue\s*=\s*(?:"([^"]*)"|'([^']*)')/is;

        my $value = defined($vd) ? $vd
                  : defined($vs) ? $vs : '';

        push @pairs, [$name, $value];
    }
   
    my $webid = join '',
        map { '&' . $uri->encode($_->[0]) . '=' . $uri->encode($_->[1]) } @pairs;
	
	my $CPT="";
	if ($response->content() =~ /name="\$CPT"\stype="hidden"\svalue="([^"]*)"\s\/><input name=/) {
		$CPT = "%24CPT=".$uri->encode($1);
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
		'&Bool%3Adata_formats_options_ofx_zonetiers=true'.
		'&CB%3Adata_formats_options_ofx_zonetiers=on'.
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
		'&data_daterange_value=range'.
		'&%5Bt%3Adbt%253adate%3B%5Ddata_daterange_startdate_value='.$arrayDateFrom[0].'%2F'.$arrayDateFrom[1].'%2F'.$arrayDateFrom[2].
		'&%5Bt%3Adbt%253adate%3B%5Ddata_daterange_enddate_value='.$arrayDateTo[0].'%2F'.$arrayDateTo[1].'%2F'.$arrayDateTo[2].
		'&%5Bt%3Axsd%253astring%3B%5Ddata_accounts_selection='.$selectedStatment.
		 $webid.
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