#!/usr/bin/perl

use lib "./lib/";

use warnings;
use MIME::Base64;
use DateTime;
use Spreadsheet::ParseExcel;
use Spreadsheet::XLSX;
use File::Basename;

use Imager;

=pod
my $imagefile = "NSImgGrille.gif";

sub rgba2hex {
    sprintf "%02x%02x%02x%02x", map { $_ || 0 } @_;
}

{
    use Imager;
    open TXT, ">", "gif2text.txt";
    my %colors;
    my $img = Imager->new();
    $img->open( file => $imagefile ) or die $img->errstr;
    my ( $w, $h ) = ( $img->getwidth, $img->getheight );
    print "width: $w, height: $h\n";
    for my $i ( 0 .. $h - 1 ) {
    	print TXT "|";
        for my $j ( 0 .. $w - 1 ) {
            my $color = $img->getpixel( x => $j, y => $i );
            my $hcolor = rgba2hex $color->rgba();
            if ("$hcolor" eq "000000ff") {
            	print TXT "*";
            }
            else {print TXT " ";}
        	$colors{$hcolor}++;
        }
        print TXT "|\n";
    }
	close TXT;
    printf "\nImager: Number of colours: %d\n", scalar keys %colors;
}


use Excel::Writer::XLSX;

    # Create a new Excel workbook
    my $workbook = Excel::Writer::XLSX->new( 'perl.xlsx' );

    # Add a worksheet
    $worksheet = $workbook->add_worksheet();

    #  Add and define a format
    $format = $workbook->add_format();
    $format->set_bold();
    $format->set_color( 'red' );
    $format->set_align( 'center' );

    # Write a formatted and unformatted string, row and column notation.
    $col = $row = 0;
    $worksheet->write( $row, $col, 'Hi Excel!', $format );
    $worksheet->write( 1, $col, 'Hi Excel!' );

    # Write a number and a formula using A1 notation
    $worksheet->write( 'A3', 1.2345 );
    $worksheet->write( 'A4', '=SIN(PI()/4)' );





my $filePath = "categories.xls";
unless (-e $filePath) { die "File ".$filePath." can't be found"; }
my($filename, $dirs, $ext) = fileparse($filePath, qr/\.[^.]*/);
unless ($ext eq '.xls' or $ext eq '.xlsx') { die "File extension ".$ext." is not expected (only .xls or .xlsx files)"; }

my $parser;
my $worbook;

if ($ext eq ".xls") {
	$parser   = Spreadsheet::ParseExcel->new();
	$workbook = $parser->parse($filePath);
} else {
	$workbook = Spreadsheet::XLSX -> new ($filePath);
}


for my $worksheet ( $workbook->worksheets() ) {

	my ( $row_min, $row_max ) = $worksheet->row_range();
	my ( $col_min, $col_max ) = $worksheet->col_range();

	for my $row ( $row_min .. $row_max ) {
		for my $col ( $col_min .. $col_max ) {

			my $cell = $worksheet->get_cell( $row, $col );
			next unless $cell;

			print "Row, Col    = ($row, $col)\n";
			print "Value       = ", $cell->value(),       "\n";
			print "Unformatted = ", $cell->unformatted(), "\n";
			print "\n";
		}
	}
}

=cut
my %hash;
$hash{F1}='value1';
$hash{F2}='value2';
$key='F1';
print $hash{$key}, "\n";