#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Help,
    [object]$TimeoutSeconds = 15,
    [switch]$Collect
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-RegistryObservation([string]$Path, [string]$Name = '') {
    $key = $null
    try {
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($Path)
        if ($null -eq $key) { return [pscustomobject]@{Status='Absent';Value=$null} }
        if (-not $Name) { return [pscustomobject]@{Status='Present';Value=$null} }
        if ($key.GetValueNames() -notcontains $Name) {
            return [pscustomobject]@{Status='Absent';Value=$null}
        }
        return [pscustomobject]@{Status='Present';Value=$key.GetValue($Name)}
    } catch {
        return [pscustomobject]@{Status='Unknown';Value=$null}
    } finally {
        if ($null -ne $key) { $key.Dispose() }
    }
}

function Get-RestartObservation {
    $policy = Get-RegistryObservation 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'NoAutoRebootWithLoggedOnUsers'
    $pause = Get-RegistryObservation 'SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'PauseUpdatesExpiryTime'
    $generic = @(
        (Get-RegistryObservation 'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'),
        (Get-RegistryObservation 'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'),
        (Get-RegistryObservation 'SYSTEM\CurrentControlSet\Control\Session Manager' 'PendingFileRenameOperations')
    )
    # Only presence matters; never serialize pending-file-rename paths.
    foreach ($indicator in $generic) { $indicator.Value = $null }
    $tasks = @()
    foreach ($name in @('Reboot','Reboot_AC','Reboot_Battery')) {
        try {
            $found = @(Get-ScheduledTask -TaskPath '\Microsoft\Windows\UpdateOrchestrator\' -TaskName $name -ErrorAction Stop)
            if ($found.Count -eq 1) {
                $tasks += [pscustomobject]@{Name=$name;State=[string]$found[0].State}
            } else { $tasks += [pscustomobject]@{Name=$name;State='Unknown'} }
        } catch {
            # A missing or inaccessible task cannot establish that no restart is possible.
            $tasks += [pscustomobject]@{Name=$name;State='Unknown'}
        }
    }
    [pscustomobject]@{Policy=$policy;Pause=$pause;Generic=$generic;Tasks=$tasks}
}

function Write-RestartReport($Observation, [DateTimeOffset]$Now = [DateTimeOffset]::UtcNow) {
    Write-Output 'Windows Update Reboot Status Check'
    Write-Output 'Read-only snapshot; Windows Update settings and restart status can change.'
    Write-Output ''
    Write-Output 'AUTO-RESTART POLICY STATUS'
    if ($Observation.Policy.Status -eq 'Unknown') { Write-Output 'Policy could not be read.' }
    elseif ($Observation.Policy.Status -eq 'Present' -and $Observation.Policy.Value -eq 1) {
        Write-Output 'NoAutoRebootWithLoggedOnUsers = 1 is configured.'
    } else { Write-Output 'NoAutoRebootWithLoggedOnUsers = 1 was not observed.' }
    Write-Output 'This legacy policy is conditional; it does not guarantee restart protection.'
    Write-Output ''
    Write-Output 'UPDATE PAUSE STATUS'
    $expiry = [DateTimeOffset]::MinValue
    if ($Observation.Pause.Status -eq 'Unknown') { Write-Output 'Pause state could not be read.' }
    elseif ($Observation.Pause.Status -ne 'Present') { Write-Output 'No pause expiry value was observed.' }
    elseif ([DateTimeOffset]::TryParse([string]$Observation.Pause.Value,
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$expiry)) {
        if ($expiry -gt $Now) { Write-Output ('Recorded pause expiry (future): '+$expiry.ToString('u')) }
        else { Write-Output ('Recorded pause expiry has passed: '+$expiry.ToString('u')) }
    } else { Write-Output 'Pause expiry is unreadable; pause state is unknown.' }
    Write-Output 'Pause dates do not establish a restart deadline or an exemption.'
    Write-Output ''
    Write-Output 'PENDING-RESTART INDICATORS'
    if (@($Observation.Generic | Where-Object {$_.Status -eq 'Present'}).Count -gt 0) {
        Write-Output 'A generic pending-reboot indicator is present.'
    } elseif (@($Observation.Generic | Where-Object {$_.Status -eq 'Unknown'}).Count -gt 0) {
        Write-Output 'Pending-reboot state is incomplete.'
    } else { Write-Output 'No checked generic pending-reboot indicator was observed.' }
    Write-Output 'These indicators do not distinguish user-controlled and enforced restarts.'
    Write-Output ''
    Write-Output 'WINDOWS UPDATE RESTART TASKS'
    foreach ($task in $Observation.Tasks) {
        Write-Output ($task.Name+': '+$task.State)
    }
    if (@($Observation.Tasks | Where-Object {$_.State -in @('Ready','Running')}).Count -gt 0) {
        Write-Output 'An active Update Orchestrator reboot task was observed.'
    } else { Write-Output 'No active task was observed among the three checked task names.' }
    Write-Output ''
    Write-Output 'FINAL INTERPRETATION'
    Write-Output 'Task readiness does not prove that a restart is armed or imminent.'
    Write-Output 'Missing or inaccessible observations do not prove that restarts are blocked.'
    Write-Output 'Check Windows Update and your organization policy before planning downtime.'
}

function Invoke-RestartCheck([int]$Seconds) {
    $process = New-Object Diagnostics.Process
    $process.StartInfo = New-Object Diagnostics.ProcessStartInfo
    $process.StartInfo.FileName = (Get-Process -Id $PID).Path
    $process.StartInfo.Arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$PSCommandPath+'" -Collect'
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    try {
        if (-not $process.Start()) { throw 'Could not start the restart check; restart status is unknown. Try again from a terminal.' }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($Seconds * 1000)) {
            $process.Kill()
            $null = $process.WaitForExit(2000)
            throw 'The restart check timed out; restart status is unknown. Try -TimeoutSeconds 30.'
        }
        $output = $stdout.Result
        $null = $stderr.Result
        if ($process.ExitCode -ne 0 -or $output.Length -gt 32768) {
            throw 'The restart check could not finish; restart status is unknown. Try again from a terminal.'
        }
        $observation = $output | ConvertFrom-Json
        Write-RestartReport $observation
        return
    } finally { $process.Dispose() }
}

# Dot-sourcing defines report/collection functions for independent offline checks.
if ($MyInvocation.InvocationName -eq '.') { return }
try {
    try { [int]$TimeoutSeconds = $TimeoutSeconds }
    catch { throw '-TimeoutSeconds must be a whole number from 1 to 60.' }
    if ($TimeoutSeconds -lt 1 -or $TimeoutSeconds -gt 60) { throw '-TimeoutSeconds must be from 1 to 60.' }
} catch {
    [Console]::Error.WriteLine('ERROR: ' + $_.Exception.Message + ' Run the launcher with -Help for usage.')
    exit 1
}
if ($Help) {
    Write-Output @'
Usage: win11_hidden-restart-exposer.bat [-Help] [-TimeoutSeconds 1..60]

Show Windows Update restart indicators in the console. A snapshot cannot predict
when Windows will restart; missing or inaccessible information remains unknown.

  -Help             Show this help without reading system state.
  -TimeoutSeconds   Maximum collection time (default 15 seconds; range 1-60).

Double-click the BAT to show a report and keep its window open.
With arguments, it finishes without pausing. In PowerShell, prefix the BAT with .\.
No output files are created. No updates, policy changes, uploads or restarts.
Administrator rights may expose more fields; the tool never elevates itself.
Exit codes: 0 report/help completed; 1 timeout, invalid arguments or failure.
'@
    exit 0
}
try {
    if ($Collect) {
        Get-RestartObservation | ConvertTo-Json -Depth 6 -Compress
    } else {
        Invoke-RestartCheck $TimeoutSeconds
    }
    exit 0
} catch {
    $message = 'Could not complete the restart check; restart status is unknown. Run the launcher with -Help for usage.'
    $knownMessages = @(
        'Could not start the restart check; restart status is unknown. Try again from a terminal.',
        'The restart check timed out; restart status is unknown. Try -TimeoutSeconds 30.',
        'The restart check could not finish; restart status is unknown. Try again from a terminal.'
    )
    if ($_.Exception.Message -cin $knownMessages) { $message = $_.Exception.Message }
    [Console]::Error.WriteLine('ERROR: '+$message)
    exit 1
}
