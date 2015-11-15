package Helpers::Date;

use lib "../../lib/";

use warnings;
use DateTime;

sub new
{
    my ($class, $date) = @_;
    if (!defined $date) {
    	$date = DateTime->now(time_zone => 'local' );
    }
	my $self = {
    	_date =>	$date->clone(),
	};
	bless $self, $class;
    return $self;
}

sub rollPreviousMonth
{
	my ($self) = @_;
	my $prevMonthDate = $self->getDate();
	my $month = $prevMonthDate->month();
	my $year = $prevMonthDate->year();
	# first day of last month
	if ($month > 1) {
		$prevMonthDate->set_month($month-1);
	} else { # shift to december of previous year
		$prevMonthDate->set_month(12);
		$prevMonthDate->set_year($year-1);
	}
	return $prevMonthDate;
}

sub rollPreviousMonday
{
	my ($self) = @_;
	my $prevMondayDate = $self->getDate();
	if ($prevMondayDate->day() - $prevMondayDate->day_of_week() < 0) { # prev monday before 1st day of month
		$prevMondayDate->set_day(1);
	} else {
		$prevMondayDate->set_day($prevMondayDate->day() - $prevMondayDate->day_of_week() + 1)
	}
	return $prevMondayDate;
}

sub setDate
{
	my ($self, $date) = @_;
	$self->{_date} = $date;
}

sub getDate
{
	my ($self) = @_;
	return $self->{_date}->clone();
}

1;