package WebConnector::CMMockWebConnector;

use lib '../../lib';
use parent 'WebConnector::CMWebConnector2';

use strict;
use warnings;
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
	return 1;
}

sub logOut
{
	return 1;
}

sub download
{
	my ( $self, $accountNumber, $dateFrom, $dateTo, $format ) = @_;
	my $logger = Helpers::Logger->new();

	# mock file name format: {accountnumber}_{NN (dateTo month)}.{format (ofx, qif)}
	# They are stored in a "mock"" directory in the the "t" directory.
	
	$accountNumber =~ s/\s//g;
	my $filePath = "./mock/".$accountNumber."_".sprintf("%02d", $dateTo->month()).".".$format;

	open IN, "<", $filePath or do {
		$logger->print ( "Mock file $filePath not exists", Helpers::Logger::ERROR);
		return undef;
	};
	read IN, my $data, -s IN;
	close IN;	
	return $data;
}

1;