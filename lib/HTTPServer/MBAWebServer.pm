package HTTPServer::MBAWebServer;
use parent HTTP::Server::Simple::CGI;

use lib '../../lib';
use strict;
use warnings;
use Helpers::SimpleDaemon;
use JSON;
use Helpers::Logger;
use Helpers::ConfReader;
  
my %dispatch = (
    '/mba/runmba' => \&run_mba,
    '/mba/synchowncloud' => \&synch_owncloud,
    # ...
);

sub new
{
	my ($class) = shift;
	resetPidFile();
	return $class->SUPER::new(@_);
}

sub handle_request {
    my $self = shift;
    my $cgi  = shift;
    
    my $logger = Helpers::Logger->new();   
    
    my $path = $cgi->path_info();
    my $handler = $dispatch{$path};
  
    if (ref($handler) eq "CODE") {
        print "HTTP/1.0 200 OK\r\n";
        $handler->($cgi);
          
    } else {
        print "HTTP/1.0 404 Not found\r\n";
        print $cgi->header,
              $cgi->start_html('Not found'),
              $cgi->h1('Not found'),
              $cgi->end_html;
    }
}

sub resetPidFile {
	my $logger = Helpers::Logger->new();
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	
	my @pidFilesToReset = (
		$prop->readParamValue("mba.pid.file"),
		$prop->readParamValue("owncloudsync.pid.file")
	);
	
	foreach my $pidFile (@pidFilesToReset) {
		if ( open( my $FH_PIDFILE, ">", $pidFile ) ) {
		    print $FH_PIDFILE 0;
		    close $FH_PIDFILE;
		} else {
			$logger->print ( "Can't write in: ". $pidFile, Helpers::Logger::ERROR);
		}
	}
}
  
sub run_mba {
    my $cgi  = shift;   # CGI.pm object
    return if !ref $cgi;
    
    my $prop = Helpers::ConfReader->new("properties/app.txt");
    my $logger = Helpers::Logger->new();
    
    my $forceStart = 0;
    my $key = undef;
    my $readOnly = 0;
    $key = $cgi->param('key');
    $forceStart = $cgi->param('force');
    $readOnly = $cgi->param('readOnly');
	my $pidFile = $prop->readParamValue("mba.pid.file");
	my $keyParam = (defined $key) ? " ".$key : "";
	
	print $cgi->header('application/json');
	manageCalledProcess ("mbaStatus", $pidFile, "perl ".$prop->readParamValue("mba.main.path").$keyParam, $forceStart, 120, $readOnly);  
}

sub synch_owncloud {
    my $cgi  = shift;   # CGI.pm object
    return if !ref $cgi;
    
    my $logger = Helpers::Logger->new();
    my $prop = Helpers::ConfReader->new("properties/app.txt");
    my $forceStart = $cgi->param('force');

	print $cgi->header('application/json');
 	manageCalledProcess ("owncloudSynchStatus", $prop->readParamValue("owncloudsync.pid.file"), "perl ". $prop->readParamValue("owncloudsync.path"), $forceStart, 15 );
}

sub manageCalledProcess {
	my ( $processName, $pidFile, $execPath, $forceStart, $maxAge, $readOnly) = @_;
	my $pid = 0;
	my $modifiedTimeinSecs = -1;
	my $json = new JSON;
	my %jsonHash = ();

	my $daemon = Helpers::SimpleDaemon->new( $pidFile, $execPath );
	
	$pid = $daemon->status();
	if ($pid) {
		%jsonHash = ($processName, "running", "pid", $pid);
		print $json->encode(\%jsonHash);
	}
	else {
	
		if (-e $pidFile) {
			$modifiedTimeinSecs = time()-(stat ($pidFile))[9];
		}
		
		my $modifiedTimeinMin = $modifiedTimeinSecs/60;
		
		if (($modifiedTimeinMin < 0 || $modifiedTimeinMin > $maxAge || $forceStart) && !$readOnly) {
			$pid = $daemon->init();
			if ($pid != 0) {
				# parent process
				%jsonHash = ($processName, "starting", "modifiedTimeInMin", sprintf("%.2f", $modifiedTimeinMin));
				print $json->encode(\%jsonHash);
			}
		}
		else {
			%jsonHash = ($processName, "ready", "modifiedTimeInMin", sprintf("%.2f", $modifiedTimeinMin));
			print $json->encode(\%jsonHash);
		}
	}
}

1;