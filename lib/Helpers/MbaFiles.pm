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
	my ($class, $CheckingAccount) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $reportingDir = getReportingDirname ($CheckingAccount->getAccountNumber () );
	my $dt = $CheckingAccount->getMonth();
	return  $reportingDir.
			sprintf("%4d-%02d", $dt->year(), $dt->month()).
			'_'.
			$CheckingAccount->getAccountNumber().	
			$prop->readParamValue('account.reporting.closing.prefix')
		;
}

sub getActualsFilePath {
	my ($class, $CheckingAccount) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $reportingDir = getReportingDirname ($CheckingAccount->getAccountNumber () );
	my $dt = $CheckingAccount->getMonth();

	my $filePath =  $reportingDir.
					sprintf("%02d-%02d", $dt->month(), $dt->day()).
					$prop->readParamValue('account.reporting.actuals.prefix');	
	
	if (! -e $filePath ) {
		unlink glob $reportingDir.'*'.$prop->readParamValue('account.reporting.actuals.prefix');
	}
	return $filePath;
}

sub getReportingDirname {
	my ( $accountNumber) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $logger = Helpers::Logger->new();

	my $rootReporting = $prop->readParamValue('root.account.reporting');
	if (! -d $rootReporting)	{
		mkdir $rootReporting;
		chmod 0771, $rootReporting;
	}
	if (! -d $rootReporting.'/'.$accountNumber) {
		mkdir $rootReporting.'/'.$accountNumber;
		chmod 0771, $rootReporting.'/'.$accountNumber;
		
	}
	return $rootReporting.'/'.$accountNumber.'/';
}

1;