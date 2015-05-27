package Helpers::ExcelWorkbook;

use lib "../../lib/";

use warnings;
use MIME::Base64;
use DateTime;
use Spreadsheet::ParseExcel;
use Spreadsheet::XLSX;
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
1;