package Helpers::Logger;

use lib "../../lib/";

use strict;
use warnings;
use Helpers::ConfReader;
use DateTime;
use File::stat;

use constant DEBUG		=> 0;
use constant INFO		=> 1;
use constant ERROR		=> 2;

sub new
{
    my ($class, $logger) = @_;
    if (!defined $logger) {
    	$logger = "logs.output";
    }
	my $config = Helpers::ConfReader->new("properties/app.txt");
	my $output = $config->readParamValue($logger);
	my $levelConf = $config->readParamValue("logs.level");
	my $level;
	if (!defined $levelConf ) {
		$level = INFO;
	} else {
		$level = ($levelConf eq 'DEBUG') ? DEBUG : (($levelConf eq 'INFO' ) ? INFO : ERROR );
	}
    my $self = { 
    	_output =>	$output,
    	_levelConf => $level,
    };
    bless $self, $class;
    return $self;
}

sub print {
	my ( $self, $message, $level ) = @_;
	my $today = DateTime->now(time_zone=>'local');
	my $config = Helpers::ConfReader->new("properties/app.txt");
	my $maxFileSizeInBytes = $config->readParamValue("log.maxsize");
	if (!defined $maxFileSizeInBytes) { $maxFileSizeInBytes = 200000 } # 200Ko by default.
	my $output = $self->{_output};
	my $levelConf = $self->{_levelConf};	
	if (!defined $level) { $level = INFO }
	if ( $level >= $levelConf ) {
		my $levelTxt = ($level == DEBUG) ? 'DEBUG':(($level == INFO ) ? 'INFO' : 'ERROR' );
		$message = $today->datetime().':'.$levelTxt.':'.$message."\n";
		if ($output eq "STDOUT") {
			print STDOUT $message;
		}
		else {
			open LOG, ">>", $output or die "Couldn't open log file $output\n";
			print LOG $message;
			close LOG;
			my $currentLogSize = stat($output)->size;
			if ( $currentLogSize > $maxFileSizeInBytes ) {
				rotateLogFile ($output);
			}
		}
	}
}

sub rotateLogFile {
	my ( $currentFile ) = @_;
	if (-e $currentFile.".1.txt") {
		unlink glob $currentFile.".1.txt";
	}
	rename $currentFile, $currentFile.".1.txt";
}

1;