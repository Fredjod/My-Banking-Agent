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
	resetMbaPidFile();
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
    my $pid = 0;
	my $modifiedTimeinSecs = -1;
	my $pidFile = $prop->readParamValue("mba.pid.file");
	my $keyParam = (defined $key) ? " ".$key : "";
	my $daemon = Helpers::SimpleDaemon->new( $pidFile, "perl ".$prop->readParamValue("mba.main.path").$keyParam );
	my $json = new JSON;
	my %jsonHash = ();


	print $cgi->header('application/json');
	
	$pid = $daemon->status();
	if ($pid) {
		%jsonHash = ("mbaStatus", "running", "pid", $pid);
		print $json->encode(\%jsonHash);
	}
	else {
	
		if (-e $pidFile) {
			$modifiedTimeinSecs = time()-(stat ($pidFile))[9];
		}
		
		my $modifiedTimeinMin = $modifiedTimeinSecs/60;
		
		if (($modifiedTimeinMin < 0 || $modifiedTimeinMin > 120 || $forceStart) && !$readOnly) {
			$pid = $daemon->init();
			if ($pid != 0) {
				# parent process
				%jsonHash = ("mbaStatus", "starting", "modifiedTimeInMin", sprintf("%.2f", $modifiedTimeinMin));
				print $json->encode(\%jsonHash);
			}
		}
		else {
			%jsonHash = ("mbaStatus", "ready", "modifiedTimeInMin", sprintf("%.2f", $modifiedTimeinMin));
			print $json->encode(\%jsonHash);
		}
	}   
}

sub resetMbaPidFile
{
	my $logger = Helpers::Logger->new();
	my $prop = Helpers::ConfReader->new("properties/app.txt");
	
	if ( open( my $FH_PIDFILE, ">", $prop->readParamValue("mba.pid.file") ) ) {
	    print $FH_PIDFILE 0;
	    close $FH_PIDFILE;
	} else {
		$logger->print ( "Can't write in: ". $prop->readParamValue("mba.pid.file"), Helpers::Logger::ERROR);
	}
}

sub synch_owncloud {
    my $cgi  = shift;   # CGI.pm object
    return if !ref $cgi;
    
    my $prop = Helpers::ConfReader->new("properties/app.txt");
    my $logger = Helpers::Logger->new();
    $logger->print ( "process synch_owncloud request", Helpers::Logger::DEBUG);
    my $daemon = Helpers::SimpleDaemon->new( $prop->readParamValue("owncloudsync.pid.file "), "docker exec owncloud_server occ files:scan \"--path=/jaudin/files/MBA\"" );
    $daemon->init();
}

1;