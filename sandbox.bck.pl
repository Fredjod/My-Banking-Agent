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

=pod
my $data = "<td><span id=\"accountListController:S\" style=\"margin-left:5px;\"><a id=\"accountListController:chk\" href=\"#\">Tout cocher</a>&nbsp;|&nbsp;<a id=\"accountListController:uchk\" href=\"#\">Tout d&#233;cocher</a></span></td>
</tr><tr>
<td><table id=\"account-table\" width=\"100%\" cellspacing=\"1\" summary=\"\" class=\"liste\">
<tbody>
<tr>
<td id=\"F_0.T2\" class=\"i\" style=\"width:50px;text-align:center;\"><span id=\"F_0.accountCheckbox:span\"><input name=\"Bool:data_accounts_account_ischecked\" id=\"F_0.accountCheckbox:DataEntry:cbhf\" type=\"hidden\" value=\"false\" /><input id=\"F_0.accountCheckbox:DataEntry\" name=\"CB:data_accounts_account_ischecked\" type=\"checkbox\" class=\"checkbox\" /></span></td><td class=\"i\"><label for=\"F_0.accountCheckbox:DataEntry\" id=\"F_0.L21\" class=\"__e_Label\">06039 000207123 02 COMPTE COURANT MLE V LAMBLET OU M F JAUDIN</label></td>
</tr><tr>
<td id=\"F_1.T2\" class=\"p\" style=\"width:50px;text-align:center;\"><span id=\"F_1.accountCheckbox:span\"><input name=\"Bool:data_accounts_account_2__ischecked\" id=\"F_1.accountCheckbox:DataEntry:cbhf\" type=\"hidden\" value=\"false\" /><input id=\"F_1.accountCheckbox:DataEntry\" name=\"CB:data_accounts_account_2__ischecked\" type=\"checkbox\" class=\"checkbox\" /></span></td><td class=\"p\"><label for=\"F_1.accountCheckbox:DataEntry\" id=\"F_1.L21\" class=\"__e_Label\">06039 000207123 04 COMPTE COURANT M JAUDIN FREDERIC</label></td>
</tr><tr>
<td id=\"F_2.T2\" class=\"i\" style=\"width:50px;text-align:center;\"><span id=\"F_2.accountCheckbox:span\"><input name=\"Bool:data_accounts_account_3__ischecked\" id=\"F_2.accountCheckbox:DataEntry:cbhf\" type=\"hidden\" value=\"false\" /><input id=\"F_2.accountCheckbox:DataEntry\" name=\"CB:data_accounts_account_3__ischecked\" type=\"checkbox\" class=\"checkbox\" /></span></td><td class=\"i\"><label for=\"F_2.accountCheckbox:DataEntry\" id=\"F_2.L21\" class=\"__e_Label\">06039 000207123 05 LIVRET DE DEVELOPPEMENT DURABLE SOLIDAIRE TRIPLEX M FREDERIC JAUDIN</label></td>
</tr><tr>
<td id=\"F_3.T2\" class=\"p\" style=\"width:50px;text-align:center;\"><span id=\"F_3.accountCheckbox:span\"><input name=\"Bool:data_accounts_account_4__ischecked\" id=\"F_3.accountCheckbox:DataEntry:cbhf\" type=\"hidden\" value=\"false\" /><input id=\"F_3.accountCheckbox:DataEntry\" name=\"CB:data_accounts_account_4__ischecked\" type=\"checkbox\" class=\"checkbox\" /></span></td><td class=\"p\"><label for=\"F_3.accountCheckbox:DataEntry\" id=\"F_3.L21\" class=\"__e_Label\">06039 000207123 06 PLAN D'EPARGNE LOGEMENT M FREDERIC JAUDIN</label></td>
</tr><tr>
<td id=\"F_4.T2\" class=\"i\" style=\"width:50px;text-align:center;\"><span id=\"F_4.accountCheckbox:span\"><input name=\"Bool:data_accounts_account_5__ischecked\" id=\"F_4.accountCheckbox:DataEntry:cbhf\" type=\"hidden\" value=\"false\" /><input id=\"F_4.accountCheckbox:DataEntry\" name=\"CB:data_accounts_account_5__ischecked\" type=\"checkbox\" class=\"checkbox\" /></span></td><td class=\"i\"><label for=\"F_4.accountCheckbox:DataEntry\" id=\"F_4.L21\" class=\"__e_Label\">06039 000207123 07 COMPTE EPARGNE LOGEMENT M FREDERIC JAUDIN</label></td>
</tr><tr>
<td id=\"F_5.T2\" class=\"p\" style=\"width:50px;text-align:center;\"><span id=\"F_5.accountCheckbox:span\"><input name=\"Bool:data_accounts_account_6__ischecked\" id=\"F_5.accountCheckbox:DataEntry:cbhf\" type=\"hidden\" value=\"false\" /><input id=\"F_5.accountCheckbox:DataEntry\" name=\"CB:data_accounts_account_6__ischecked\" type=\"checkbox\" class=\"checkbox\" /></span></td><td class=\"p\"><label for=\"F_5.accountCheckbox:DataEntry\" id=\"F_5.L21\" class=\"__e_Label\">06039 000207123 08 LIVRET BLEU M FREDERIC JAUDIN</label></td>
</tr><tr>
<td id=\"F_6.T2\" class=\"i\" style=\"width:50px;text-align:center;\"><span id=\"F_6.accountCheckbox:span\"><input name=\"Bool:data_accounts_account_7__ischecked\" id=\"F_6.accountCheckbox:DataEntry:cbhf\" type=\"hidden\" value=\"false\" /><input id=\"F_6.accountCheckbox:DataEntry\" name=\"CB:data_accounts_account_7__ischecked\" type=\"checkbox\" class=\"checkbox\" /></span></td><td class=\"i\"><label for=\"F_6.accountCheckbox:DataEntry\" id=\"F_6.L21\" class=\"__e_Label\">06039 000217275 02 LIVRET BLEU M VICTOR JAUDIN</label></td>
</tr><tr>
<td id=\"F_7.T2\" class=\"p\" style=\"width:50px;text-align:center;\"><span id=\"F_7.accountCheckbox:span\"><input name=\"Bool:data_accounts_account_8__ischecked\" id=\"F_7.accountCheckbox:DataEntry:cbhf\" type=\"hidden\" value=\"false\" /><input id=\"F_7.accountCheckbox:DataEntry\" name=\"CB:data_accounts_account_8__ischecked\" type=\"checkbox\" class=\"checkbox\" /></span></td><td class=\"p\"><label for=\"F_7.accountCheckbox:DataEntry\" id=\"F_7.L21\" class=\"__e_Label\">06039 000217277 02 LIVRET BLEU MLE CHLOE JAUDIN</label></td>
</tr>
</tbody>
</table><script type=\"text/javascript\">
/** * Méthode de création de cookie **/ function createCookie(name, value) { var date = new Date(); date.setTime(date.getTime() + (3600 * 1000 * 24 * 365)); var expires = \"; expires=\" + date.toGMTString(); document.cookie = name + \"=\" + value + expires + \"; path=/\"; } /** * Méthode pour modifier un seul caractère d'une chaîne javascript **/ function setCharAt(str,index,chr) { if(index > str.length-1) return str; return str.substr(0,index) + chr + str.substr(index+1); }";

my $accountNumber="06039 000207123 05";

if ($data =~ /CB:data_accounts_account_(.*)ischecked.+$accountNumber/m) {
	print "found: "."CB%3Adata_accounts_account_$1ischecked=on\n";
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

#my $dth = Helpers::Date->new();
#my $dtToday = $dth->getDate();
#print sprintf ("%02d/%02d", $dtToday->day(), $dtToday->month()), "\n";

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
	
#print "login: ", Helpers::WebConnector->getLogin ('MARC.KEY'), "\n";
#print "password: ", Helpers::WebConnector->getPwd ('MARC.KEY'), "\n";

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
=cut
sub parseCookies {
	my ($rawCookies) = @_;
	my %result;
	my @allcookies = split(/, /, $rawCookies);
	for my $cookie (@allcookies) {
		#print "cookie: $cookie\n";
		my @cookieItems = split(/; /, $cookie);
		for my $item (@cookieItems) {
			#print "item: $item\n";
			my @keypair = split(/=/, $item);
			if (defined $keypair[1] 
				&& $keypair[0] ne "expires"
				&& $keypair[0] ne "Max-Age" 
				&& $keypair[0] ne "Path"
				&& $keypair[0] ne "Secure"
				&& $keypair[0] ne "SameSite"
				&& $keypair[0] ne "HttpOnly"
			) {
				print "$keypair[0]: $keypair[1]\n";
				$result{$keypair[0]} = $keypair[1];
			}
		}
	}
	return %result;
}

my %cookies;
my $cookie3 = "initially_requested_url=/fr/banque/pageaccueil.html; HttpOnly; Max-Age=120; Path=/; Secure, IdSes=5719186e81619cd716080813d91ecd60276560f9959de31bcfb2c9f16f78f368ca588d8fb9b21056212d7b4b0a9f90e4c35db41ba54c8917b7b0863abd549f00d4281ba2c3f8e269014f900e502f49efd4e0f97bee03e4ee8ecb3e0a2433efe26ae96f451e3a58a932f9f66a6dd71c7941a001d02ec51fb54e20b466de0fd1b46644b886a6b588b84a00cb749f24c28edec08ecbf1714e5d36c3a601637e910d0967573d5b8c9a45add329447d6840266f941edfe6936ec7b48444431e2e2316c9050863cd6efdf8790d542532ec135677918cf8e4d3f75b17f362ffc8a975f705f2ce10f4c37cf6a27a1aff2234cfc5bba64b6533c9b0d5f902c40e7997eced3d4245ce8d272742d0e05de294abd963e0cfa2ce3b5cb9ab520d56cd3cc67193e9fe27146f5948408385411ac1825c9a80d216617125cf8966a9cfa2531d2d9a225c99316acdae65681648aa0bb34d74e4cb210f4010a42212f594ffc6035aa8e1e8ea4dea0485e44093cb155cd9f4d679e4262c404cb90fce1ff8b14cbe22b01b6b361f22aa32c09f07acd128aed45665afb3078536fe1deb77eea6ae3c2a8cc9040b68b534ed0dd128289d227629f998ba29584d91b7e6703f27ff7ac7df0c17ecb89db788852532b821d68cc3230e3021071841df2b94319d8b0ca27e20a3370b460a8cc84e294a14b6a615eed48192373adf18337240a0df96e61f4c2b1b111882ac5a4ecb1d220edafbb9df092330aa287bb3300f4a4a7512d417221c996a64dc960b87f64081c73b2e70157e6f; HttpOnly; Path=/; SameSite=lax; Secure, SessionStart=1766367384; Path=/; Secure, SessionTimeout=5; Path=/; Secure";
my $cookie2 = "SessionStart=; expires=Fri, 01 Jan 1971 01:00:00 GMT; Max-Age=0; Path=/; Secure, SessionTimeout=; expires=Fri, 01 Jan 1971 01:00:00 GMT; Max-Age=0; Path=/; Secure";
my $cookie1 = "nid=259DC49A08B193DB470BF9FD61957C1397C1FBFE; HttpOnly; Max-Age=31536000; Path=/; Secure, SessionStart=; expires=Fri, 01 Jan 1971 01:00:00 GMT; Max-Age=0; Path=/; Secure, SessionTimeout=; expires=Fri, 01 Jan 1971 01:00:00 GMT; Max-Age=0; Path=/; Secure";
my $cookie4 = "nid=83A07EB7A3D44D1DB4718D75089BC106CA39D98F; HttpOnly; Max-Age=31536000; Path=/; Secure, SessionStart=; expires=Fri, 01 Jan 1971 01:00:00 GMT; Max-Age=0; Path=/; Secure, SessionTimeout=; expires=Fri, 01 Jan 1971 01:00:00 GMT; Max-Age=0; Path=/; Secure";

%cookies =(%cookies, parseCookies($cookie1));
%cookies =(%cookies, parseCookies($cookie2));
%cookies =(%cookies, parseCookies($cookie3));
%cookies =(%cookies, parseCookies($cookie4));

print Dumper \%cookies;

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
