package Helpers::Logger;

use lib "../../lib/";

use strict;
use warnings;
use Helpers::ConfReader;
use DateTime;

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
			open LOG, ">>", $output or die "Couldn't open file $output\n";
			print LOG $message;
			close LOG;		
		}
	}
}

sub write {
	my ( $self, $txt ) = @_;
	my $output = $self->{_output};
	open LOG, ">", $output or die "Couldn't open file $output\n";
	print LOG $txt;
	close LOG;
}

sub read {
	my ( $self ) = @_;
	my $txt='';
	my $output = $self->{_output};
	if (-f $output) {
		open LOG, "<", $output or die "Couldn't open file $output\n";
		read LOG, $txt, 10000;
		close LOG;
	}
	return $txt;
}

1;