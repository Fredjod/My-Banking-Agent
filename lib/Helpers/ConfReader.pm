package Helpers::ConfReader;

use strict;
use warnings;


sub new
{
	my ($class, $confFile) = @_;
	open my $in, "<", $confFile or die "Can't open file $confFile.\n";
	read $in, my $confData, -s $in;
	close $in;	
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
	my ($line, $value);
	foreach $line (split /\n/ ,$confData) {
		if ($line =~ /^\s*$param\s*=\s*(.*)/) {
			$value = trim($1);
		}
	}
	return $value;
}

1;