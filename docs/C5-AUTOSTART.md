# ChatpadBridge hidden startup and recovery

After the current package is installed and `ChatpadHidMaestroBroker` has been repaired, configure the current Windows user from a normal PowerShell window:

```powershell
& '<package>\ChatpadSetup.ps1' -Mode EnableAutostart
```

This writes one quoted launcher path to the current user's `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`. The launcher and runner execute from the protected `C:\Program Files\ChatpadBridge` directory. The launcher is a Windows GUI-subsystem process; it starts the console runner with `CREATE_NO_WINDOW`, supervises unexpected exits with capped backoff, and writes launcher diagnostics under `%LOCALAPPDATA%\ChatpadBridge\logs`.

The runner itself stays at normal user privilege. It opens the existing broker pipe before waiting for physical hardware, so the broker can report the latest resume epoch even if the runner was disconnected during sleep. On a wake event, the runner cancels session I/O, releases keyboard and virtual state, closes WinUSB, then reopens the physical target and requires a strict changing `00 14` report. The existing broker permits one fixed physical restart in an epoch. If that bounded attempt does not restore reports, the runner waits without holding the device or virtual lease until another broker resume epoch.

Manual controls from a normal user PowerShell window:

```powershell
& "$env:ProgramFiles\ChatpadBridge\ChatpadBridge.exe" start
& "$env:ProgramFiles\ChatpadBridge\ChatpadBridge.exe" stop
& '<package>\ChatpadSetup.ps1' -Mode AutostartStatus
& '<package>\ChatpadSetup.ps1' -Mode DisableAutostart
```

`start` launches the hidden supervisor. `stop` requests graceful cleanup and stops both the runner and supervisor. `DisableAutostart` removes only the current user's Run value. No tray icon is installed.

C5 remains partial until live verification confirms logon startup, hidden execution, resume notification, exact-target recovery, controller reports, Chatpad, XInput, rumble, and cleanup across the required sleep/wake cycles.
