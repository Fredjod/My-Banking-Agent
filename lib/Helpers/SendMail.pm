package Helpers::SendMail;

use lib "../../lib/";

use strict;
use warnings;
use MIME::Lite;
use Helpers::ConfReader;
use Helpers::Logger;
use HTML::Template;


sub new
{
	my ($class, $subject, $bodyTemplateProperty) = @_;

	my $config = Helpers::ConfReader->new("properties/app.txt");
	my $logger = Helpers::Logger->new();	
	my $to = $config->readParamValue("mailing.list"); if (!defined $to) {
		$logger->print ( "mailing.list property is undefined!", Helpers::Logger::ERROR);
		die "mailing.list property is undefined!";
	}
	my $server = $config->readParamValue("smtp.server"); if (!defined $server) {
		$logger->print ( "smtp.server property is undefined!", Helpers::Logger::ERROR);
		die "smtp.server property is undefined!";
	}
	my $templatePath = $config->readParamValue("$bodyTemplateProperty"); if ( !defined $templatePath || !(-e $templatePath) )  {
		$logger->print ( "$bodyTemplateProperty property is undefined or corresponding $templatePath file doesn't exist!", Helpers::Logger::ERROR);
		die "$bodyTemplateProperty property is undefined or corresponding $templatePath file doesn't exist!";
	}
	my $template = HTML::Template->new(filename => $templatePath);
	my $from = 'MyBankingAgent@home.com';

	my $msg = MIME::Lite->new (
		From    =>$from,
		To      =>$to,
		Subject =>$subject,
		Type    =>'multipart/related',
	);

    my $self = {
    	_msg =>	$msg,
    	_server =>	$server,
    	_template => $template,
    };
    bless $self, $class;
    return $self;
}

sub send {
	my ($self) = @_;
	my $msg = $self->{_msg};
	my $server = $self->{_server};
	my $template = $self->{_template};

	### Create a standalone part:
	my $part = MIME::Lite->new(
		Type     =>'text/html',
		Data     =>$template->output(),
	);
	$part->attr('content-type.charset' => 'UTF8');
	### Attach it to any message:
	$msg->attach($part);
	MIME::Lite->send('smtp', $server, Timeout=>60);
	$msg->send;
}

sub buildAlertBody {
	my ($self, $accountData, $currentBalance, $plannedBalance) = @_;
	my $template = $self->{_template};
	
	# Total value block
	$template->param(ACTUAL => euroFormating($currentBalance));
	$template->param(ACTUAL_COLOR => "#000000");
	if ($currentBalance < 0) { $template->param(ACTUAL_COLOR => "#ff0000"); } # red = #ff0000
	$template->param(FORECASTED => euroFormating($plannedBalance));
	$template->param(FORECASTED_COLOR => "#000000");
	if ($plannedBalance < 0) { $template->param(FORECASTED_COLOR => "#ff0000"); } # red = #ff0000
	
	my $var = $currentBalance-$plannedBalance;
	$template->param(VAREURO => euroFormating($var) );
	$template->param(VARRATIO => sprintf("%.2f%%", (($var)/$currentBalance)*100) );
	$template->param(VAR_COLOR => "#00ae00"); # lightgreen = #00ae00
	if ($var < 0) { $template->param(VAR_COLOR => "#ff0000"); } # red = #ff0000
	
	# Details loop
	my @loopLineDetails = ();
	
	my $pivotCredit = $accountData->groupBy ('FAMILY', 'CREDIT');
	my $pivotDebit = $accountData->groupBy ('FAMILY', 'DEBIT');
	
	foreach my $fam ('MONTHLY INCOMES', 'EXCEPTIONAL INCOMES') {
		push ( @loopLineDetails, buildDetailsLine ($fam, @$pivotCredit[0]->{$fam}, $accountData->sumForecastedOperationPerFamily($fam) ));
	}
	
	foreach my $fam ('MONTHLY EXPENSES', 'WEEKLY EXPENSES', 'EXCEPTIONAL EXPENSES') {
		push (@loopLineDetails, buildDetailsLine ($fam, @$pivotDebit[0]->{$fam}, $accountData->sumForecastedOperationPerFamily($fam) ));
	}	
	$template->param(LOOP_LINE_DETAILS => \@loopLineDetails);
	
	$self->{_template} = $template;
}

sub buildDetailsLine {
	my ($family, $actual, $forecasted) = @_;
	my %line;
	$line{FAMILY} = $family;
	$line{F_ACTUAL} = euroFormating($actual);
	$line{F_FORECASTED} = euroFormating($forecasted);
	my $var = $actual-$forecasted;
	$line{F_VAREURO} = euroFormating($var);
	if ( $actual !=0 ) {
		$line{F_VARRATIO} = sprintf("%.2f%%", (($var)/$actual)*100 );
	} else {
		$line{F_VARRATIO} = "NA"
	}
	$line{F_VAR_COLOR} = "#00ae00"; # lightgreen = #00ae00
	if ($var < 0) { $line{F_VAR_COLOR} = "#ff0000"; } # red = #ff0000
	return \%line;
}

sub euroFormating {
    my $text = reverse sprintf ('%.2f',$_[0]);
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1 /g;
    my $amount = scalar reverse $text;
    return $amount.' EUR';
}
1;