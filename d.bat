@echo off
cls
setlocal enabledelayedexpansion

REM By default, variables within a block of code (like an IF statement or a loop) 
REM are expanded just once when the block is read, which means %miniumgoodformatcount% 
REM is not updated after the set /a command within the same block (see code later)
REM To solve this, enable delayed expansion, which allows you to use ! instead of % to 
REM get the updated value of a variable within the same block. 


REM Operator | Description
REM EQU      | equal to
REM NEQ      | not equal to
REM LSS      | less than
REM LEQ      | less than or equal to
REM GTR      | greater than
REM GEQ      | greater than or equal to

setlocal

:: Initialize the counter for the array index and max string length
set /a index=0
set /a maxLength=0

set /a maxfinalscancount=2
set /a zerodefectformatcount=0
set /a somedefectformatcount=0
set /a wobble=0
set /a stable=0
set /a miniumgoodformatcount=2
REM why is this 1? Check later
set /a smartformatcount=1 
set /a lastformatfailed=0
set /a failedformatcount=0
set /a lastformatfailed=0
set /a goodformatcount=10

REM Set # times to try and format (if there are errors on the disk)
set /a maxf=4
REM Set # of times to scan the disk and relocate sectors (when there are no bad sectors reported)
set /a scancount=2
REM Set max # times to test a disk with bad sectors after formatting. 
set /a MAX_STABILITY_CHECKS=10
set /a goodformatcount=0
set /a count=0
set /a chkcount=1
set /a lastformatfailed=0
set /a badSectorsFound=-1
set /a formatted_already=0

REM Get Script Start Time Using jTimestamp.cmd
CALL jTimestamp -f {ums} -r t1
REM Show time 
call :showdatetime

REM Assume not formatted
set /a formatted=0
REM Halt if files found on A: also record if disk is formatted
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

:TryFormattingAgain
:: Are we done?
if %count% geq !maxf! (
    echo Made !maxf! attempts. Exit after checking for bad sectors..
	if %lastformatfailed% equ 1 (
		echo Last format did not work exit
		echo Disk may be unusable wipe with magnet or electromagnet and retrying
		echo Inspect the disks for errors to see if there is phyical damage
		echo Check drive and disk are connected. Try formatting disk manually to check setup.
		call :disksummary
		echo Stopping, disk is not formatted.
		call :sad
		exit /b 0
	)
	:: Last format worked
	call :DiskPostFormatCheck
	call :DiskSummary
	echo Stopping Disk is formatted
	exit /b 0
)
:: Not done
call :SFormat
REM Skip Bad Sector Check if format did not work
if lastformatfailed equ 0 (
call :bscheck
)
if !zerodefectformatcount! geq 2 (
	set /a maxf=2
	echo completed !zerodefectformatcount! Zero defect formats, stopping..
	
)

goto :TryFormattingAgain
echo Stopping..
exit /b


REM We have a floppy disk see if there are bad sectors 
:bscheck
REM Check if a floppy disk is inserted
if exist a:\ (
    echo Bad Sector Check - Floppy disk detected.
    REM Unmount the floppy disk forcefully
    echo Forcibly unmounting the floppy disk...
    fsutil fsinfo volumeinfo a: >nul 2>&1 && fsutil volume dismount a: >nul 2>&1
	call :updatetime
) else (
    echo No floppy disk detected
	exit /b 0
)
REM Initialize bad sector check to 0 = No errors
set  /a "badSectorsFound=0"
REM Check if a floppy disk is inserted 
echo Checking for bad sectors on floppy disk in drive A:...
REM Run chkdsk to check for bad sectors
chkdsk a: /F /X > "C:\Users\Seth\chkdsk_output.txt" 2>&1
REM Check the output of chkdsk for any indication of bad sectors
findstr /C:"bad sectors" "C:\Users\Seth\chkdsk_output.txt" > bs.txt
REM Count lines in the specified file
for /f %%A in ('find /c /v "" ^< "bs.txt"') do set "badSectorsFound=%%A"
REM Display the result
if !badSectorsFound! gtr 0 (
	echo Bad sectors found on the floppy disk in drive A:.
	set /a somedefectformatcount=+1
) else (
	echo No bad sectors found on the floppy disk in drive A:.
	set /a zerodefectformatcount=+1
)
REM Clean up the temporary files
del "C:\Users\Seth\chkdsk_output.txt"
del bs.txt
if !badSectorsFound! equ 0 (
	set /a goodformatcount+=1
)
REM If smart format count is on and there are bad sectors let's double the minimum
REM format count as we know the media has issues, reformating lays down new sectors
REM the erase head can magnetically polarise areas of the disk where polarisation has faded
REM this can bring back areas of the disk into use and revive disks. Repeated formating
REM followed by multiple checks to read data off each sector post formatting can Then
REM be used to mark faulty sectors as bad leaving only good sectors in use.
REM the code sets smartformatcount to 0 to prevent the code doubling the format Count
REM indefinately. Users can set it to 0 in at the top of the file to disable this
REM feature 
if !smartformatcount! equ 1 (
	if !badSectorsFound! neq 0 (
		echo Bad sectors detected, smart format count enabled
		echo Minium good format count is !miniumgoodformatcount!
		set /a "miniumgoodformatcount=miniumgoodformatcount*2"
		set /a smartformatcount=0
		echo Minium good format count increased to !miniumgoodformatcount!
	)
)
exit /b 0

:DiskPostFormatCheck
:: Last format was bad so no need to scan for bad sectors one last time
if %lastformatfailed% equ 0 (
	call :finaldiskcheck
)
echo End of Disk Format / Check Run Report
if !chkcount! equ %scancount% Echo Completed !chkcount! Surface Scans
if !badSectorsFound! equ 0 Echo Formatted, no bad sectors
if !badSectorsFound! equ 1 (
	Echo Formatted, but bad sectors present marked as bad and will not be used
	Echo %wobble% disk fixes applied by Checkdisk after formatting with bad sectors
	Echo %stable% sucessful sucessive checkdisk runs with no fixes applied
)
REM Play a sound to show we are done
call :completed
REM Show the elapsed time
call :updatetime
REM Exit processing end of batchfile
exit /b

:completed
start soft-piano-logo-141290.mp3 > nul
timeout 4 > nul
start taskkill /im WMPlayer.exe > nul
exit /b

:sad
start videogame-death-sound-43894.mp3
timeout 4 > nul
start taskkill /im WMPlayer.exe > nul
exit /b

:progress
setlocal
set /a progress=%~1*20/%~2
echo.
echo Formatting attempt: %~1 of %~2
REM Display progress bar
for /l %%i in (1, 1, %progress%) do echo|set /p=#
for /l %%i in (%progress%, 1, 20) do echo|set /p=.
echo.
call :updatetime
endlocal
exit /b

:sprogress
setlocal
set /a progress=%~1*20/%~2
echo.
echo Scanning disk attempt: %~1 of %~2
REM Display progress bar
for /l %%i in (1, 1, %progress%) do echo|set /p=#
for /l %%i in (%progress%, 1, 20) do echo|set /p=.
echo.
call :updatetime
endlocal
exit /b

:updatetime
REM Get Script End Time Using jTimestamp.cmd
CALL jTimestamp -f {ums} -r t2
REM Fancy Time Stamp
for /F "tokens=*" %%a in (
   'jTimestamp -d %t2% /F " {WKD} {MTH} {D}, {yyyy} {H12}:{NN}:{SS}{PM}"'
) do (
   
   set Timestamp=%%a   
)
set "Timestamp=%Timestamp::00am=am%"
set "Timestamp=%Timestamp::00pm=pm%"
REM echo %Timestamp%
REM Get Script End Time Using jTimestamp.cmd
CALL jTimestamp -d %t2%-%t1% -f "{ud} Days {h} Hours {n} Minutes And {s} Seconds" -u
exit /b

:showdatetime
CALL jTimestamp -f {ums} -r t2
REM Fancy Time Stamp
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
    echo The disk in drive A: has a volume but could be RAW or formatted.
)
:: Initialize variables
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
REM might use this to detect formatted floppies
if "%VolumeName%"=="FLOPPY" (
    echo The variable is equal to FLOPPY.
)	
 
if %FileSystemName% equ "FAT" (
	echo Disk is FAT format
)
rem Run chkdsk and redirect the output to a temporary file
chkdsk A: > chkdsk_output.txt 2>&1
rem Extract the line with bad sectors information and save it to a new file
type chkdsk_output.txt | findstr /C:"bytes in bad sectors" > bad_sectors_line.txt
:: Check if the file bad_sectors_line.txt exists
if exist "bad_sectors_line.txt" (
    echo Bad sectors reported by chkdsk using FAT
	:: Read the line from the file
	set /p line=<bad_sectors_line.txt
	:: Remove leading spaces, commas, and alphabetic characters
	set "cleaned_line=!line: =!"
	set "cleaned_line=!cleaned_line:,=!"
	for /f "delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ" %%a in ("!cleaned_line!") do set "number=%%a"
	:: Output the variable
	echo Number of bytes in bad sectors: !number!
	set /a badSectorsFound=1
	) else (
    echo No bad sectors reported
	set /a badSectorsFound=0
	)
rem Cleanup: Delete the temporary file
del chkdsk_output.txt
del bad_sectors_line.txt
exit /b 0

:SFormat
echo Trying to format
call :format
exit /b 0

:format
set /a count+=1
call :progress %count% %maxf%
format A: /P:2 /X /Y /V:Floppy
REM Check the result of the format command
if %errorlevel% neq 0 (
	set /a lastformatfailed=1
	set /a failedformatcount+=1
	exit /b 1
) else (
	set /a lastformatfailed=0
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



    

