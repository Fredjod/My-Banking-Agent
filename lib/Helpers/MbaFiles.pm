package Helpers::MbaFiles;

use lib "../../lib/";

use strict;
use warnings;

use Helpers::Logger;
use Helpers::ConfReader;
use Data::Dumper;
use Helpers::Date;
use utf8;
use JSON;


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

sub getYearlyClosingFilePath {
	my ($class, $checkingAccount) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $number = $checkingAccount->getAccountNumber ();
	
	$number =~ s/\s//g; #remove space in the original account number
	my $reportingDir = getClosingDirname ($number);
	my $dt = $checkingAccount->getMonth();
	return  $reportingDir.
			sprintf("%4d", $dt->year() ).
			'_'.$number.
			$prop->readParamValue('account.reporting.yearly.prefix');
}

sub getForecastedFilePath {
	my ($class, $checkingAccount) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $logger = Helpers::Logger->new();
	my $number = $checkingAccount->getAccountNumber ();
	
	$number =~ s/\s//g; #remove space in the original account number
	my $reportingDir = getReportingDirname ($number);
	my $dt = $checkingAccount->getMonth();
	my $filePath =  $reportingDir.
			sprintf("%4d-%02d", $dt->year(), $dt->month()).
			$prop->readParamValue('account.reporting.forecasted.prefix');
	if (! -e $filePath ) {
		my $deletingMask = $reportingDir.'*'.$prop->readParamValue('account.reporting.forecasted.prefix');
		unlink glob $deletingMask;
		$logger->print ( "Deleting old Forecasted files: $deletingMask", Helpers::Logger::INFO);
	}
	return $filePath;	
}

sub getActualsFilePath {
	my ($class, $checkingAccount) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $logger = Helpers::Logger->new();
	my $number = $checkingAccount->getAccountNumber ();
	$number =~ s/\s//g;
	my $reportingDir = getReportingDirname ( $number );
	my $dt = $checkingAccount->getMonth();

	my $filePath =  $reportingDir.
					sprintf("%02d-%02d", $dt->month(), $dt->day()).
					$prop->readParamValue('account.reporting.actuals.prefix');	
	
	if (! -e $filePath ) {
		my $deletingMask = $reportingDir.'*'.$prop->readParamValue('account.reporting.actuals.prefix');
		unlink glob $deletingMask;
		$logger->print ( "Deleting all Actuals files: $deletingMask", Helpers::Logger::INFO);
	}
	return $filePath;
}

sub getPreviousMonthCacheFilePath { # to be called with the previous month statement only
	my ( $class, $stat ) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $logger = Helpers::Logger->new();
	my $number = $stat->getAccountNumber ();
	$number =~ s/\s//g;
	my $prefix = sprintf("%04d%02d", $stat->getMonth->year(), $stat->getMonth->month() );
	
	# if needed, clean the old cache file on the disk
	my $dth = Helpers::Date->new($stat->getMonth());
	my $oldDateCache = $dth->rollPreviousMonth();
	my $oldFileCachePrefix = sprintf("%04d%02d", $oldDateCache->year(), $oldDateCache->month() );
	my $oldFileCacheToDelete = getReportingDirname($number).$prop->readParamValue('account.previous.month.cache').".".$oldFileCachePrefix;
	if (-e $oldFileCacheToDelete ) {
		unlink glob $oldFileCacheToDelete;
		$logger->print ( "Deleting old cache file: $oldFileCacheToDelete", Helpers::Logger::INFO);
	}
				 
	return getReportingDirname ( $number ).$prop->readParamValue('account.previous.month.cache').".".$prefix;
}	

sub getPreviousMonthCacheObjectiveFilePath { # to be called with the Previous month statement only
	my ( $class, $stat ) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $logger = Helpers::Logger->new();
	my $number = $stat->getAccountNumber ();
	$number =~ s/\s//g;
	
	my $prefix = sprintf("%04d%02d", $stat->getMonth->year(), $stat->getMonth->month() );
	my $previousMonthObjectiveCacheFileName = getReportingDirname ( $number ).$prop->readParamValue('previous.month.objective.cache').".".$prefix;
	my $lastCurrentObjectiveCacheFileName = getReportingDirname ( $number ).$prop->readParamValue('current.month.objective.cache').".".$prefix;
	
	# if previous month objective file does not exist and the last month current objectives file exists, then move it to previous month objective
	if (! -e $previousMonthObjectiveCacheFileName && -e $lastCurrentObjectiveCacheFileName) {
		rename ($lastCurrentObjectiveCacheFileName, $previousMonthObjectiveCacheFileName); 
		$logger->print( "Rename: $lastCurrentObjectiveCacheFileName to: $previousMonthObjectiveCacheFileName", Helpers::Logger::INFO);
	}

	# if needed, clean the old cache file on the disk
	my $dth = Helpers::Date->new($stat->getMonth());
	my $oldDateCache = $dth->rollPreviousMonth();
	my $oldFileCachePrefix = sprintf("%04d%02d", $oldDateCache->year(), $oldDateCache->month() );
	my $oldFileCacheToDelete = getReportingDirname($number).$prop->readParamValue('previous.month.objective.cache').".".$oldFileCachePrefix;
	if (-e $oldFileCacheToDelete ) {
		unlink glob $oldFileCacheToDelete;
		$logger->print ( "Deleting old cache file: $oldFileCacheToDelete", Helpers::Logger::INFO);
	}
			 
	return $previousMonthObjectiveCacheFileName;
}

sub getCurrentMonthCacheObjectiveFilePath { # to be called with the Current month statement only
	my ( $class, $stat ) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $logger = Helpers::Logger->new();
	my $number = $stat->getAccountNumber ();
	$number =~ s/\s//g;
	
	my $prefix = sprintf("%04d%02d", $stat->getMonth->year(), $stat->getMonth->month() );
	return getReportingDirname ( $number ).$prop->readParamValue('current.month.objective.cache').".".$prefix;
}

sub readBudgetObjectiveCacheFile {
	my ( $class, $filePath ) = @_;
	my $logger = Helpers::Logger->new();
	open IN, "<", $filePath or do {
		$logger->print ( "File ".$filePath." cant't be opened!", Helpers::Logger::INFO);
		return undef;
	};
	my %record;
	while ( my $line = <IN> ) {
		$line =~ s/\r|\n//g;
		my @recTxt = split (':', $line);
		$record{$recTxt[0]} = $recTxt[1];
	}
	close IN;
	return \%record;
}

sub writeBudgetObjectiveCacheFile {
	my ( $class, $filePath, $record ) = @_;
	my $logger = Helpers::Logger->new();
	my $recordTxt = "";
	foreach my $key ( keys %{$record} ) {
		$recordTxt .= "$key:".$record->{$key}."\n";
	}
	open OUT, ">", $filePath or
		$logger->print ( "File ".$filePath." cant't be written!", Helpers::Logger::ERROR);
	print OUT $recordTxt;
	close OUT;
}

sub writeJSONFile {
	my ( $class, $fileName, $record ) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $logger = Helpers::Logger->new();
	
	my $filePath = $prop->readParamValue('webreport.json.reporting').'/'.$fileName;
	open OUT, ">", $filePath or
		$logger->print ( "File ".$filePath." cant't be written!", Helpers::Logger::ERROR);
	print OUT encode_json $record;
	close OUT;
}


sub deleteOldSavingFiles {
	my ( $class, $dt ) = @_;
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	my $logger = Helpers::Logger->new();
	my $dirname = $prop->readParamValue('root.account.reporting');
	my $fileprefix = $prop->readParamValue('account.reporting.saving.prefix');
	my $filePath = undef;
	my $currentSavingFile = $class->getSavingFilePath ( $dt );
	
	if (-d $dirname) {
		opendir my($dh), $dirname;
		while ( readdir($dh) ) {
			if (-f "$dirname/$_" && $_ =~ /[0-9]{4}_[0-9]{2}$fileprefix/ ) {
				$filePath = "$dirname/$_";
				do {
					unlink glob $filePath;
					$logger->print ( "Deleting old saving file: $filePath", Helpers::Logger::INFO);
				}
				unless $filePath eq $currentSavingFile;
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