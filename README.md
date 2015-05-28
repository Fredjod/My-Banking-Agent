# My-Banking-Agent (MB@)

<b>A web agent for monitoring your bank accounts balance</b>

The MB@ core engine is written in Perl and the GUI is Excel documents. Thus can work on any OS and give lot of flexibility for generating your own report/graph with Excel features.
The following external CPAN libraries are used by this program. No need to install them separetly on your computer, they are already packaged with the rest of MB@ files.
<ul>
<li>Spreadsheet::ParseExcel v0.65 and Spreadsheet::XLSX v0.13 for reading any Excel format files</li>
<li>Excel::Writer::XLSX v0.84 for writting results in XLSX format</lib>
<li>MIME::Lite v3.01 - low-calorie MIME generator, use for sending email</li>
</ul>

This is not a "yet another bank statement manager". It has only one main objective : alert the account owner by email when something not expected occurs on his bank statement, bad news (more expenses than planed) or good news (more incomes than hoped). 
The core engine automatically downloads your statements from your online bank account. Specific dev is required per bank website. The first bank available will be Credit Mutuel (France), and then should be followed by BNP (France) and then Citibank (USA).
<P>
The security aspect will be addressed, the online bank passwords are never stored in any config file of MB@. The passwords are only stored and read from a 3rd party vault solution (like MacOSX keychains application).
<P>
The project is still under development. Don't hesitate to post your interest in this project for supporting the hard work.
Some specific modules for accessing more bank website will require extra support by interested and motivated developers. Actually, this is needed to have an active online login in order to develop the connection to a specific bank website. Some of them are challenging especially when the password input field is a captcha!

<b>Features</b>
<ul>
<li>Group debit or credit operations per customized categories</li>
<li>Forecasting of the coming month budget, based on the previous month transactions. You can adjust the forecast at will</li>
<li>Automatic download and process the bank statements in a regular basis</li>
<li>If the actual balance at the given day varies from the forecast balance, send an alert to the account owner</li> 
<li>Assess at the beginning of the month the impact of an exceptional expenses on your cash flow</li>
<li>Virtually, this is possible to monitor as many bank accounts as needed, even hosted in several banks</li>
</ul>

<b>Installation - quick start</b>
...
