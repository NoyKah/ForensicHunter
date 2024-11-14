@echo off
setlocal enabledelayedexpansion
if "%~1"=="" (
    @echo off
	:acquisition_prompt
	set /p "acquisition_choice=Would you like to perform an Acquisition? (Y/N): "

	REM Extract the first character of the input and convert it to uppercase
	set "acquisition_choice=!acquisition_choice:~0,1!"
	call :ToUpper acquisition_choice_upper "!acquisition_choice!"

	if /I "!acquisition_choice_upper!"=="Y" (
		goto :perform_acquisition
	) else if /I "!acquisition_choice_upper!"=="N" (
		goto :get_filepath
	) else (
		echo Invalid choice. Please enter Y or N.
		goto :acquisition_prompt
	)

	:perform_acquisition
	echo Starting Acquisition...
	CyLR.exe -d Cyconfig.txt -q -od Acquisition -of Acquisition.zip

	REM Check if the zip file was created successfully
	if exist Acquisition\Acquisition.zip (
		echo Unzipping Acquisition.zip...
		powershell -command "Expand-Archive -Path 'Acquisition\Acquisition.zip' -DestinationPath 'Acquisition'"
		ren Acquisition\C\$Extend\$UsnJrnl$J $J
		set "filepath=Acquisition\C"
		echo Acquisition completed and unzipped successfully.
		goto :analyze
	) else (
		echo Acquisition.zip not found. Acquisition may have failed.
	)

	REM Ask again if the user wants to perform another acquisition
	goto :acquisition_prompt
)
:get_filepath
set /p "filepath=Please enter the path to the C drive you wish to analyze: "
if not exist "%filepath%" (
    echo Invalid path. Please try again.
    goto :get_filepath
)
echo Path set to %filepath%
goto :analyze

set "filepath=%~1"
:analyze
set "script_dir=%~dp0"
set "artifacts_dir=%script_dir%Artifacts"
set "users_dir="%filepath%"\Users"
echo The provided path is: %filepath%
timeout /t 3 /nobreak >nul
echo Parsing MFT and USNJournal...
MFTECmd.exe -f "%filepath%\$Extend\$J" -m "%filepath%\$MFT" --csv "Artifacts\MFT and USNJournal" >nul 2>>errors.txt
echo Parsing Shimcache...
AppCompatCacheParser.exe -f "%filepath%\Windows\System32\config\SYSTEM" --csv "Artifacts\Shimcache" --csvf "Shimcache.csv" >nul 2>>errors.txt
echo ---------------------------------------
echo [##]10%%
echo ---------------------------------------
echo Parsing Amcache...
AmcacheParser.exe --nl -f "%filepath%\Windows\appcompat\Programs\Amcache.hve" --csv "Artifacts\Amcache" --csvf "Amcache.csv" >nul 2>>errors.txt
echo Parsing Prefetch Files...
PECmd.exe -d "%filepath%\Windows\Prefetch" --csv "Artifacts\Prefetch" --csvf "Prefetch.csv" >nul 2>>errors.txt
echo Parsing SRUMdb...
SrumECmd.exe -f "%filepath%\Windows\System32\SRU\SRUDB.dat" -r "%filepath%\Windows\System32\config\SOFTWARE" --csv "Artifacts\SRUMdb"  >nul 2>>errors.txt
echo ---------------------------------------
echo [####]20%%
echo ---------------------------------------
echo Parsing Search Index...
sidr.exe -f csv -o "Artifacts\Search Index" "%filepath%\ProgramData\Microsoft\Search\Data\Applications\Windows" >nul 2>>errors.txt
echo Collecting Registry Hives...
mkdir "Artifacts\Registry Hives" && copy "%filepath%\Windows\System32\config\*" "Artifacts\Registry Hives" >nul 2>>errors.txt
echo Collecting Event Logs...
mkdir "Artifacts\Event Logs" && copy "%filepath%\Windows\System32\winevt\logs\*" "Artifacts\Event Logs\" >nul 2>>errors.txt
echo ---------------------------------------
echo [######]30%%
echo ---------------------------------------
echo Collecting the Main Temp directory...
mkdir "Artifacts\Main Temp Directory" && copy "%filepath%\Windows\Temp\*" "Artifacts\Main Temp Directory" >nul 2>>errors.txt
echo Parsing Event Logs...
EvtxECmd.exe -d "Artifacts\Event Logs" --csv "Artifacts\Parsed Event Logs" --csvf "Parsed_Logs.csv" >nul 2>>errors.txt
for /d %%u in ("%users_dir%\*") do (
    if /i not "%%u"=="%filepath%\Users\Public" if /i not "%%u"=="%filepath%\Users\Default" (
		set "tempPath=%%u"
        set "username=!tempPath:*Users=\!"
        set "username=!username:\=!"
		echo Parsing !username!'s LNK Files...
        LECmd.exe -d "%%u\AppData\Roaming\Microsoft\Windows\Recent" --csv "Artifacts\LNK Files" --csvf "!username!.csv" >nul 2>>errors.txt	
	)
) 
echo ---------------------------------------
echo [########]40%%
echo ---------------------------------------
for /d %%u in ("%users_dir%\*") do (
    if /i not "%%u"=="%filepath%\Users\Public" if /i not "%%u"=="%filepath%\Users\Default" (
		set "tempPath=%%u"
        set "username=!tempPath:*Users=\!"
        set "username=!username:\=!"
		echo Parsing !username!'s Jumplists - Automatic Destinations...
        JLECmd.exe -d "%%u\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations" --csv "Artifacts\Jumplists" --csvf "Auto_!username!.csv" >nul 2>>errors.txt
	)
)  
for /d %%u in ("%users_dir%\*") do (
    if /i not "%%u"=="%filepath%\Users\Public" if /i not "%%u"=="%filepath%\Users\Default" (
		set "tempPath=%%u"
        set "username=!tempPath:*Users=\!"
        set "username=!username:\=!"
		echo Parsing !username!'s Jumplists - Custom Destinations...
        JLECmd.exe -d "%%u\AppData\Roaming\Microsoft\Windows\Recent\CustomDestinations" --csv "Artifacts\Jumplists" --csvf "Auto_!username!.csv" >nul 2>>errors.txt
	)
)   
for /d %%u in ("%users_dir%\*") do (
    if /i not "%%u"=="%filepath%\Users\Public" if /i not "%%u"=="%filepath%\Users\Default" (
        set "tempPath=%%u"
        set "username=!tempPath:*Users=\!"
        set "username=!username:\=!"
		echo Collecting !username!'s Windows Notification DB...
        mkdir "Artifacts\Windows Notification DB\!username!" && copy "%%u\AppData\Local\Microsoft\Windows\Notifications\wpndatabase.db" "Artifacts\Windows Notification DB\!username!" >nul 2>>errors.txt	
	)
) 
echo ---------------------------------------
echo [##########]50%%
echo ---------------------------------------
for /d %%u in ("%users_dir%\*") do (
    if /i not "%%u"=="%filepath%\Users\Public" if /i not "%%u"=="%filepath%\Users\Default" (
		set "tempPath=%%u"
        set "username=!tempPath:*Users=\!"
        set "username=!username:\=!"
		echo Collecting !username!'s RDP Cache...
		python bmc-tools.py -s "%%u\AppData\Local\Microsoft\Terminal Server Client\Cache" -d "Artifacts\RDP Cache\!username!" -b >nul 2>>errors.txt
	)
) 
for /d %%u in ("%users_dir%\*") do (
    if /i not "%%u"=="%filepath%\Users\Public" if /i not "%%u"=="%filepath%\Users\Default" (
		set "tempPath=%%u"
        set "username=!tempPath:*Users=\!"
        set "username=!username:\=!"
		echo Collecting !username!'s Chrome History...
		mkdir "Artifacts\Chrome History\!username!\" >nul 2>>errors.txt && xcopy "%%u\AppData\Local\Google\Chrome\User Data\Default" "Artifacts\Chrome History\!username!\"  /E /I >nul 2>>errors.txt
	)
)
for /d %%u in ("%users_dir%\*") do (
    if /i not "%%u"=="%filepath%\Users\Public" if /i not "%%u"=="%filepath%\Users\Default" (
		set "tempPath=%%u"
        set "username=!tempPath:*Users=\!"
        set "username=!username:\=!"
		echo Collecting !username!'s Firefox History...
		mkdir "Artifacts\Firefox History\!username!\" >nul 2>>errors.txt&& xcopy "%%u\AppData\Roaming\Mozilla\Firefox\Profiles" "Artifacts\Firefox History\!username!\"  /E /I >nul 2>>errors.txt
	)
)  
echo ---------------------------------------
echo [############]60%%
echo ---------------------------------------
for /d %%u in ("%users_dir%\*") do (
    if /i not "%%u"=="%filepath%\Users\Public" if /i not "%%u"=="%filepath%\Users\Default" (
		set "tempPath=%%u"
        set "username=!tempPath:*Users=\!"
        set "username=!username:\=!"
		echo Collecting !username!'s Edge History...
		mkdir "Artifacts\Edge History\!username!\" >nul 2>>errors.txt&& xcopy "%%u\AppData\Local\Microsoft\Edge\User Data\Default" "Artifacts\Edge History\!username!\"  /E /I >nul 2>>errors.txt
	)
) 
for /d %%u in ("%users_dir%\*") do (
    if /i not "%%u"=="%filepath%\Users\Public" if /i not "%%u"=="%filepath%\Users\Default" (
		set "tempPath=%%u"
        set "username=!tempPath:*Users=\!"
        set "username=!username:\=!"
		echo Collecting !username!'s Opera History...
		mkdir "Artifacts\Opera History\!username!\" >nul 2>>errors.txt && xcopy "%%u\AppData\Roaming\Opera Software\Opera Stable" "Artifacts\Opera History\!username!\"  /E /I >nul 2>>errors.txt
	)
) 
for /d %%u in ("%users_dir%\*") do (
    if /i not "%%u"=="%filepath%\Users\Public" if /i not "%%u"=="%filepath%\Users\Default" (
	    set "tempPath=%%u"
        set "username=!tempPath:*Users=\!"
        set "username=!username:\=!"
		echo Collecting !username!'s Registry Hives - USRclass.dat...
		mkdir "Artifacts\Users Registry Hives\!username!" >nul 2>>errors.txt && copy "%%u\AppData\Local\Microsoft\Windows\usrclass.dat*" "Artifacts\Users Registry Hives\!username!" >nul 2>>errors.txt
	)
)
echo ---------------------------------------
echo [##############]70%%
echo ---------------------------------------
for /d %%u in ("%users_dir%\*") do (
    if /i not "%%u"=="%filepath%\Users\Public" if /i not "%%u"=="%filepath%\Users\Default" (
		set "tempPath=%%u"
        set "username=!tempPath:*Users=\!"
        set "username=!username:\=!"
		echo Collecting !username!'s Registry Hives - NTuser.dat...
		copy "%%u\ntuser.dat*" "Artifacts\Users Registry Hives\!username!" >nul 2>>errors.txt
	)
)
for /d %%u in ("%users_dir%\*") do (
    if /i not "%%u"=="%filepath%\Users\Public" if /i not "%%u"=="%filepath%\Users\Default" (
		set "tempPath=%%u"
        set "username=!tempPath:*Users=\!"
        set "username=!username:\=!"
		echo Collecting !username!'s Outlook OST...
		mkdir "Artifacts\Outlook\!username! Outlook OST" && copy "%%u\AppData\Local\Microsoft\Outlook\*.ost" "Artifacts\Outlook\!username! Outlook OST" >nul 2>>errors.txt
	)
)  
for /d %%u in ("%users_dir%\*") do (
    if /i not "%%u"=="%filepath%\Users\Public" if /i not "%%u"=="%filepath%\Users\Default" (
		set "tempPath=%%u"
        set "username=!tempPath:*Users=\!"
        set "username=!username:\=!"
		echo Collecting !username!'s Outlook PST...
		mkdir "Artifacts\Outlook\!username! Outlook PST" && copy "%%u\Documents\Outlook Files\*.pst" "Artifacts\Outlook\!username! Outlook PST" >nul 2>>errors.txt
	)
) 
echo ---------------------------------------
echo [################]80%%
echo --------------------------------------- 
for /d %%u in ("%filepath%\$Recycle.Bin\*") do (
	set "tempPath=%%u"
    set "sid=!tempPath:*$Recycle.Bin=\!"
    set "sid=!sid:\=!"
	echo Collecting !sid!'s Recycle Bin Artifact...
    RBCmd.exe -d "%filepath%\$Recycle.Bin\!sid!" --csv "Artifacts\RecycleBin" --csvf "!sid!.csv" >nul 2>>errors.txt
	mkdir "Artifacts\RecycleBin\Bin Content" >nul 2>>errors.txt&& xcopy "%filepath%\$Recycle.Bin\!sid!" "Artifacts\RecycleBin\Bin Content" /E /I >nul 2>>errors.txt
	
) 
for /d %%u in ("%users_dir%\*") do (
    if /i not "%%u"=="%filepath%\Users\Public" if /i not "%%u"=="%filepath%\Users\Default" (
		set "tempPath=%%u"
        set "username=!tempPath:*Users=\!"
        set "username=!username:\=!"
		echo Collecting !username!'s Filezilla Logs...
		mkdir "Artifacts\Filezilla\!username! logs" >nul 2>>errors.txt && xcopy "%%u\AppData\Local\FileZilla\logs" "Artifacts\Filezilla\!username! logs" /E /I >nul 2>>errors.txt
	)
) 
for /d %%u in ("%users_dir%\*") do (
    if /i not "%%u"=="%filepath%\Users\Public" if /i not "%%u"=="%filepath%\Users\Default" (
		set "tempPath=%%u"
        set "username=!tempPath:*Users=\!"
        set "username=!username:\=!"
		echo Collecting !username!'s Startup Directory...
		mkdir "Artifacts\Startup Directory\!username!\" >nul 2>>errors.txt && copy "%%u\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\*" "Artifacts\Startup Directory\!username!\" >nul 2>>errors.txt
	)
)
echo ---------------------------------------
echo [##################]90%%
echo ---------------------------------------
for /d %%u in ("%users_dir%\*") do (
    if /i not "%%u"=="%filepath%\Users\Public" if /i not "%%u"=="%filepath%\Users\Default" (
		set "tempPath=%%u"
        set "username=!tempPath:*Users=\!"
        set "username=!username:\=!"
		echo Collecting !username!'s Downloads Directory...
		mkdir "Artifacts\Downloads Directory\!username!\" >nul 2>>errors.txt && xcopy "%%u\Downloads\*" "Artifacts\Downloads Directory\!username!\" /E /I >nul 2>>errors.txt
	)
)
for /d %%u in ("%users_dir%\*") do (
    if /i not "%%u"=="%filepath%\Users\Public" if /i not "%%u"=="%filepath%\Users\Default" (
		set "tempPath=%%u"
        set "username=!tempPath:*Users=\!"
        set "username=!username:\=!"
		echo Collecting !username!'s Temp Directory...
		mkdir "Artifacts\User's Temp Directory\!username!\" >nul 2>>errors.txt && xcopy "%%u\AppData\Local\Temp" "Artifacts\User's Temp Directory\!username!\" /E /I >nul 2>>errors.txt
	)
) 
for /d %%u in ("%users_dir%\*") do (
    if /i not "%%u"=="%filepath%\Users\Public" if /i not "%%u"=="%filepath%\Users\Default" (
		set "tempPath=%%u"
        set "username=!tempPath:*Users=\!"
        set "username=!username:\=!"
		echo Collecting !username!'s PowerShell History - PSReadLine...
		mkdir "Artifacts\PSReadLine\!username!\" >nul 2>>errors.txt && xcopy "%%u\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\" "Artifacts\PSReadLine\!username!\" /E /I >nul 2>>errors.txt
	)
) 
for /d %%u in ("%users_dir%\*") do (
    if /i not "%%u"=="%filepath%\Users\Public" if /i not "%%u"=="%filepath%\Users\Default" (
		set "tempPath=%%u"
        set "username=!tempPath:*Users=\!"
        set "username=!username:\=!"
		echo Collecting !username!'s Shellbags...
        SBECmd.exe -d "Artifacts\Users Registry Hives\!username!" >nul 2>>errors.txt --csv "Artifacts\Shellbags" --csvf "!username!.csv" >nul 2>>errors.txt
	)
) 
echo Running Hayabusa...
hayabusa-2.18.0-win-aarch64.exe csv-timeline -d "Artifacts\Event Logs" -a -A -Q -N -w -o "Artifacts\Detection-Hayabusa.csv"
echo ---------------------------------------
echo [####################]100%%
echo ---------------------------------------


	echo ---------------------------------------
	echo Collected Artifacts:

REM Iterate through each subdirectory in Artifacts
for /d %%D in ("%artifacts_dir%\*") do (
    REM Initialize size_bytes for the current subdirectory
    set "size_bytes=0"
    
    REM Use dir to get the total size of files in the subdirectory, suppressing "File Not Found" message
    for /f "tokens=3" %%S in ('dir /s /a:-d "%%D" 2^>nul ^| find "File(s)"') do (
        set "size_bytes=%%S"
    )
    
    REM Remove commas from the size (e.g., "1,234" to "1234")
    set "size_bytes=!size_bytes:,=!"
    
    REM Check if the size is greater than 0
    if "!size_bytes!" GTR "0" (
        echo Directory: %%~nD - Size: !size_bytes! - Collected Successfully
        echo ---------------------------------------
    )
)

echo.
echo ====================================================================================



@echo off
REM Loop for repeated IOC searches
:search_prompt
set /p "search_choice=Would you like to search for a specific IOC? (Y/N): "

REM Extract the first character of the input and convert it to uppercase
set "search_choice=!search_choice:~0,1!"
call :ToUpper search_choice_upper "!search_choice!"

if /I "!search_choice_upper!"=="Y" (
    goto :get_search_term
) else if /I "!search_choice_upper!"=="N" (
    goto :end
) else (
    echo Invalid choice. Please enter Y or N.
    goto :search_prompt
)

:get_search_term
set /p "search_term=Enter the search word: "
if "%search_term%"=="" (
    echo No search term entered. Exiting search.
    goto :search_prompt
)

echo.
echo ==========================================
echo Searching for directories containing "%search_term%"
echo ==========================================
echo.
pip install pandas >nul 2>>errors.txt
python Find.py %search_term% Artifacts -o Artifacts\%search_term%_Search_Results.csv --add-source
echo Done

REM Ask again if the user wants to search for another IOC
goto :search_prompt

:end
echo Script execution completed.
goto :eof

REM Function to convert a single character to uppercase
:ToUpper
set "%1=%~2"
if "%~2" geq "a" if "%~2" leq "z" (
    set /a "offset=65 - 97"
    for /f %%i in ('"cmd /c exit /b %~2"') do set /a "%1=%%i + offset"
    cmd /c exit /b %1 >nul
)
goto :eof


