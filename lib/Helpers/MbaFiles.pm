package Helpers::MbaFiles;

use lib "../../lib/";
use Helpers::Logger;
use Helpers::ConfReader;
use Data::Dumper;
use Helpers::Date;

sub new
{
    my ($class) = @_;
    bless $self, $class;
    return $self;
}

sub getAccountConfigFilesName {
	my ($class) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $logger = Helpers::Logger->new();
	my $dirname = $prop->readParamValue('root.account.config');
	my $filepattern = $prop->readParamValue('account.config.pattern');
	
	my @files = ();
	if (! -d $dirname) {
		$logger->print ( "Couldn't open directory $dirname", Helpers::Logger::ERROR);
		die "Couldn't open dir $dirname";
	}
	opendir my($dh), $dirname;
	while ( readdir($dh) ) {
		if (-f "$dirname/$_" && $_ =~ /$filepattern/ ) {
			push (@files, "$dirname/$_");
	 	}
	}
	closedir $dh;	
	return @files;
}

sub getClosingFilePath {
	my ($class, $accountData) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $reportingDir = getReportingDirname ($accountData->getAccountNumber () );
	my $dt = $accountData->getMonth();
	return  $reportingDir.
			sprintf("%4d-%02d", $dt->year(), $dt->month()).
			'_'.
			$accountData->getAccountNumber().	
			$prop->readParamValue('account.reporting.closing.prefix')
		;
}

sub getActualsFilePath {
	my ($class, $accountData) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $reportingDir = getReportingDirname ($accountData->getAccountNumber () );
	my $dt = $accountData->getMonth();
	my $dth = Helpers::Date->new ();
	my $dtToday = $dth->getDate();
	if ($dt->month() != $dtToday->month() && $dt->day() != $dtToday->day()) {
		unlink glob $reportingDir.'*'.$prop->readParamValue('account.reporting.actuals.prefix');
	}
	return  $reportingDir.
			sprintf("%02d-%02d", $dt->month(), $dt->day()).
			$prop->readParamValue('account.reporting.actuals.prefix')
		;
}

sub getReportingDirname {
	my ( $accountNumber) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $logger = Helpers::Logger->new();

	my $rootReporting = $prop->readParamValue('root.account.reporting');
	if (! -d $rootReporting)	{
		mkdir $rootReporting;
	}
	if (! -d $rootReporting.'/'.$accountNumber) {
		mkdir $rootReporting.'/'.$accountNumber;
	}
	return $rootReporting.'/'.$accountNumber.'/';
}

1;