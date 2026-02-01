# Windows Hidden Restart Exposer

A Windows 11 utility that **checks Windows Update servicing state relevant to restart enforcement** and **exposes hidden, planned restarts**
— including the exact servicing path that produces:

```
MoUsoCoreWorker.exe
Operating System: Service pack (Planned)
Reason Code: 0x80020010
```

This tool reveals **OS-enforced restart conditions** *before* Windows is allowed to force them.

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

- ❌ Does not reboot the system
- ❌ Does not block or disable Windows Update
- ❌ Does not modify servicing, update, or policy state
- ❌ Does not treat generic “reboot required” flags as enforcement

Generic reboot-required indicators are intentionally excluded, as they do **not** correspond to enforced Update Orchestrator restarts.

---

## Why This Exists

Windows Update pause:
- stops downloads and new offers
- does **not** stop servicing enforcement

Hidden servicing updates can:
- survive multiple reboots
- remain invisible in the Windows Update UI
- later be enforced by `MoUsoCoreWorker.exe` after a deadline

This tool makes that otherwise opaque state explicit.

---

## Usage

Run as **Administrator**:

```
windows_hidden_restart_exposer.bat
```

### Menu

```
1) Check for updates and expose hidden planned restarts
2) Check ONLY for hidden planned restart enforcement
```

---

## Output Interpretation

### Normal reboot required
User-controlled. Windows will wait for the user to reboot.

### Hidden planned restart detected
A servicing update is already installed and Windows **may enforce a restart**:
- after pause expiry (if updates are paused)
- outside active hours or when enforcement conditions are met (if not paused)

---

## Limitations

This tool reflects current Windows 11 servicing behavior.
Microsoft may change Update Orchestrator or MoUSO enforcement logic in future releases.

---

## Supported Systems

- Windows 11 (Home / Pro / Enterprise)
- Retail (non-Insider) builds
