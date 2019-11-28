#!/usr/bin/perl
use lib "./lib/";

use warnings;
use MIME::Base64;
use DateTime;
use File::Basename;
use Imager;
use HTML::Parser;
use Data::Dumper;
use Encode;


#my $imagefile = "NSImgGrille.gif";
my $imagefile = "f-158185486993832738126732718724886509310.png";


my %digit = (
			8192 => 0, 
			917504 => 1,
			1044480 => 2, 
			512000 => 3,
			8216576 => 4,
			507904 => 5,
			778240 => 6,
			1617920 => 7,
			1548288 => 8,
			1032192 => 9
			);


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
            if ("$hcolor" eq "1f2728ff") {
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

{
    use Imager;
    my %colors;
    my $img = Imager->new();
    $img->open( file => $imagefile ) or die $img->errstr;
    my ( $w, $h ) = ( $img->getwidth, $img->getheight );
    my $squareH = 80;
    my $squareW = 83;

	for my $raw (1 .. 2) {
		for my $col (1 .. 5) {
			my $binSum = 0;
			for my $y (($raw-1)*$squareH+20 .. $raw*$squareH-20) {
				 my $bin;
				 for my $x (($col-1)*$squareW+25.. $col*$squareW-25) {
					my $color = $img->getpixel( y => $y, x => $x );
					my $hcolor = rgba2hex $color->rgba();
					if ("$hcolor" eq "1f2728ff") {
						$bin .="1";
					}
					else { $bin .= "0" ; }
				}
				$binSum = $binSum ^ oct("0b$bin");
			}
			print "case ", $col + (($raw-1)*5), " => ", $digit{$binSum}, "\n";
		}
		
	}
}