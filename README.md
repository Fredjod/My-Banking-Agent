# My-Banking-Agent (MB@)

<b>A web agent for monitoring your bank accounts balance</b>

The MB@ core engine is written in Perl and the GUI is Excel documents. Thus can work on any OS and gives lot of flexibility for generating your own report/graph with Excel features.
The following external CPAN libraries are used by this program. No need to install them separetly on your computer, they are already packaged with the rest of MB@ files.
<ul>
<li>Spreadsheet::ParseExcel v0.65 and Spreadsheet::XLSX v0.13 for reading any Excel format files</li>
<li>Spreadsheet::WriteExcel v2.40 and Excel::Writer::XLSX v0.84 for writing reports & dashboards in any Excel format files</lib>
<li>MIME::Lite v3.01 - low-calorie MIME generator, use for sending email</li>
</ul>

<b>Motivations</b><P>
This is not a "yet another bank statement manager" ;) It has only one main objective : alert the account owner by email when something not expected occurs on his bank statement, bad news (more expenses than planed) or good news (more incomes than hoped). The core engine automatically downloads your statements from your online bank account for monitoring the account balance in a regular basis.
<P>
The security aspect is addressed, the online bank passwords are never stored in any configuration file of MB@. The passwords are only stored and read from a 3rd party vault solution (like MacOSX Keychains application).
<P>
The project is still under development. Don't hesitate to post your interest in this project for supporting the hard work.
Some specific modules for accessing more bank websites will require extra support by interested and motivated developers. See lib/WebConnector/ for details. Some of them are challenging especially when the password input field is a captcha, requiring OCR development!

<b>Features</b>
<ul>
<li>Group debit or credit operations per customized categories</li>
<li>Forecasting of the coming month budget, based on the previous month transactions. You can adjust the forecast at will</li>
<li>Automatically connect and download bank statements from bank website. Only Credit Mutuel (France) is currently supported. Should be followed by BNP (France) and then Citibank (USA)</li>
<li>Send an alert to the account owner by email, if the forecast significantly varies from the actuals downloaded from bank website</li> 
<li>This is possible to monitor as many bank accounts as needed, even hosted in several banks</li>
</ul>

<b>Installation - quick start</b>
...
