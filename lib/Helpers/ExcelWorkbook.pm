package Helpers::ExcelWorkbook;

use lib "../../lib/";

use warnings;
use MIME::Base64;
use DateTime;
use Spreadsheet::ParseExcel;
use Spreadsheet::XLSX;
use Spreadsheet::ParseExcel;
use Excel::Writer::XLSX;
use File::Basename;

sub new
{
    my ($class) = @_;
    bless $self, $class;
    return $self;
}

sub openExcelWorkbook {
	my ($class, $filePath) = @_;
	
	unless (-e $filePath) { die "File ".$filePath." can't be found"; }
	my($filename, $dirs, $ext) = fileparse($filePath, qr/\.[^.]*/);
	unless ($ext eq '.xls' or $ext eq '.xlsx') { die "File extension ".$ext." is not supported (only .xls or .xlsx are)"; }
	
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
1;