package Helpers::MbaFiles;

use lib "../../lib/";

use strict;
use warnings;

use Helpers::Logger;
use Helpers::ConfReader;
use Data::Dumper;
use Helpers::Date;


sub getAccountConfigFilesName {
	my ($class, $filepattern) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $logger = Helpers::Logger->new();
	my $dirname = $prop->readParamValue('root.account.config');
	if (!defined $filepattern ) { $filepattern = $prop->readParamValue('account.config.pattern'); }
	
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
	my ($class, $checkingAccount) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $number = $checkingAccount->getAccountNumber ();
	
	$number =~ s/\s//g; #remove space in the original account number
	my $reportingDir = getClosingDirname ($number);
	my $dt = $checkingAccount->getMonth();
	return  $reportingDir.
			sprintf("%4d-%02d", $dt->year(), $dt->month()).
			'_'.$number.
			$prop->readParamValue('account.reporting.closing.prefix');
}

sub getForecastedFilePath {
	my ($class, $checkingAccount) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $number = $checkingAccount->getAccountNumber ();
	
	$number =~ s/\s//g; #remove space in the original account number
	my $reportingDir = getReportingDirname ($number);
	my $dt = $checkingAccount->getMonth();
	my $filePath =  $reportingDir.
			sprintf("%4d-%02d", $dt->year(), $dt->month()).
			$prop->readParamValue('account.reporting.forecasted.prefix');
	if (! -e $filePath ) {
		unlink glob $reportingDir.'*'.$prop->readParamValue('account.reporting.forecasted.prefix');
	}
	return $filePath;	
}

sub getActualsFilePath {
	my ($class, $checkingAccount) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $number = $checkingAccount->getAccountNumber ();
	$number =~ s/\s//g;
	my $reportingDir = getReportingDirname ( $number );
	my $dt = $checkingAccount->getMonth();

	my $filePath =  $reportingDir.
					sprintf("%02d-%02d", $dt->month(), $dt->day()).
					$prop->readParamValue('account.reporting.actuals.prefix');	
	
	if (! -e $filePath ) {
		unlink glob $reportingDir.'*'.$prop->readParamValue('account.reporting.actuals.prefix');
	}
	return $filePath;
}

sub getPreviousMonthCacheFilePath {
	my ( $class, $stat ) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $logger = Helpers::Logger->new();
	my $number = $stat->getAccountNumber ();
	$number =~ s/\s//g;
	my $prefix = sprintf("%04d%02d", $stat->getMonth->year(), $stat->getMonth->month() );
	
	# if needed, clean the old cache file on the disk
	my $dth = Helpers::Date->new($stat->getMonth());
	my $oldDateCache = $dth->rollPreviousMonth();
	my $OldFileCachePrefix = sprintf("%04d%02d", $oldDateCache->year(), $oldDateCache->month() );
	if (-e getReportingDirname($number).$prop->readParamValue('account.previous.month.cache').".".$OldFileCachePrefix ) {
		unlink glob getReportingDirname($number).$prop->readParamValue('account.previous.month.cache').".".$OldFileCachePrefix;
	}
				 
	return getReportingDirname ( $number ).$prop->readParamValue('account.previous.month.cache').".".$prefix;
}	

sub getLastSavingFilePath {
	my ( $class ) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $logger = Helpers::Logger->new();
	my $dirname = $prop->readParamValue('root.account.reporting');
	my $fileprefix = $prop->readParamValue('account.reporting.saving.prefix');
	my $filePath = undef;
	
	if (-d $dirname) {
		opendir my($dh), $dirname;
		while ( readdir($dh) ) {
			if (-f "$dirname/$_" && $_ =~ /[0-9]{4}_[0-9]{2}$fileprefix/ ) {
				$filePath = "$dirname/$_";
		 	}
		}
		closedir $dh;
	}
	return $filePath;
}

sub getSavingFilePath {
	my ( $class, $dt ) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $logger = Helpers::Logger->new();
	my $dirname = $prop->readParamValue('root.account.reporting');

	if (! -d $dirname) {
		mkdir $dirname;
		chmod 0771, $dirname;
	}
	
	return  $dirname.'/'.
			sprintf("%04d_%02d", $dt->year(), $dt->month()).
			$prop->readParamValue('account.reporting.saving.prefix');	
}

sub getPlannedOperationPath {
	
	my ($class, $checkingAccount) = @_;
	my $logger = Helpers::Logger->new();
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $number = $checkingAccount->getAccountNumber ();
	$number =~ s/\s//g;
	my $reportingDir = getReportingDirname ($number);

	my $filePath =  $reportingDir.
					$prop->readParamValue('account.reporting.planned.prefix');	
	
	if (! -e $filePath ) {
		$logger->print ( "File $filePath doesn't exist", Helpers::Logger::DEBUG);
		return undef;
	} else {
		return $filePath;
	}
}

sub getClosingDirname {
	my ( $number) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $logger = Helpers::Logger->new();

	my $closingDir = $prop->readParamValue('dir.account.closing');
	my $rootClosing = getReportingDirname ($number);
	checkDirectory ($rootClosing.'/'.$closingDir);
	
	return $rootClosing.'/'.$closingDir.'/';

}

sub getReportingDirname {
	my ( $number) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $logger = Helpers::Logger->new();

	my $rootReporting = $prop->readParamValue('root.account.reporting');
	checkDirectory ($rootReporting);
	checkDirectory ($rootReporting.'/'.$number);
	return $rootReporting.'/'.$number.'/';
}

sub checkDirectory {
	my ( $dir) = @_;
	if (! -d $dir)	{
		mkdir $dir;
		chmod 0771, $dir;
	}
}

1;