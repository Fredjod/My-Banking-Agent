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
	my $cookie_jar = $self->{_cookie_jar};
	my $url = $self->{_url};
	my $request = HTTP::Request->new();
	my $response;

	# Check whether the login is locked due to a past login error
	unless (! $self->isLoginLock() ) {
		$logger->print ( "The website login is locked. Check the auth config and delelte the file lock.login.txt before retrying.", Helpers::Logger::ERROR);
		return 0;				
	}
	
	# Page acceuil
	$request->method('GET');
	$request->url('https://www.creditmutuel.fr/fr/authentification.html');
	$response = $ua->request($request);
	$cookie_jar->extract_cookies($response);
	
	# Login
	$ua->cookie_jar($cookie_jar);
	$request->method('POST');
	$request->url('https://www.creditmutuel.fr/fr/authentification.html');
	$request->header('Content-Type' => 'application/x-www-form-urlencoded');
	$request->content('_cm_user='.$login.'&flag=password&_cm_pwd='.$password.'&submit.x=35&submit.y=15');
	$response = $ua->request($request);
	$cookie_jar->extract_cookies($response);
	
	# Page perso
	$ua->cookie_jar($cookie_jar);
	$request->method('GET');
	$request->url('https://www.creditmutuel.fr/fr/banque/pageaccueil.html');
	$request->header('Content-Type' => 'text/plain');
	$request->content('');
	$response = $ua->request($request);
	$cookie_jar->extract_cookies($response);

	unless ($response->content() =~ /deconnexion\.cgi/m) {
		$logger->print ( "Login to website failed!", Helpers::Logger::ERROR);
		$logger->print ( "The login is locked for avoiding intempstive errors and bank website locking.", Helpers::Logger::ERROR);
		$self->loginLock();
		$logger->print ( "HTML content: \n".$response->content(), Helpers::Logger::DEBUG);
		return 0;				
	}
	$logger->print ( "Login to website v2 succeed", Helpers::Logger::INFO);
	
	# Page Download
	$ua->cookie_jar($cookie_jar);
	$request->method('GET');
	$request->url('https://www.creditmutuel.fr/fr/banque/compte/telechargement.cgi');
	$request->header('Content-Type' => 'text/plain');
	$request->content('');
	$response = $ua->request($request);
	$cookie_jar->extract_cookies($response);
	
	unless (${$response->content_ref} =~ /form id="P:F" action="(.+)"\smethod/) {
		$logger->print ( "Can't read URL download", Helpers::Logger::ERROR);
		$logger->print ( "HTML content: \n".${$response->content_ref}, Helpers::Logger::DEBUG);
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
	my ( $self ) = @_;
	my $logger = Helpers::Logger->new();
	my $ua = $self->{_ua};
	my $cookie_jar = $self->{_cookie_jar};
	my $request = HTTP::Request->new();
	my $response;
	
	# Deconnexion
	$ua->cookie_jar($cookie_jar);
	$request->method('GET');
	$request->url('https://www.creditmutuel.fr/fr/deconnexion/deconnexion.cgi');
	$request->header('Content-Type' => 'text/plain');
	$request->content('');
	$response = $ua->request($request);
	$cookie_jar->extract_cookies($response);
	$ua->cookie_jar($cookie_jar);
	$request->method('GET');
	$request->url('https://www.creditmutuel.fr/fr/identification/msg_deconnexion.html');
	$request->header('Content-Type' => 'application/x-www-form-urlencoded');
	$response = $ua->request($request);
	unless ($response->content() =~ /<title>Page de d.connexion - Cr.dit Mutuel<\/title>/m) {
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
	my $ua = $self->{_ua};
	my $cookie_jar = $self->{_cookie_jar};
	my $url = $self->{_url};
	my $request = HTTP::Request->new();
	my $response = $self->{_response};
	if (!defined $format) {$format = 'csv';}
	
	my @arrayDateFrom = (sprintf("%02d", $dateFrom->day()), sprintf("%02d", $dateFrom->month()), $dateFrom->year());
	my @arrayDateTo = 	(sprintf("%02d", $dateTo->day()), sprintf("%02d", $dateTo->month()), $dateTo->year());
	unless ( $accountNumber =~ /^(\d{5})\s(\d{9})\s(\d{2})$/ ) {
		$logger->print ( "Wrong account number format: $accountNumber", Helpers::Logger::ERROR);
		return undef;
	}
	unless ( $response->content() =~ /CB:data_accounts_account_(.*)ischecked.+$accountNumber/m ) {
		$logger->print ( "Account number: $accountNumber can not be found", Helpers::Logger::ERROR);
		$logger->print ( "HTML content: \n".$response->content(), Helpers::Logger::DEBUG);
		return undef;	
	}
	my $checkedAccount = "CB%3Adata_accounts_account_$1ischecked=on";
	
	# File download 
	$ua->cookie_jar($cookie_jar);
	$request->method('POST');
	$request->url($url);
	$request->header('Referer' => 'https://www.creditmutuel.fr/fr/banque/compte/telechargement.cgi');
	$request->header('Host' => 'www.creditmutuel.fr');
	$request->header('Content-Type' => 'application/x-www-form-urlencoded');
	$request->content('data_formats_selected='.$format.'&data_formats_options_cmi_download=0&data_formats_options_ofx_format=7&Bool%3Adata_formats_options_ofx_zonetiers=false&CB%3Adata_formats_options_ofx_zonetiers=on&data_formats_options_qif_fileformat=6&data_formats_options_qif_dateformat=0&data_formats_options_qif_amountformat=0&data_formats_options_qif_headerformat=0&Bool%3Adata_formats_options_qif_zonetiers=false&CB%3Adata_formats_options_qif_zonetiers=on&data_formats_options_csv_fileformat=2&data_formats_options_csv_dateformat=0&data_formats_options_csv_fieldseparator=0&data_formats_options_csv_amountcolnumber=1&data_formats_options_csv_decimalseparator=1&'.$checkedAccount.'&data_daterange_value=range&%5Bt%3Adbt%253adate%3B%5Ddata_daterange_startdate_value='.$arrayDateFrom[0].'%2F'.$arrayDateFrom[1].'%2F'.$arrayDateFrom[2].'&%5Bt%3Adbt%253adate%3B%5Ddata_daterange_enddate_value='.$arrayDateTo[0].'%2F'.$arrayDateTo[1].'%2F'.$arrayDateTo[2].'&_FID_DoDownload.x=37&_FID_DoDownload.y=10&data_accounts_selection=10000000&data_formats_options_cmi_show=True&data_formats_options_qif_show=True&data_formats_options_excel_show=True&data_formats_options_excel_selected%255fformat=xl-2007&data_formats_options_csv_show=True');
	$response = $ua->request($request);
	$cookie_jar->extract_cookies($response);		
	return $response->content;
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
	my ( $self, $account, $dateFrom, $dateTo ) = @_;

	my ( $bankData, $balance );
	my $logger = Helpers::Logger->new();
	# Get the operations from website
	$logger->print ( "Log in to ".$account->getBankName()." website", Helpers::Logger::INFO);
	if ( $self->logIn( Helpers::WebConnector->getLogin ($account->getAccountAuth), Helpers::WebConnector->getPwd ($account->getAccountAuth) ) ) {
		$logger->print ( "Download and parse bank statement for account ".$account->getAccountNumber()." for month ".$dateTo->month(), Helpers::Logger::INFO);
		$balance = $self->downloadBalance ( $account->getAccountNumber(), $dateFrom, $dateTo );
		$account->setBalance($balance);
		$bankData = $self->downloadOperations ( $account->getAccountNumber(), $dateFrom, $dateTo );
		if ($#{$bankData} > -1) {
			$self->backwardBalanceCompute ( $bankData, $balance );
		}
	}
	$logger->print ( "Log out", Helpers::Logger::INFO);
	$self->logOut();
	return $bankData;
}

sub downloadMultipleBankStatement {
	my ( $self, $AccountList, $dateFrom, $dateTo ) = @_;
	my $logger = Helpers::Logger->new();
	
	my @result;
	
	for my $info ( @$AccountList ) {
		# As input a array of hashes:
		my $bankname = $info->{'BANK'};
		my $authKey = $info->{'KEY'};
		my $desc = 	$info->{'DESC'};
		my $number = $info->{'NUMBER'};
		$logger->print ( "Log in to ".$bankname." website", Helpers::Logger::INFO);
		if ( $self->logIn(  Helpers::WebConnector->getLogin ($authKey),  Helpers::WebConnector->getPwd ($authKey) ) ) {
			my %record;
			$logger->print ( "Download and parse bank statement for account ".$desc." for month ".$dateFrom->month()."...", Helpers::Logger::INFO);
			# As output an array of hashes:
			$record{'BALANCE'} = $self->downloadBalance ( $number, , $dateFrom, $dateTo );
			$record{'BANKOPE'} = $self->downloadOperations ( $number, $dateFrom, $dateTo );
			$record{'NUMBER'} = $$number;
			$record{'DESC'} = $desc;
			push (@result, \%record);
		}
	}
	$logger->print ( "Log out", Helpers::Logger::INFO);
	$self->logOut();
	return \@result;
}

1;