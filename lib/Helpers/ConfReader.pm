package Helpers::ConfReader;

use lib "../../lib/";

use strict;
use warnings;

sub new
{
	my ($class, $confFile) = @_;
	my $confData = undef;
	if (-e $confFile) {
		open my $in, "<", $confFile;
		read $in, $confData, -s $in;
		close $in;
	}

    my $self = {
        _confData =>	$confData,
    };
    bless $self, $class;
    return $self;
}

sub trim {
	my ($str) = @_;
	return $str =~ s/^\s+|\s+$//gr;
}

sub readParamValueList
{
	my ( $self, $param ) = @_;
	my $confData = $self->{_confData};
	unless ( defined $confData ) { return undef;}
	my ($line, @list);
	foreach $line (split /\n/ ,$confData) {
		if ($line =~ /^$param\s*=\s*(.*)/) {
			@list = map { trim($_) } split(';', $1);
		}
	}
	return \@list;
}

sub readParamValue
{
	my ( $self, $param ) = @_;
	my $confData = $self->{_confData};
	unless ( defined $confData ) { return undef;}
	my ($line, $value);
	foreach $line (split /\n/ ,$confData) {
		if ($line =~ /^\s*$param\s*=\s*(.*)/) {
			$value = trim($1);
		}
	}
	return $value;
}

1;