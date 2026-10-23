# Windows Hidden Restart Exposer

Show Windows Update restart indicators in one read-only console report.
This is a snapshot, not a prediction of when Windows will restart.

## Requirements

Windows 11 with built-in Windows PowerShell 5.1. Keep the BAT and PS1 together.
PowerShell 7 can also run the PS1 directly. No installation or network access is needed.

## Usage

Double-click `win11_hidden-restart-exposer.bat`. The window stays open until you press a key.
From a terminal:

```bat
win11_hidden-restart-exposer.bat -Help
win11_hidden-restart-exposer.bat -TimeoutSeconds 15
```

Commands with arguments finish without pausing. In PowerShell, prefix BAT commands
with `.\`. Quote paths containing spaces. Administrator rights may expose more fields;
the tool never elevates itself. Organization policy may block scripts.

## Behavior

The report shows the legacy `NoAutoRebootWithLoggedOnUsers` policy, recorded update-pause
expiry, three pending-reboot registry indicators, and Update Orchestrator's
Reboot, Reboot_AC and Reboot_Battery task states.

These observations do not guarantee protection from restarts or establish a restart
deadline. Pending flags and Ready/Running tasks do not prove a restart is imminent.
Missing or inaccessible data remains unknown. Check Windows Update and your
organization's policy before scheduling downtime.

## Outputs

Reports print to the console; no files are written. Reports/help exit 0;
timeout or failure exits 1. Incomplete observations are labeled.

## Safety and privacy

No updates, registry/policy/task changes or restart requests. No telemetry or uploads.
Collection has a 15-second timeout by default, adjustable from 1 to 60 seconds.
Review console captures before sharing them.

## Troubleshooting

`-Help` should exit 0 without reading system state. `-TimeoutSeconds 0` should fail
with exit 1 before collection. If collection times out, try `-TimeoutSeconds 30`.
An inaccessible field may need administrator rights. Task names and behavior vary by Windows build.

Report issues with the command, Windows version and expected/actual result.
Omit identifying console captures.
