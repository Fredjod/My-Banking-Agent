package WebConnector::CMWebConnector;

use lib '../../lib';
use parent 'WebConnector::GenericWebConnector';

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Cookies;
use MIME::Base64;
use DateTime;

sub new
{
	my ($class) = shift;
	return $class->SUPER::new(@_);
}

sub logIn
{
	my ( $self, $login, $password ) = @_;
	my $ua = $self->{_ua};
	my $cookie_jar = $self->{_cookie_jar};
	my $url = $self->{_url};
	my $request = HTTP::Request->new();
	my $response;
	
	# Page acceuil
	$request->method('GET');
	$request->url('https://www.creditmutuel.fr/cmidf/fr/banques/accueil/services-banque-a-distance.html');
	$response = $ua->request($request);
	$cookie_jar->extract_cookies($response);
	
	# Login
	$ua->cookie_jar($cookie_jar);
	$request->method('POST');
	$request->url('https://www.creditmutuel.fr/cmidf/fr/identification/default.cgi');
	$request->header('Referer' => 'https://www.creditmutuel.fr/cmidf/fr/banques/accueil/services-banque-a-distance.html');
	$request->header('Content-Type' => 'application/x-www-form-urlencoded');
	$request->content('_cm_app=SITFIN&_cm_langue=fr&_cm_user='.$login.'&_cm_pwd='.$password.'&input_label_pwd=Mot%20de%20passe&x=0&y=0');
	$response = $ua->request($request);
	$cookie_jar->extract_cookies($response);
	
	# Page perso
	$ua->cookie_jar($cookie_jar);
	$request->method('GET');
	$request->url('https://www.creditmutuel.fr/cmidf/fr/banque/espace_personnel.aspx');
	$request->header('Content-Type' => 'text/plain');
	$request->content('');
	$response = $ua->request($request);
	$cookie_jar->extract_cookies($response);
	
	# Page Download
	$ua->cookie_jar($cookie_jar);
	$request->method('GET');
	$request->url('https://www.creditmutuel.fr/cmidf/fr/banque/compte/telechargement.cgi');
	$request->header('Content-Type' => 'text/plain');
	$request->content('');
	$response = $ua->request($request);
	$cookie_jar->extract_cookies($response);
	
	if (${$response->content_ref} =~ /form id="P:F" action="(.+)"\smethod/) {
		$url .= $1;
		$url =~ s/&amp;/&/g;
	}
	$self->{_url} = $url;
	$self->{_response} = $response;
}

sub logOut
{
	my ( $self ) = @_;
	my $ua = $self->{_ua};
	my $cookie_jar = $self->{_cookie_jar};
	my $request = HTTP::Request->new();
	my $response;
	
	# Deconnexion
	$ua->cookie_jar($cookie_jar);
	$request->method('GET');
	$request->url('https://www.creditmutuel.fr/cmidf/fr/identification/deconnexion/deconnexion.cgi');
	$request->header('Content-Type' => 'text/plain');
	$request->content('');
	$response = $ua->request($request);
	$cookie_jar->extract_cookies($response);
	$ua->cookie_jar($cookie_jar);
	$request->method('GET');
	$request->url('https://www.creditmutuel.fr/cmidf/fr/identification/msg_deconnexion.html');
	$response = $ua->request($request);
}

sub downloadCSV
{
	my ( $self, $accountNumber, $dateFrom, $dateTo ) = @_;
	my $ua = $self->{_ua};
	my $cookie_jar = $self->{_cookie_jar};
	my $url = $self->{_url};
	my $request = HTTP::Request->new();
	my $response = $self->{_response};
	
	my @arrayDateFrom = (sprintf("%02d", $dateFrom->day()), sprintf("%02d", $dateFrom->month()), $dateFrom->year());
	my @arrayDateTo = 	(sprintf("%02d", $dateTo->day()), sprintf("%02d", $dateTo->month()), $dateTo->year());
	$accountNumber =~ s/^(\d{5})(\d{9})(\d{2})$/$1 $2 $3/;
	$response->content() =~ /CB:data_accounts_account_(.*)ischecked.+$accountNumber/m;
	my $checkedAccount = "CB%3Adata_accounts_account_$1ischecked=on";
	
	# CSV file download 
	$ua->cookie_jar($cookie_jar);
	$request->method('POST');
	$request->url($url);
	$request->header('Referer' => 'https://www.creditmutuel.fr/cmidf/fr/banque/compte/telechargement.cgi');
	$request->header('Host' => 'www.creditmutuel.fr');
	$request->header('Content-Type' => 'application/x-www-form-urlencoded');
	$request->content('data_formats_selected=csv&data_formats_options_cmi_download=0&data_formats_options_ofx_format=7&Bool%3Adata_formats_options_ofx_zonetiers=false&CB%3Adata_formats_options_ofx_zonetiers=on&data_formats_options_qif_fileformat=6&data_formats_options_qif_dateformat=0&data_formats_options_qif_amountformat=0&data_formats_options_qif_headerformat=0&Bool%3Adata_formats_options_qif_zonetiers=false&CB%3Adata_formats_options_qif_zonetiers=on&data_formats_options_csv_fileformat=2&data_formats_options_csv_dateformat=0&data_formats_options_csv_fieldseparator=0&data_formats_options_csv_amountcolnumber=1&data_formats_options_csv_decimalseparator=1&'.$checkedAccount.'&data_daterange_value=range&%5Bt%3Adbt%253adate%3B%5Ddata_daterange_startdate_value='.$arrayDateFrom[0].'%2F'.$arrayDateFrom[1].'%2F'.$arrayDateFrom[2].'&%5Bt%3Adbt%253adate%3B%5Ddata_daterange_enddate_value='.$arrayDateTo[0].'%2F'.$arrayDateTo[1].'%2F'.$arrayDateTo[2].'&_FID_DoDownload.x=37&_FID_DoDownload.y=10&data_accounts_selection=10000000&data_formats_options_cmi_show=True&data_formats_options_qif_show=True&data_formats_options_excel_show=True&data_formats_options_csv_show=True');
	$response = $ua->request($request);
	$cookie_jar->extract_cookies($response);		
	return $response->content;
}
1;