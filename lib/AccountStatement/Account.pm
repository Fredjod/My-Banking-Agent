package AccountStatement::Account;
# This is an abstract class, must never be instanciated!

use lib '../../lib';
use strict;
use warnings;

use constant INCOME		=> 2;
use constant EXPENSE	=> 1;


sub new
{
    my ($class, $url) = @_;
    my $self = {};
    bless $self, $class;
    return $self;
}
    

1;