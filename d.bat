@echo off
:: ====================================
:: Author: Agent X
:: Description: Media Recovery Script
:: Version: 1.0 
:: Revision: 2024-01-12
:: Only tested on Windows11
:: ====================================
cls
setlocal enabledelayedexpansion

:: Set # formats
set /a MAX_FORMAT_COUNT=20
:: Set # times to scan a disk and check for errors once it is formatted. 
set /a MAX_FINAL_SCAN_COUNT=2
:: Set # consecutive formats are needed to complete with no bad sectors after whichdtimes to scan a disk and check for errors once it is formatted. 
set /a MINIUM_ZERO_DEFECT_FORMAT_COUNT=2
:: Set max # times to test a disk with bad sectors after formatting. 
set /a MAX_STABILITY_CHECKS=10
:: Set # times to try and format (if there are errors on the disk), if enabled Smart Format 
:: will double this for disks with bad sectors
set /a maxf=20
:: Set # of times to scan the disk and relocate sectors (when there are no bad sectors reported).
:: This is important as it catches areas of the disk that are unreliable as sectors can work for 
:: a few seconds to pass formatting, but loose their stored magenetic signal after a few minutes.
:: This approach formats then disk including an erase cycle and random data fills with checksums
:: followed by many independent reads 2-4 minutes later. You will see the error count increase
:: as marginal sectors are moved out of use. This creates a more robust, reliable recovered disk
:: with slightly less storage space.
set /a ScanCount=2
:: Variables used 
set /a badSectorBytes=0
set /a badSectorBytesPrevious=0
set /a badSectorsFound=-1
set BAR_LINE=_______________________________________
set /a chkCount=1
set /a count=0
set /a failedFormatCount=0
set /a formatted=0
set /a formattedAlready=0
set /a goodFormatCount=0
set /a hardErrorsStable=0
set /a index=0
set /a lastFormatFailed=0
set /a line=0
set /a maxLength=0
set /a minimumGoodFormatCount=2
set /a someDefectFormatCount=0
set /a stable=0
set /a wobble=0
set /a zeroDefectFormatCount=0


call :ShowLogo
:: ====================================
:: Main Code Block
:: Check if the disk has data 
:: Only format when do data is present
:: Run formatting then scan the disk
:: ====================================
:: Get Script Start Time Using jTimestamp.cmd
CALL jTimestamp -f {ums} -r t1
:: Show time 
call :showdatetime
:: Halt if files found on A: also record if disk is formatted


:: debug remove
::call :BadSectorReport "test " !count!
::call :GraphArray
::goto :eof

set "drive=A:"
dir /b "%drive%\"
if %errorlevel% equ 1 (
    echo No files found on %drive%
) 
if %errorlevel% equ 0  (
    echo Files found on %drive% filefound variable = %fileFound%
	echo Stopping, directory.. 
	DIR A:
	exit /b
)

:: maxf is modified if SMART_FORMAT is enable (the default)
:: In such cases to save time if we get 2 consecuetive
:: Disk formats without error then further formatting does
:: not take place. This is done by setting the loop
:: control variable maxf to stop futher formats
set /A maxf=MAX_FORMAT_COUNT
:TryFormattingAgain
:: Are we done?
if !count! geq !maxf! (
    echo Made !maxf! attempts. Exit after checking for bad sectors..
	if %lastFormatFailed% equ 1 (
		echo Last format did not work exit
		echo Disk may be unusable wipe with magnet or electromagnet and retrying
		echo Inspect the disks for errors to see if there is phyical damage
		echo Check drive and disk are connected. Try formatting disk manually to check setup.
		call :DiskSummary
		echo Stopping, disk is not formatted.
		call :sad
		exit /b 0
	)
	:: Last format worked
	call :DiskPostFormatCheck
	call :DiskSummary
	call :GraphArray
	echo Stopping Disk is formatted
	exit /b 0
)
:: Not done
call :SFormat
call :BadSectorReport "Format " !count!
if !hardErrorsStable! equ 1 (
	set /a maxf=!count!
	echo Had 2 formats with same number of bad sectors
)
if !zerodefectformatcount! geq 2 (
	set /a maxf=MINIUM_ZERO_DEFECT_FORMAT_COUNT
	echo Hit Limit for good formats  
	echo !zerodefectformatcount! Zero defect formats, stopping formatting early.
)
goto :TryFormattingAgain
echo Stopping..
exit /b

:: ====================================
:: Library Block
:: Functions used by the main code
:: Format, GetBadSector, Scan Fix  
:: Show Stats, etc
:: ====================================
:DiskPostFormatCheck
:: Last format was bad so no need to scan for bad sectors one last time
if %lastFormatFailed% equ 0 (
	call :finaldiskcheck
)
echo.
echo %BAR_LINE%
echo End of Disk Format / Check Run Report
if !chkcount! equ %scancount% Echo Completed !chkcount! Surface Scans
if !badSectorsFound! equ 0 Echo Formatted, no bad sectors
if !badSectorsFound! equ 1 (
	Echo Formatted, but bad sectors present marked as bad and will not be used
	Echo %wobble% disk fixes applied by Checkdisk after formatting with bad sectors
	Echo %stable% sucessful sucessive checkdisk runs with no fixes applied
)
:: Play a sound to show we are done
call :completed
:: Show the elapsed time
call :updatetime
:: Exit processing end of batchfile
exit /b

:FinalDiskCheck
set /a finalcheck=0
set /a finalscancount=0
set /a finalcheckgoodcount=0
set /a finalwobble=0

:ReCheckDisk
set /a finalcheck=finalcheck+1
call :progress !finalcheck!  !scancount! "Scan"
echo Running Post Format Check on Disk as bad sectors can appear even after formatting
echo This will run Checkdisk /R / X and unlock to test disk...
echo Running post format checks on on disk to test each sector of the disk
echo This will flag bad sectors so they will not to be used
chkdsk a: /R /X
:: Zero is no error
if %errorlevel% equ 0 (
	set /a finalcheckgoodcount+=1
)
:: Errors were found and fixed
if %errorlevel% equ 1 (
	set /a finalwobble+=1
	set /a finalcheckgoodcount=0
)
echo.
echo Final check count is !finalcheck! and limit is set to !MAX_FINAL_SCAN_COUNT!
call :BadSectorReport "Scan " !finalcheck!
if 	!finalcheck! equ !MAX_FINAL_SCAN_COUNT! (
	echo.
	echo Done with final Checks
	echo Correction count was !finalwobble! with !finalcheck! final checks run 
	echo !finalcheckgoodcount! successful scans
	call :GraphArray
	exit /b
)
goto :ReCheckDisk
exit /b 0

:completed
start soft-piano-logo-141290.mp3 > nul
timeout 3 > nul
start taskkill /im WMPlayer.exe > nul
exit /b

:sad
start wibble-92687.mp3
timeout 3 > nul
start taskkill /im WMPlayer.exe > nul
exit /b

:progress
setlocal
set /a progress=%~1*20/%~2
echo.
echo %~3: %~1 of %~2
:: Display progress bar
for /l %%i in (1, 1, %progress%) do echo|set /p=#
for /l %%i in (%progress%, 1, 20) do echo|set /p=.
echo.
call :AddToArray badSectorBytes %~3:%~1
call :updatetime
endlocal
exit /b

:updatetime
:: Get Script End Time Using jTimestamp.cmd
CALL jTimestamp -f {ums} -r t2
:: Fancy Time Stamp
for /F "tokens=*" %%a in (
   'jTimestamp -d %t2% /F " {WKD} {MTH} {D}, {yyyy} {H12}:{NN}:{SS}{PM}"'
) do (
   
   set Timestamp=%%a   
)
set "Timestamp=%Timestamp::00am=am%"
set "Timestamp=%Timestamp::00pm=pm%"
:: echo %Timestamp%
:: Get Script End Time Using jTimestamp.cmd
CALL jTimestamp -d %t2%-%t1% -f "{ud} Days {h} Hours {n} Minutes And {s} Seconds" -u
exit /b

:showdatetime
CALL jTimestamp -f {ums} -r t2
:: Fancy Time Stamp
for /F "tokens=*" %%a in (
   'jTimestamp -d %t2% /F " {WKD} {MTH} {D}, {yyyy} {H12}:{NN}:{SS}{PM}"'
) do (
   
   set Timestamp=%%a   
)
set "Timestamp=%Timestamp::00am=am%"
set "Timestamp=%Timestamp::00pm=pm%"
echo %Timestamp%
exit /b

:DiskSummary
:: Check disk A: for bad sectors and capture the bad sector count
:: The echo Y is needed as sometime checkdisk ask if you want to convery chains to files
:: The is a rare edge condition, as the disk must have no files. Unclear as to why this 
:: does occur but the disk in question would allow chkdsk and then throw this prompt
:: about convert chains to files. When I added this code the problem went away
:: However that disk then reported a bad track 0 and I had to use a magnet to wipe the disk
:: It then formated. 
vol A: >nul 2>&1
if errorlevel 1 (
    echo The disk in drive A: has no volume
	echo Formatting is needed.
	set /a badSectorsFound=1
	exit /b 1
) else (
    echo The disk in drive A: has a volume
)
set "VolumeSerialNumber="
set "FileSystemName="
:: Capture the output of fsutil into variables
for /f "tokens=1* delims=:" %%a in ('fsutil fsinfo volumeinfo A: ^| findstr /R /C:"Volume Serial Number" /C:"File System Name" /C:"Volume Name"') do (
    set "infoType=%%a"
    set "infoValue=%%b"
    set "infoType=!infoType: =!"
    set "!infoType!=!infoValue:~1!"
)
:: Use the variables
echo Volume Serial Number is: %VolumeSerialNumber%
echo File System Name is: %FileSystemName%
echo Volume Name is: %VolumeName%
:: might use this to detect formatted floppies
::if "%VolumeName%"=="FLOPPY" (
::   echo The variable is equal to FLOPPY.
::)	
 
if %FileSystemName% equ "FAT" (
	echo Disk is FAT format
)
exit /b 0

:BadSectorReport
set "ReportingText=%~1"
set "CountText=%~2"
set "BadExists=0"
::Store previous bad sector count
set /a badSectorBytesPrevious=!BadSectorBytes!
set /a BadSectorBytes=0
set /a line=0

if !lastFormatFailed! equ 1 (
	Echo Unable to format so skipping Bad Sector check
	exit /b
)

:: Run CHKDSK and redirect output to a file
chkdsk A: > chkdsk_output.txt 2>&1
set "chkdskReturn=%errorlevel%"

:: Handle different CHKDSK exit codes
if !chkdskReturn! equ 3 (
	Echo Could not check disk so skipping Bad Sector check
	goto Cleanup
)


if !chkdskReturn! equ 0 (
	:: Check for bad sectors in the report
	type chkdsk_output.txt | findstr /C:"bytes in bad sectors" > bad_sectors_line.txt
	findstr /C:"bytes in bad sectors" bad_sectors_line.txt > nul
	:: Read the line from the file
	set /p line=<bad_sectors_line.txt
	:: Remove leading spaces, commas, and alphabetic characters
	set "cleaned_line=!line: =!"
	set "cleaned_line=!cleaned_line:,=!"
	for /f "delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ" %%a in ("!cleaned_line!") do set "number=%%a"
	set "IsNumber=1"
	:: Check if number contains non-numeric characters
	for /f "delims=0123456789" %%a in ("!number!") do set "IsNumber=0"
	if "!IsNumber!"=="1" (
		:: Output the bytes in bad sectors
		echo Number of bytes in bad sectors: !number!
		if !number! equ 0 (
			Echo Disk is formatted and no bad sectors reported in FAT
			set /a badSectorsFound=0
			set /a zerodefectformatcount+=1
			set /a BadSectorBytes=0
		)
		if !number! gtr 0 (
			Echo Bad sectors reported in FAT
			set /a badSectorsFound=1
			set /a zerodefectformatcount=0
			set /a BadSectorBytes=!number!
			:: Only 2nd format onwards
			if !count! neq 1 (
				::We need a format that worked
				if !lastFormatFailed! equ 0 (
					:: Hard errors are consistent
					if !badSectorBytesPrevious! leq !BadSectorBytes! (
						set /a hardErrorsStable=1
					)
					:: This is only looking for reducing BS Counts not zero defect
					If !badSectorBytesPrevious! equ 0 (
						set /a hardErrorsStable=0
					)
				Echo Disk defect stability is !hardErrorsStable! previous bytes in bad sectors was !badSectorBytesPrevious! current bytes in bad sector !BadSectorBytes!
				)			
			)
		)
	if "!IsNumber!"=="0" (
		Echo Non numeric from bad Sector check halting..
		exit /b
	)
) 
Echo #Format/Surface Scans with no bad sectors is !zerodefectformatcount!
goto Cleanup
)

echo Unexpected return code from CHKDSK
goto Cleanup

:Cleanup
:: Clean up temporary files
if exist chkdsk_output.txt del chkdsk_output.txt
if exist bad_sectors_line.txt del bad_sectors_line.txt
exit /b


:SFormat
echo Trying to format
call :format 
exit /b 0

:format
set /a count+=1
call :progress %count% %maxf% "Format"
format A: /P:2 /X /Y /V:Floppy
:: Check the result of the format command
if %errorlevel% neq 0 (
	set /a lastFormatFailed=1
	set /a failedformatcount+=1
	exit /b 1
) else (
	set /a lastFormatFailed=0
	set /a goodformatcount+=1
	exit /b 0	
)
echo Should not execute after format. Investigate.
exit /b 0	

:: Function to add a value and associated text to the array
:AddToArray
set /a value=%~1
set "text=%~2"
set arrayValue[!index!]=!value!
set arrayText[!index!]=!text!
:: Update max length of text if necessary
set "tempText=!text!"
set /a textLength=0
for /l %%a in (0,1,1000) do if "!tempText:~%%a,1!" neq "" set /a textLength=%%a+1
if !textLength! gtr !maxLength! set /a maxLength=!textLength!
set /a index+=1
exit /b 0

:: Function to graph the values in the array
:GraphArray
for /l %%i in (0,1,!index!) do (
    if defined arrayValue[%%i] (
        set "text=!arrayText[%%i]!"
        set "paddedText=!text!"
        :: Pad the text with spaces
        set "tempText=!text!"
        set /a textLength=0
        for /l %%a in (0,1,1000) do if "!tempText:~%%a,1!" neq "" set /a textLength=%%a+1
        set /a spacesToAdd=!maxLength!-!textLength!
        for /l %%j in (0,1,!spacesToAdd!) do set "paddedText=!paddedText! "
        :: Call NormalizeValue function to get the graph
        call :NormalizeValue !arrayValue[%%i]! graph
        :: Output the padded text and graph
        echo !paddedText!!graph!
    )
)
exit /b 0

:: Function to normalize and graph a single value
:NormalizeValue
set /a value=%~1
set /a maxValue=120000
set /a normalizedMax=60
set /a normalizedValue=(!value!*!normalizedMax!/!maxValue!)
:: Ensure the normalized value is within the range
if !normalizedValue! gtr !normalizedMax! (
    set /a normalizedValue=!normalizedMax!
)
if !normalizedValue! lss 1 (
    set /a normalizedValue=1
)
:: Graph the normalized value or output a . if the value is zero
set "graph="
if !value! equ 0 (
    set "graph=."
) else (
    for /l %%j in (1,1,!normalizedValue!) do (
        set "graph=!graph!*"
    )
)
:: Return the graph via an output variable
set "%~2=!graph!"
exit /b 0


:ShowLogo
echo|set /p=" _______"
echo.
echo|set /p="| |__| | Media Recovery Script"
echo.
echo|set /p="|  ()  | Version: 1.0 (Disk Defibrillator)"
echo.
echo|set /p="|______| Revision: 2024-01-12"
echo.
echo.


exit /b 0


:WPCheck
REM *** Call format A: and pipe the output to a file named output.txt
Echo Testing for Write Protection Error, please wait...
FORMAT A: /P:2 /X /Y /V:Floppy > output.txt
REM *** Scan the file for the write protected errors and set a variable named isWriteProtected
find /i "write protected" output.txt > nul
if %errorlevel% equ 0 (
  set isWriteProtected=1
) else (
  set isWriteProtected=0
)
REM *** Display the value of the variable
echo isWriteProtected = %isWriteProtected%



:: ====================================
:: Notes
:: Description: Summary Notes for batch
::              File development
:: Revision     2024-01-12
:: ====================================
:: By default, variables within a block of code (like an IF statement or a loop) 
:: are expanded just once when the block is read, which means %miniumgoodformatcount% 
:: is not updated after the set /a command within the same block (see code later)
:: To solve this, enable delayed expansion, which allows you to use ! instead of % to 
:: get the updated value of a variable within the same block.
::  
:: Operator | Description
:: EQU      | equal to
:: NEQ      | not equal to
:: LSS      | less than
:: LEQ      | less than or equal to
:: GTR      | greater than
:: GEQ      | greater than or equal to