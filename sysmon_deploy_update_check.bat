rem setting variables
set SETUPFOLDER=\\superserver\Sysmon\setup
set INSTALLFOLDER=c:\WINDOWS\sysmon_install_folder
set SYSMON_CFG_NAME=Sysmon_config.xml
rem file name parameter is used by installer to define service neme. So set it here if you whant to use some specific name. The same for Driver. Useful if you want to hide Sysmon from beeing detected by attacker.
rem Driver Name 8 characters max.
set SYSMON_DRV_NAME=sysmondr
set SYSMON_EXE_NAME=Sysmon.exe
rem Service name should be the same as filename (without .exe)
set SYSMON_SVC_NAME=Sysmon_svc
set LOGFOLDER=\\superserver\Sysmon\logs


rem get date and time 
for /f "delims=" %%a in ('powershell get-date(Get-Date^) -uformat "%%H:%%M"') do set time=%%a
for /f "delims=" %%a in ('powershell get-date(Get-Date^) -uformat "%%d/%%m/%%Y"') do set date=%%a

rem Check for existence
sc query "%SYSMON_SVC_NAME%" |findstr STATE
If "%ERRORLEVEL%" EQU "1" (
rem install
echo "%date% - %time% Sysmon serverice is not installe on computer: %computername% . Installing..." >> %LOGFOLDER%\Warning\%computername%_w.log
mkdir "%INSTALLFOLDER%"
copy /z /y "%SETUPFOLDER%\%SYSMON_CFG_NAME%" "%INSTALLFOLDER%"
copy /z /y "%SETUPFOLDER%\%SYSMON_EXE_NAME%" "%INSTALLFOLDER%"
del /F "C:\WINDOWS\%SYSMON_EXE_NAME%"
"%INSTALLFOLDER%%SYSMON_EXE_NAME%" -accepteula -i "%INSTALLFOLDER%%SYSMON_CFG_NAME%" -d %SYSMON_DRV_NAME%
) else (
echo "%date% - %time% Sysmon service is installed on computer: %computername%. Nothing to do." >> %LOGFOLDER%\OK\%computername%_OK.log
)

rem check for Install Folder existents 
if exist %INSTALLFOLDER% (
  echo Install Folder exists. OK.
) else (
  echo Install Folder Does not exist. Creating folder and copy files. 
  mkdir "%INSTALLFOLDER%"
  copy /z /y "%SETUPFOLDER%\%SYSMON_CFG_NAME%" "%INSTALLFOLDER%"
  copy /z /y "%SETUPFOLDER%\%SYSMON_EXE_NAME%" "%INSTALLFOLDER%"
)

rem service check for up to date.
fc "%INSTALLFOLDER%%SYSMON_EXE_NAME%" "%SETUPFOLDER%\%SYSMON_EXE_NAME%" > nul
If "%ERRORLEVEL%" EQU "1" (
rem updating %SYSMON_SVC_NAME%...
echo "%date% - %time% Sysmon serviss is out of date on %computername%. Installing a new version..." >> %LOGFOLDER%\Warning\%computername%_w.log
net stop "%SYSMON_SVC_NAME%"
"%INSTALLFOLDER%%SYSMON_EXE_NAME%" -u force
del /F "C:\WINDOWS\%SYSMON_EXE_NAME%"
copy /z /y "%SETUPFOLDER%\%SYSMON_EXE_NAME%" "%INSTALLFOLDER%"
copy /z /y "%SETUPFOLDER%\%SYSMON_CFG_NAME%" "%INSTALLFOLDER%"
"%INSTALLFOLDER%%SYSMON_EXE_NAME%" -accepteula -i "%INSTALLFOLDER%%SYSMON_CFG_NAME%" -d %SYSMON_DRV_NAME%
) else (
echo "%date% - %time% Computer %computername% is running the newest version of Sysmon. Nothing to do." >> %LOGFOLDER%\OK\%computername%_OK.log
)

rem config check for up to date.
fc "%INSTALLFOLDER%%SYSMON_CFG_NAME%" "%SETUPFOLDER%\%SYSMON_CFG_NAME%" > nul
If "%ERRORLEVEL%" EQU "1" (
rem updating config...
echo "%date% - %time% Sysmon serviss konfig file is out of date on %computername%. Installing a new version..." >> %LOGFOLDER%\Warning\%computername%_w.log
copy /z /y "%SETUPFOLDER%\%SYSMON_CFG_NAME%" "%INSTALLFOLDER%"
"%SYSMON_EXE_NAME%" -c %INSTALLFOLDER%%SYSMON_CFG_NAME%
) else (
echo "%date% - %time% Computer %computername% is running the newest version of Sysmon config. Nothing to do." >> %LOGFOLDER%\OK\%computername%_OK.log
)

rem check for service status
sc query "%SYSMON_SVC_NAME%" | Find "RUNNING"
If "%ERRORLEVEL%" EQU "1" (
echo "%date% - %time% Sysmon service is stopped on %computername%. Starting sysmon..." >> %LOGFOLDER%\Warning\%computername%_w.log
net start "%SYSMON_SVC_NAME%"
) else (
echo "%date% - %time% Sysmon service is in running state on %computername% Nothing to do." >> %LOGFOLDER%\OK\%computername%_OK.log
)

rem Change Description of Sysmon service
Set ServiceDescription="DESCRIPTION:  Microsoft Windows Event Mnitor Service"
FOR /F "tokens=*" %%g IN ('sc Qdescription "%SYSMON_SVC_NAME%" ^|findstr "DESCRIPTION:"') DO (SET CurrentSvcDescription=%%g)
if %ServiceDescription% == "%CurrentSvcDescription%" (
echo "%date% - %time% Sysmon service description is correct on %computername%. Nothing to do." >> %LOGFOLDER%\OK\%computername%_OK.log
) ELSE (
echo "%date% - %time% SYsmon service description is not correct on  %computername% Setting new description... " >> %LOGFOLDER%\Warning\%computername%_w.log
sc description "%SYSMON_SVC_NAME%" "Microsoft Windows Event Mnitor Service"
)

rem EventViewer Sysmon file permission check 
Set CA="channelAccess: O:BAG:SYD:(A;;0xf0007;;;SY)(A;;0x7;;;BA)(A;;0x1;;;S-1-5-32-573)(A;;0x1;;;NS)"
FOR /F "tokens=*" %%g IN ('wevtutil gl Microsoft-Windows-Sysmon/Operational ^|findstr "channelAccess:"') DO (SET CurrentCA=%%g)
if %CA% == "%CurrentCA%" (
echo "%date% - %time% Sysmon log file persmission are correct on %computername%. Nothing to do." >> %LOGFOLDER%\OK\%computername%_OK.log
) ELSE (
echo "%date% - %time% Sysmon log file persmission not correct on %computername%. Changing... " >> %LOGFOLDER%\Warning\%computername%_w.log
wevtutil sl Microsoft-Windows-Sysmon/Operational /ca:"O:BAG:SYD:(A;;0xf0007;;;SY)(A;;0x7;;;BA)(A;;0x1;;;S-1-5-32-573)(A;;0x1;;;NS)"
)

rem service registry check. Sysmon service executable file path must be set in quotas in ImagePath parameter. "C:\WINDOWS\%SYSMON_EXE_NAME%". Google for "Unquoted service path" vulnerability. 

REG QUERY "HKLM\SYSTEM\CurrentControlSet\Services\%SYSMON_SVC_NAME%" /v "ImagePath" | Findstr """
IF %ERRORLEVEL% == 1 (
echo "%date% - %time% Sysmon registry has unquoted value in ImagePath parameter on %computername%. Changing... " >> %LOGFOLDER%\Warning\%computername%_w.log
REG ADD "HKLM\SYSTEM\CurrentControlSet\Services\%SYSMON_SVC_NAME%" /v "ImagePath" /t REG_EXPAND_SZ /d "\"C:\WINDOWS\%SYSMON_EXE_NAME%\"" /f
net stop "%SYSMON_SVC_NAME%"
net start "%SYSMON_SVC_NAME%"
)else (
echo "%date% - %time% Sysmon service registry ImagePath value is correct on %computername%. Nothing to do." >> %LOGFOLDER%\OK\%computername%_OK.log
)

 









