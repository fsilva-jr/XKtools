My personal tool to manage F&O environments. It was created based on my individual needs, utilizing scripts generated with the assistance of ChatGPT. Every single line in any of the scripts was created using ChatGPT. I've made some adjustments to accommodate my daily work. Always using ChatGPT! Run the "00 - Menu.ps1" file to have access to different options. I believe that the name of the scripts a very clear and gives you a tip about what it executes. I will make changes based on the issues or different needs I find during its execution. Some of the scripts use the D365FO.Tools to run D365F&O administrative tasks like Build, Sync DB, or cleanup tables before restoring a .bacpac file. With more time, I will add a description for each script. I hope it helps me save some time; if it helps you too, that's awesome!
The first step to start using the XKTools is to run the "DownloadXKTools.ps1" command in your PowerShell. The command will download the XKTools.zip file, unpack it to the C:\Temp\XKTools, and eliminate the .zip file! Here is a simple line that you can use in your PowerShell instead of copying the entire file:
iwr -useb https://raw.githubusercontent.com/fsilva-jr/XKtools/main/DownloadXKTools.ps1 | iex 
And here is the final result of it:
Open the XKTools and run the 00 - Menu.ps1 with PowerShell:

I believe that the names of each option indicate their functionalities, but I will try to document each one here. Note that after choosing one option, the color will change, so you know it was executed!

1 - Stop Services:
Stop all the F&O Windows Services. It just doesn´t stop the IISExpress. After completing, press Enter to go back to the main menu!

2 - AZCopy + SQLPackage Download:
The entire "solution" was created thinking about preparing a new F&O VM from Scratch. The script two downloads Azcopy and SQLPackage, unzips them, and saves them to the C:\Temp folder.

3 - Download BacPack from LCS:
Here, you need to have the SAS link from LCS, select the file name, and specify where you want to save it.


4 - Clean BacPac And Remove Tables:
Inside the XKTools folder, there is a RemoveTables.txt file. If you populate the file with the names of the tables you want to remove before starting the restore of the .bacpac file.

The script will ask you where the downloaded .bacpac is to be cleaned up, where the .txt file is, and where you want to save the new. bacpac file.

Even if it does not find the tables, the script finishes. For more details, always go to the log folder!
5 - Rename Database:
It asks you what the name of the database is that you want to rename and what the new name for the database is. If there is no AxDB in the SQL Server, this step is not necessary. If there is an AxDB but a service is running and blocking it from being renamed, the script will prompt you to stop the service until it is possible to rename the database.

6 - Restore Bacpac:
This one restores the bacpac! There are some additional parameters to help accelerate the process. The script will ask you where the .bacpac file is and what the name of the database to be restored is. Useful if you want to restore an AxDB database in parallel with an existing one.

7 - Start Services:
Not too much to explain here!!!

8 - Build Models:
It will compile all the models available:
A screenshot will be added soon.
9 - Sync Database:
The script will ask in which drive letter the AOSSERVICE folder is and then run the sync command:
A screenshot will be added soon.
