package Helpers::ExcelWorkbook;

use lib "../../lib/";

use warnings;
use MIME::Base64;
use DateTime;
use Spreadsheet::ParseExcel;
use Spreadsheet::XLSX;
use Spreadsheet::ParseExcel;
use File::Basename;
use Spreadsheet::WriteExcel;
use Helpers::Logger;

sub new
{
    my ($class) = @_;
    bless $self, $class;
    return $self;
}

sub openExcelWorkbook {
	my ($class, $filePath) = @_;
	my $logger = Helpers::Logger->new();
	
	unless (-e $filePath) { $logger->print ( "File ".$filePath." can't be found", Helpers::Logger::ERROR); die; }
	my($filename, $dirs, $ext) = fileparse($filePath, qr/\.[^.]*/);
	unless ($ext eq '.xls' or $ext eq '.xlsx') { $logger->print ( "File extension ".$ext." is not supported (only .xls or .xlsx are)", Helpers::Logger::ERROR); die; }
	
	my $parser;
	my $workbook;
	
	if ($ext eq ".xls") {
		$parser   = Spreadsheet::ParseExcel->new();
		$workbook = $parser->parse($filePath);
	} else {
		$workbook = Spreadsheet::XLSX -> new ($filePath);
	}
	return $workbook
}

sub fontTranslator {
	my ($class, $parsedFont) = @_;
	my %font = (
        font  => $parsedFont->{Name},
        size  => $parsedFont->{Height},
        color => $parsedFont->{Color},
        bold  => $parsedFont->{Bold},
        italic => $parsedFont->{Italic},
        underline=> $parsedFont->{Underline},
    );
    return \%font;
}

sub cellFormatTranslator {
	my ($class, $parsedFx) = @_;
	my $colorFill = $parsedFx->{Fill};
    my %shading = (
        bg_color => @$colorFill[2],
        fg_color => @$colorFill[1],
        pattern  => @$colorFill[0],
    );
    return \%shading;
}

sub createWorkbook {
	my ($class, $filePath) = @_;
	my $wb_out = Spreadsheet::WriteExcel->new( $filePath );
	my $i = 1;
	while (! defined $wb_out) {
		$filePath =~ s/\.xls/-$i.xls/;
		$wb_out = Spreadsheet::WriteExcel->new( $filePath );
		$i++;
	}
	chmod 0664, $filePath; # allow read/write to the user and group. Needed for Owncloud sharing.
	# Pre-requisite: the mba user and www-data should be both in the same unix group.
	return $wb_out;
}

sub readFromExcelSheetDetails {
	my ( $class, $ws, $maxColumnToCopy, $maxLineToCopy) = @_;
	my ( $row_min, $row_max ) = $ws->row_range();
	my ( $col_min, $col_max ) = $ws->col_range();
	my @tabSheet = ();

	if (defined $maxColumnToCopy) {
		 $col_max = $maxColumnToCopy unless $col_max < $maxColumnToCopy;
	}
	if (defined $maxLineToCopy) {
		 $row_max = $maxLineToCopy unless $row_max < $maxLineToCopy;
	}	
	for my $row ( 0 .. $row_max ) {
		for my $col ( 0 .. $col_max ) {
			my $cell = $ws->get_cell( $row, $col );	
			my %record;
			if (defined $cell) {
				%record = (
					'unformatted' => $cell->unformatted(),
					'value' => $cell->value(),
				);
				$tabSheet[$row][$col] = \%record;
			}
			else {
				$tabSheet[$row][$col] = undef;
			}
		}
	}
	return \@tabSheet;
}

1;