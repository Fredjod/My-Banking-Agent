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
<li>Send an alert to the account owner by email, if the forecast significantly varies from the actuals downloaded from bank website</li> 
<li>This is possible to monitor as many bank accounts as needed, even hosted in several banks</li>
<li> Keep monthly and yearly history of your transactions
<li> Manage the saving accounts
</ul>

<b>Architecture</b>
<P>
The architecture is quite simple. The components are the following:
1) A main batch, wrote in Perl. Works without database. This batch contains all the business logics and procedures of MBA. It generates Excel files (bank statements reports). The batch parameters are read in Excel files.
2) Crontab. A crontab that manages the occurences of the MBA executions. By experience, the bank statements are not updated quite ofen. One or 2 daily execution is enought. However, the batch can be run as ofen as desired.
3) Owncloud server. It's used to transfer Excel files between the end user and the server that hosts the MBA batch. Thru Owncloud directories (replicated localy on his computer), the user can update Excel files that make the configuration of MBA and also read the Excel files generated by the batch.
