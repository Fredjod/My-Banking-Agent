package AccountStatement::PlannedOperation;

use lib '../../lib';

use strict;
use warnings;
use DateTime;
use Helpers::ConfReader;
use utf8;
use Helpers::Logger;
use Helpers::Date;
use Helpers::ExcelWorkbook;
use Spreadsheet::ParseExcel;
use Data::Dumper;

sub new
{
    my ($class, $account, $plannedPath) = @_;
    my $prop = Helpers::ConfReader->new("properties/app.txt");
    unless ( defined $plannedPath) { $plannedPath = Helpers::MbaFiles->getPlannedOperationPath ( $account ); }
    
    # 
    my $self = {
    	_isPlannedOperation => ( $plannedPath ) ? 1 : 0,
    	_data 				=> loadExcelFile ( $plannedPath, 0 ),
    };
    bless $self, $class;
    
    # Associate a familly to each planned operation
    $self->qualifyOperation ( $account );
    # Looking for in the current operations wether some planned operations exist
    $self->LookingForOperation ( $account );
    
    return $self;
}

sub loadExcelFile {
	
	my ( $wbPath, $wsNumber ) = @_;
	my $logger = Helpers::Logger->new();
	
	my @data;
	
	if (not defined $wbPath) { return \@data; } 
	
	$logger->print ( "Loading planned operations file: $wbPath", Helpers::Logger::DEBUG);
	
	my $wb = Helpers::ExcelWorkbook->openExcelWorkbook($wbPath);
	my $ws = $wb->worksheet( $wsNumber );		

	my ( $row_min, $row_max ) = $ws->row_range();
	for my $row ( 0 .. $row_max ) {
		my ($cell, %line);
		# Date column
		$cell = $ws->get_cell( $row, 0 );
		if ( defined $cell && $cell->unformatted() =~ /\d+/ ) {
			$line{'KEY'} = $cell->unformatted();
			$line{'DATE'} = $cell->value();
			# keyword column
			$cell = $ws->get_cell( $row, 1 );
			if ( defined $cell ) { 
				$line{'DETAILS'} = $cell->value();
				# operation column
				$cell = $ws->get_cell ( $row, 2 );
				if (defined $cell && $cell->unformatted() =~ /^[+-]?\d+(\.\d+)?$/ ) {
					$line{'AMOUNT'} = $cell->unformatted();
					$line{'FAMILY'} = "";
					$line{'FOUND'} = 0;
					$cell = $ws->get_cell ( $row, 3 );
					$line{'FORECASTED'} = 'N';
					if (defined $cell) {
						if (uc ($cell->unformatted()) eq "Y") { $line{'FORECASTED'} = 'Y'; }
					}
					push (@data, \%line);
				}
			}
		}
	}
	@data =  sort { $a->{'KEY'} <=> $b->{'KEY'} } @data;
	return \@data;
}

sub saveExcelFile {
	my( $self, $account ) = @_;
	if ($self->{_isPlannedOperation}) {
		my $prop = Helpers::ConfReader->new("properties/app.txt");
		my $wb_out = Helpers::ExcelWorkbook->createWorkbook ( Helpers::MbaFiles->getPlannedOperationPath ( $account ) );
		my $currency_format = $wb_out->add_format( num_format => eval($prop->readParamValue('workbook.dashboard.currency.format')));
		my $date_format = $wb_out->add_format(num_format => $prop->readParamValue('workbook.dashboard.date.format'));
		my $ws_out = $wb_out->add_worksheet();

		my $ops = $self->{_data};
		
		$ws_out->write( 0, 0, 'DATE' );
		$ws_out->write( 0, 1, 'KEYWORD' );
		$ws_out->write( 0, 2, 'AMOUNT' );
		$ws_out->write( 0, 3, 'FORECASTED' );
		my $row = 1;
		for my $line ( @$ops) {
			if (not $line->{'FOUND'}) {
				$ws_out->write( $row, 0, $line->{'KEY'}, $date_format );
				$ws_out->write( $row, 1, $line->{'DETAILS'} );
				$ws_out->write( $row, 2, $line->{'AMOUNT'}, $currency_format );
				$ws_out->write( $row, 3, $line->{'FORECASTED'} );
				$row++;
			}
		}
		$ws_out->set_column(0, 0,  10);	
		$ws_out->set_column(1, 1,  40);
		$ws_out->set_column(2, 2,  15);
		$ws_out->set_column(3, 3,  15);
		$ws_out->set_zoom(85);
	}
}

sub qualifyOperation {
	my( $self, $account ) = @_;
	if ($self->{_isPlannedOperation}) {
		my $ops = $self->{_data};
		for my $line ( @$ops) {
			$line->{'FAMILY'} = $account->findOperationsFamily($line);
		}
	}
}

sub LookingForOperation {
	my( $self, $account ) = @_;
	if ($self->{_isPlannedOperation}) {
		my $planOps = $self->{_data};
		my $MTDOps = $account->getOperations ();
		
		for my $mtd ( @$MTDOps) {
			for my $plan ( @$planOps ) {
				my ($d,$m,$y) = $plan->{'DATE'} =~ /^([0-9]{2})\/([0-9]{2})\/([0-9]{4})\z/;
				my $planDate = DateTime->new(
			   		year      => $y,
			   		month     => $m,
			   		day       => $d,
			   		time_zone => 'local',
				);	
				if ( $mtd->{'LIBELLE'} =~ /$plan->{'DETAILS'}/ ) {
					if ($mtd->{'FAMILY'} eq $plan->{'FAMILY'}) {
						if (( $plan->{'AMOUNT'} < 0) ?  $mtd->{'DEBIT'} == $plan->{'AMOUNT'} : $mtd->{'CREDIT'} == $plan->{'AMOUNT'}) {
							if (DateTime->compare( $planDate, $account->getMonth () ) <= 0 ) {
								$plan->{'FOUND'} = 1;
							}
						}
					}
				}    
			}
		}
	}
}

sub isPlannedOperation {
	my( $self) = @_;
	return $self->{_isPlannedOperation};		
}

sub getPlannedOperations {
	my( $self) = @_;
	return $self->{_data};		
}

1;