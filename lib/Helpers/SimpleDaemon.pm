package Helpers::SimpleDaemon;

use lib '../../lib';
use strict;
use warnings;
use Helpers::Logger;

sub new
{
    my ( $class, $pidFile, $exec ) = @_;

    my $self = {
 	   pid_file     => $pidFile,
	   exec_command => $exec 	
    };
    bless( $self, $class );
    return $self;
}

sub init
{

	my ( $self ) = @_;
	my $logger = Helpers::Logger->new();
	my $pid = undef;
	
	if(!defined($pid = fork())) {
	   # fork returned undef, so unsuccessful
	   $logger->print ( "Can't fork child", Helpers::Logger::ERROR);
	} elsif ($pid == 0) {
	   # this branch is child
	   $logger->print ( "Launch the command: ". $self->{"exec_command"}, Helpers::Logger::DEBUG);
	   exec($self->{"exec_command"});
	} else {
	   # fork returned 0 nor undef
	   # so this branch is parent
	   
		if ( open( my $FH_PIDFILE, ">", $self->{"pid_file"} ) ) {
		    print $FH_PIDFILE $pid;
		    close $FH_PIDFILE;
		} else {
			$logger->print ( "Can't write in: ". $self->{"pid_file"}, Helpers::Logger::ERROR);
		}
		  
	   return $pid;
	}

}

sub status
{

	my ( $self ) = @_;
	my $pid = undef;
	my $logger = Helpers::Logger->new();
	
	if ( open( my $FH_PIDFILE, "<", $self->{"pid_file"} ) ) {
        $pid = <$FH_PIDFILE>;
        close $FH_PIDFILE;
        $logger->print ( "No valid PID '$pid' in pidfile: ". $self->{"pid_file"}, Helpers::Logger::ERROR) if $pid =~ /\D/s;
        $pid = ($pid =~ /^(\d+)$/)[0]; # untaint
	} else {
		$logger->print ( "Can't read in: ". $self->{"pid_file"}, Helpers::Logger::ERROR);
	}
	return 0 if ! $pid;
	return ( kill( 0, $pid ) ? $pid : 0 );
}

1;