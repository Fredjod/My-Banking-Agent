# My-Banking-Agent (MB@)

<b>A web agent for monitoring your bank accounts balance</b>

The MB@ core engine is written in Perl and the GUI is Excel documents (OpenOffice compliant) generated by the Perl scripts. The aim is to combine the power of Perl in data transformation and the handy and flexible possibilities for displaying the transformed data in Excel document.

<b>Motivations</b><P>
This is not a "yet another bank statement manager" ;) It has only one main objective : alert the account owner by email when something not expected occurs on his bank statement, bad news (more expenses than planed) or good news (more incomes than hoped). The core engine automatically downloads your statements from your online bank account for monitoring the account balance in a regular basis.
<P>
Don't hesitate to post your interest in this project for supporting the hard work.
Some specific modules for accessing more bank websites will require extra support by interested and motivated developers. See lib/WebConnector/ for details. Some of them are challenging especially when the password input field is a captcha, requiring OCR development!

<b>Features</b>
<ul>
<li>Group debit or credit operations per customized categories</li>
<li>Forecasting of the coming month budget, based on the previous month transactions. You can adjust the forecast at will</li>
<li>Automatically connect and download bank statements from bank website. Only Credit Mutuel (France) is currently supported. Should be followed by BNP (France) and then Citibank (USA)</li>
<li>Send an alert to the account owner by email in case of an current overdraft or an anticipated overdraft based on the monthly forecast</li> 
<li>It is possible to monitor as many bank accounts as needed, even hosted in several banks</li>
<li> Keep monthly and yearly history of your transactions
<li> Specific management of the saving accounts (PEL, CEL, Livret, etc...)
</ul>

<b>Architecture</b>
<P>
The architecture is quite simple. The components are the following:<P>
1) A main batch, wrote in Perl. Works without database. This batch contains all the business logics and procedures of MBA. It connects and downloads OFX/QIF files from the bank websites and generates reports in Excel format. The MBA configuration is read in Excel files (lists of bank accounts, account numbers, transaction categories, etc...).<P>
2) Crontab. A cron manages the occurences of the MBA executions. By experience, the statements are not updated quite ofen by banks. One or 2 daily executions are enought. However, the batch can be run as ofen as desired.<P>
3) Owncloud server. It's used to transfer Excel files between the end user and the server that hosts the MBA batch. Thru Owncloud directories (replicated localy on his computer), the user can update Excel files that make the configuration of MBA and read the Excel files generated by the batch.<P>
4) The User Interface: Open Office. There is no macro. Open Office is only used for writing (configuration files) and reading / manipulating reports generated by MBA. 

<b>Installation and execution</b>
<P>
Refer to "HOWTO-INSTALL" readme file for details.