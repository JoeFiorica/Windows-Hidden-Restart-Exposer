@echo off
setlocal EnableDelayedExpansion
title Windows Update Reboot Status Check
cls

if "%~1" neq "__KEEP__" (
    cmd /k "%~f0" __KEEP__
    exit /b
)

echo ==========================================
echo   Windows Update Reboot Status Check
echo ==========================================
echo.
echo This script checks update / reboot state.
echo No update actions will be triggered.
echo.

:: -------------------------------------------------
:: REQUIRE ADMIN
:: -------------------------------------------------
net session >nul 2>&1
if errorlevel 1 (
    echo ERROR: Run this script as Administrator.
    echo.
    pause
    exit /b
)

:: ================================
:: AUTO-RESTART POLICY STATUS
:: ================================
echo.
echo ==========================================
echo AUTO-RESTART POLICY STATUS
echo ==========================================

reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" ^
 /v NoAutoRebootWithLoggedOnUsers >nul 2>&1

if errorlevel 1 goto AR_NOT_ENABLED

for /f "tokens=3" %%A in (
    'reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" ^
     /v NoAutoRebootWithLoggedOnUsers'
) do set POLICY_VALUE=%%A

if "%POLICY_VALUE%"=="0x1" goto AR_ENABLED

:AR_NOT_ENABLED
echo WARNING: AUTO-RESTART PROTECTION IS NOT ENABLED
echo Automatic restarts are ALLOWED when enforcement exists.
echo.
echo To enable protection:
echo   1. Open: gpedit.msc
echo   2. Navigate to:
echo      Computer Configuration
echo        ^> Administrative Templates
echo          ^> Windows Components
echo            ^> Windows Update
echo              ^> Legacy Policies
echo   3. Enable:
echo      No auto-restart with logged on users for scheduled automatic updates installations
echo.
echo Registry alternative (Administrator):
echo   HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU
echo   NoAutoRebootWithLoggedOnUsers = 1 (DWORD)
goto AR_DONE

:AR_ENABLED
echo Policy ENABLED:
echo Automatic restarts are BLOCKED while a user is logged on.

:AR_DONE

:: ================================
:: UPDATE PAUSE STATUS
:: ================================
echo.
echo ==========================================
echo UPDATE PAUSE STATUS
echo ==========================================

set "PAUSED=0"
set "PAUSE_END="

for /f "tokens=2,*" %%A in (
    'reg query "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v PauseUpdatesExpiryTime 2^>nul'
) do set "PAUSE_END=%%B"

if defined PAUSE_END (
    set "PAUSED=1"
    echo Updates are PAUSED
    echo Pause expires on: !PAUSE_END!
) else (
    echo Updates are NOT paused
)

:: ================================
:: NORMAL REBOOT REQUIRED CHECK
:: ================================
echo.
echo ==========================================
echo NORMAL REBOOT REQUIRED (USER-CONTROLLED)
echo ==========================================

set "NORMAL_REBOOT=0"

reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" >nul 2>&1 && set "NORMAL_REBOOT=1"
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" >nul 2>&1 && set "NORMAL_REBOOT=1"
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v PendingFileRenameOperations >nul 2>&1 && set "NORMAL_REBOOT=1"

if "!NORMAL_REBOOT!"=="1" (
    echo A normal reboot is required.
    echo This reboot is USER-CONTROLLED and not enforced.
) else (
    echo No normal reboot requirement detected.
)

:: ================================
:: MoUSO SERVICING ENFORCEMENT CHECK
:: ================================
echo.
echo ==========================================
echo MoUSO SERVICING ENFORCEMENT STATUS
echo ==========================================

set "MUSO_ENFORCEMENT=0"

for %%T in (Reboot Reboot_AC Reboot_Battery) do (
    schtasks /query /tn "\Microsoft\Windows\UpdateOrchestrator\%%T" >nul 2>&1
    if not errorlevel 1 (
        schtasks /query /tn "\Microsoft\Windows\UpdateOrchestrator\%%T" | findstr /i "Ready Running" >nul 2>&1
        if not errorlevel 1 set "MUSO_ENFORCEMENT=1"
    )
)

if "!MUSO_ENFORCEMENT!"=="1" (
    echo MoUSO servicing enforcement IS ARMED.
    echo A restart will occur once allowed.
) else (
    echo No MoUSO servicing enforcement scheduled.
)

:: ================================
:: FINAL INTERPRETATION
:: ================================
echo.
echo ==========================================
echo FINAL INTERPRETATION
echo ==========================================

if "!MUSO_ENFORCEMENT!"=="1" (
    if "!AUTO_RESTART_BLOCKED!"=="0" (
        echo CRITICAL:
        echo Automatic restarts are NOT blocked.
        echo A MoUSO-enforced restart may occur when no user is logged in.
    )
    if "!PAUSED!"=="1" (
        echo Forced restart becomes legal ON OR AFTER:
        echo !PAUSE_END!
    ) else (
        echo Windows will restart automatically once allowed.
    )
) else (
    echo No hidden servicing enforcement detected.
)

echo ==========================================
echo.
pause
exit /b
