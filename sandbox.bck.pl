#!/usr/bin/perl

use lib "./lib/";


use warnings;
use MIME::Base64;
use DateTime;
#use Spreadsheet::ParseExcel;
#use Spreadsheet::XLSX;
#use File::Basename;
#use Imager;
use Data::Dumper;
#use HTML::Parser;
#use Data::Dumper;
#use Helpers::ExcelWorkbook;
#use Encode;
#use Helpers::Date;
#use Helpers::WebConnector;
#use File::stat;
#use URI::Encode;


my $data = "<p id=\"C:M:T:title\" role=\"heading\" aria-level=\"2\" class=\"ei_titletext\">Authentification forte</p>
</div> 
</div>
</div>
</div><div class=\"_c1 ei_mainblocfctl _c1\">
<div id=\"C:T2:D\" class=\"bloctxt alerte\">
<b>Pourquoi nous vous demandons de confirmer votre identité ?</b><br/><br/>Dans le cadre de la directive européenne relative aux services de paiement (DSP2), le niveau de sécurité de l'accès à votre Espace Client est renforcé.<br/><br/>Pour accéder à vos comptes, merci de confirmer votre identité depuis votre smartphone ou votre tablette avec <b>Confirmation Mobile</b>. Cette étape est obligatoire au moins une fois tous les 90 jours.  
</div><div id=\"C:F:D\" class=\"ei_fnblock\">
<div id=\"C:F:expContent\" class=\"ei_fnblock_body\">
<div id=\"C:T3:D\" class=\"bloctxt\">
<b>Votre derni&#232;re authentification forte a &#233;t&#233; enregistr&#233;e le mercredi 1 juillet 2020.</b><br /><b>Vous devrez saisir un nouveau code de confirmation au plus tard le mardi 29 septembre 2020.</b>  
</div><div id=\"C:G:D\" class=\"ei_gpblock\">
<div id=\"C:G:expContent\" class=\"ei_gpblock_body\">
<div id=\"C:O:D\" class=\"blocboutons\">
  <span id=\"C:B:S\" class=\"ei_buttonbar\"><span id=\"C:R:RootSpan\" class=\"ei_button\"><a id=\"C:R:link\" aria-labelledby=\"C:R:labelsubmit\" href=\"/fr/banque/validation.aspx?_tabi=C&amp;_pid=AuthChoicePage&amp;_fid=SCA\" class=\"ei_btn ei_btn_fn_forward\"><span id=\"C:R:labelsubmit\" class=\"_c1 ei_btn_body _c1\"><span role=\"presentation\" class=\"_c1 ei_btn_tlcorn _c1\"></span><span class=\"_c1 ei_btn_label _c1\">Confirmer mon identit&#233;</span><span role=\"presentation\" class=\"_c1 ei_iblock ei_btn_pic _c1\">&nbsp;</span></span><span role=\"presentation\" class=\"_c1 ei_btn_footer _c1\"><span role=\"presentation\" class=\"_c1 ei_btn_blcorn _c1\"></span></span></a></span></span>
</div> 
</div>
</div><ul class=\"_c1 niv1 _c1\">
<li>Si vous pr&#233;f&#233;rez confirmer votre identit&#233; plus tard : <a id=\"C:L1\" href=\"/fr/banque/validation.aspx?_tabi=C&amp;_pid=AuthChoicePage&amp;_fid=Bypass\">cliquez ici.</a></li>
</ul>  
</div>
</div>Consultez notre <a id=\"C:L2\" href=\"https://www.creditmutuel.fr/fr/assistance/faq/connexion-comptes.html\" target=\"_blank\">Foire Aux Questions (FAQ).</a> <div id=\"C:O1:D\" class=\"blocboutons\">
  <span id=\"C:B1:S\" class=\"ei_buttonbar\"><span id=\"C:R1:RootSpan\" class=\"ei_button\"><a id=\"C:R1:link\" aria-labelledby=\"C:R1:labelsubmit\" href=\"/fr/banque/validation.aspx?_tabi=C&amp;_pid=AuthChoicePage&amp;_fid=DoCancel\" class=\"ei_btn ei_btn_typ_back\"><span id=\"C:R1:labelsubmit\" class=\"_c1 ei_btn_body _c1\"><span role=\"presentation\" class=\"_c1 ei_btn_tlcorn _c1\"></span><span class=\"_c1 ei_btn_label _c1\">Abandonner</span><span role=\"presentation\" class=\"_c1 ei_iblock ei_btn_pic _c1\">&nbsp;</span></span><span role=\"presentation\" class=\"_c1 ei_btn_footer _c1\"><span role=\"presentation\" class=\"_c1 ei_btn_blcorn _c1\"></span></span></a></span></span>
</div>
</div>
</div> 
</div><input name=\"_wxf2_cc\" type=\"hidden\" value=\"fr-FR\" />
</form><script type=\"text/javascript\">";

if ($data =~ /href="\/fr\/banque\/validation.aspx\?_tabi=C&amp;_pid=AuthChoicePage&amp;_fid=SCA"/m) {
	print "SCA found\n";
}

my $a = "29.6";
my $b = "29.61";
print "Diff: ".(abs($a-$b) > 0.009), "\n";

my $size = stat("README.md")->size;
print "README.md size: $size\n";

my $string = "04/05/2015;-251.58;VIR SEPA WEB VERS ECOSYNDIC CDN;10748.49";
my @data = split (';', $string);
print Dumper @data;
	
my $str = "4.2";
$str =~ s/\d\.(\d)/0.$1/;
print $str,"\n";
 
if (!defined -e "/Users/home/git/My-Banking-Agent/closing.sh") { print "does not exist\n"; }
else {print "does exist\n"; }

#require "auth.pl";
#our %auth;

#print $auth{'MARC.KEY'}[1], "\n";

my $dth = Helpers::Date->new();
my $dtToday = $dth->getDate();
print sprintf ("%02d/%02d", $dtToday->day(), $dtToday->month()), "\n";

$i = 1;
$filePath = './reporting/0603900020712304/11-15_actuals.xls';
$filePath =~ s/\.xls/-$i.xls/;
print $filePath, "\n";

$str = 'DEFAULT-180';
$defautString = '^DEFAULT[\-|\+](\d+)$';
if ($str =~ m/$defautString/) {
	print "limit: $1\n";
}

my @arr = ("a");
print "arr size: ", $#arr, "\n";

sub spaceRemover {
	my ($num) = @_;
	$num =~ s/\s//g;
	print "num: $num\n";
}

my $number="06039 000207123 05";
spaceRemover($number);
print "number: $number\n";
	
print "login: ", Helpers::WebConnector->getLogin ('MARC.KEY'), "\n";
print "password: ", Helpers::WebConnector->getPwd ('MARC.KEY'), "\n";

my $QIFdata="!Type:Bank
D01/02/16
T-425.92
PVF SERVICES CARTE 60414070 PAIEMENT CB 2901 PARIS
^
";
my @records = split ('\^', $QIFdata);
print $#records, "\n";

print "\n-------------------\n";

for my $j (0 .. 6) {
	for my $i (0 .. 9) {
		print $i + $j*10, "\t";
	}
	print "\n";
}

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



    #  Add and define a format
    #$format = $workbook->add_format();
    #$format->set_bold();
    #$format->set_color( 'red' );
    #$format->set_align( 'center' );

    # Write a formatted and unformatted string, row and column notation.
    #$col = $row = 0;
    #$worksheet->write( $row, $col, 'Hi Excel!', $format );
    #$worksheet->write( 1, $col, 'Hi Excel!' );

    # Write a number and a formula using A1 notation
    #$worksheet->write( 'A3', 1.2345 );
    #$worksheet->write( 'A4', '=SIN(PI()/4)' );




# Create a new Excel workbook
my $wb_out = Excel::Writer::XLSX->new( 'copy_categ.xlsx' );

# Add a worksheet
my $ws_out = $wb_out->add_worksheet();


my $filePath = "t/t.categories.xls";
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


my $worksheet = $workbook->worksheet(0);

my ( $row_min, $row_max ) = $worksheet->row_range();
my ( $col_min, $col_max ) = $worksheet->col_range();

for my $row ( $row_min .. $row_max ) {
	for my $col ( $col_min .. $col_max ) {
		my $cell = $worksheet->get_cell( $row, $col );
		next unless $cell;
		my $fx_in = $cell->get_format();
		my $font = Helpers::ExcelWorkbook->fontTranslator($fx_in->{Font});
		my $shading = Helpers::ExcelWorkbook->cellFormatTranslator($fx_in);;
		my $fx_out = $wb_out->add_format( %$font , %$shading);
		$ws_out->write( $row, $col, $cell->unformatted(), $fx_out );
		print "$row/$col: ", $fx_in->{Font}->{Name}, "\n";
	}
}

=cut
