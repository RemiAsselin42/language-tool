# Restarts everything: closes Zen (politely), kills and restarts the LanguageTool server, reopens Zen.
#   powershell -ExecutionPolicy Bypass -File reset.ps1
$ErrorActionPreference = 'Stop'

# 1. Ask Zen to close, the same way as clicking the X of each window - never forced
$zen = (Get-Process zen -ErrorAction SilentlyContinue | Select-Object -First 1).Path
if ($zen) {
    cmd /c 'taskkill /IM zen.exe >nul 2>&1'
    Wait-Process -Name zen -Timeout 30 -ErrorAction SilentlyContinue
    if (Get-Process zen -ErrorAction SilentlyContinue) {
        throw 'Zen did not close (it is probably waiting for an answer to a dialog). Close it yourself and re-run.'
    }
}

try {
    # 2. Stop the LanguageTool server. It has no window and no shutdown command, so this one is a kill (it holds no state)
    Get-CimInstance Win32_Process -Filter "Name='javaw.exe' and CommandLine like '%languagetool-server.jar%'" |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force; Wait-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }

    # 3. Start it again through setup.ps1, which also repairs the config and checks that the server answers
    & "$PSScriptRoot\setup.ps1" -KeepBrowsers
}
finally {
    # 4. Reopen Zen, also when the server failed to start
    if ($zen) { Start-Process $zen }
}
exit $LASTEXITCODE
