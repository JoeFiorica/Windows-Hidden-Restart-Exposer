# Windows Hidden Restart Exposer

A Windows 11 utility that **checks Windows Update servicing state relevant to restart enforcement** and **exposes hidden, planned restarts**.

This tool surfaces **OS-enforced restart conditions** *before* Windows is legally allowed to force them.

— including the exact servicing path that produces:

```
MoUsoCoreWorker.exe
Operating System: Service pack (Planned)
Reason Code: 0x80020010
```

> “Hidden” refers specifically to **Windows Update servicing restarts managed by Update Orchestrator (MoUSO)**, not user-initiated or application-driven reboots.

---

## What This Tool Does

### ✅ Checks Windows Update Servicing State
- Surfaces update activity **only as it relates to restart enforcement**
- Detects whether updates are paused
- Shows when a pause expires and enforcement becomes legal

### ✅ Exposes Hidden Planned Restarts
- Detects **Update Orchestrator (MoUSO)** restart enforcement
- Identifies servicing restarts that are **already installed but delayed**
- Cleanly separates them from normal, user-controlled reboot requirements

---

## What This Tool Does *Not* Do

- ❌ Does not scan for updates
- ❌ Does not download or install updates
- ❌ Does not trigger Windows Update activity
- ❌ Does not reboot the system
- ❌ Does not block or disable Windows Update
- ❌ Does not modify servicing, update, or policy state
- ❌ Does not treat generic “reboot required” flags as enforcement

Generic reboot-required indicators are intentionally excluded, as they do **not** correspond to enforced Update Orchestrator restarts.

---

## Related Windows Policy Behavior (Critical)

### Group Policy: No Auto-Restart With Logged-On Users

Windows includes a Group Policy setting that **prevents any automatic restart while a user is logged on**, including **MoUSO / Update Orchestrator planned restarts**.

**Policy path:**
```
Computer Configuration
 └─ Administrative Templates
    └─ Windows Components
       └─ Windows Update
          └─ No auto-restart with logged on users for scheduled automatic updates installations
```

**Registry equivalent:**
```
HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU
NoAutoRebootWithLoggedOnUsers = 1 (DWORD)
```

### What this policy DOES
- ✅ Blocks **all automatic restarts** while a user session exists
- ✅ Applies to **classic Windows Update** restarts
- ✅ Applies to **MoUSO / Update Orchestrator planned restarts**
- ✅ Forces Windows to wait for a **user-initiated reboot or logoff**

### Policy limitations
- ❗ This policy **does not prevent restarts once no user is logged in**
- ❗ If enforcement exists and the user logs out, Windows **may restart immediately**
- ❗ Headless, kiosk, or shared systems remain vulnerable once sessions end

**Key point:**  
This policy is effective, but **conditional**.  
This tool exists to expose **when enforcement is armed**, so administrators know **when logging out becomes dangerous**.

---

## Why This Exists

Windows Update pause:
- stops downloads and new offers
- does **not** remove already-installed servicing enforcement

Hidden servicing updates can:
- survive multiple reboots
- remain invisible in the Windows Update UI
- later be enforced by `MoUsoCoreWorker.exe` once conditions are met

This tool makes that otherwise opaque state explicit.

---

## Usage

Run as **Administrator**:

```
windows_hidden_restart_exposer.bat
```

The script performs a **status-only diagnostic pass** and exits after displaying results.

---

## Output Interpretation

### Normal reboot required
User-controlled. Windows will wait indefinitely for the user to reboot.

### Hidden planned restart detected
A servicing update is already installed and Windows **will restart automatically once allowed**:
- immediately after user logoff, **or**
- after pause expiry and outside enforcement constraints

---

## Limitations

This tool reflects current Windows 11 servicing behavior.
Microsoft may change Update Orchestrator or MoUSO enforcement logic in future releases.

---

## Supported Systems

- Windows 11 (Home / Pro / Enterprise)
- Retail (non-Insider) builds
