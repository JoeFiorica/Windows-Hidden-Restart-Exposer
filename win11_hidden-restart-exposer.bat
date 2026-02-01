@echo off
setlocal enabledelayedexpansion
title Windows Update Reboot Status Check
cls

echo ==========================================
echo   Windows Update Reboot Status Check
echo ==========================================
echo.
echo This script ONLY checks update / reboot state.
echo No update actions will be triggered.
echo.

:: -------------------------------------------------
:: REQUIRE ADMIN
:: -------------------------------------------------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Run this script as Administrator.
    pause
    exit /b 1
)

goto STATUS

:: -------------------------------------------------
:STATUS

:: ================================
:: UPDATE PAUSE STATUS
:: ================================
echo.
echo ==========================================
echo UPDATE PAUSE STATUS
echo ==========================================

set PAUSED=0
set PAUSE_END=

for /f "tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v PauseUpdatesExpiryTime 2^>nul') do set PAUSE_END=%%B

if defined PAUSE_END (
    set PAUSED=1
    echo Updates are PAUSED
    echo Pause expires on: %PAUSE_END%
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

set NORMAL_REBOOT=0

reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" >nul 2>&1 && set NORMAL_REBOOT=1
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" >nul 2>&1 && set NORMAL_REBOOT=1
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v PendingFileRenameOperations >nul 2>&1 && set NORMAL_REBOOT=1

if %NORMAL_REBOOT%==1 (
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

set MUSO_ENFORCEMENT=0

for %%T in (Reboot Reboot_AC Reboot_Battery) do (
    schtasks /query /tn "\Microsoft\Windows\UpdateOrchestrator\%%T" >nul 2>&1
    if !errorlevel!==0 (
        schtasks /query /tn "\Microsoft\Windows\UpdateOrchestrator\%%T" | findstr /i "Ready Running" >nul 2>&1
        if !errorlevel!==0 (
            set MUSO_ENFORCEMENT=1
        )
    )
)

if %MUSO_ENFORCEMENT%==1 (
    echo MoUSO servicing enforcement IS ARMED.
    echo This class of update can force a restart.
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

if %MUSO_ENFORCEMENT%==1 (
    if %PAUSED%==1 (
        echo Servicing updates are already installed.
        echo Enforcement is DEFERRED by pause.
        echo.
        echo Forced restart becomes legal ON OR AFTER:
        echo %PAUSE_END%
    ) else (
        echo Servicing updates are already installed.
        echo Updates are NOT paused.
        echo.
        echo Windows may force a restart AT ANY TIME.
    )
) else (
    echo No hidden servicing enforcement detected.
    echo A forced "Service pack (Planned)" restart is NOT expected.
)

echo ==========================================
echo.
pause
exit /b 0
