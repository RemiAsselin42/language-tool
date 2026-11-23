# One-shot setup for a new machine (or after moving the repo). Safe to re-run.
#   powershell -ExecutionPolicy Bypass -File setup.ps1
param([switch]$KeepBrowsers)   # reuse the saved browser selection instead of asking (reset.ps1 passes it)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

# 0. java.exe and fasttext.exe cannot open paths with characters outside the Windows ANSI code page
$ansi = [Text.Encoding]::GetEncoding([int](Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage').ACP)
if ($ansi.GetString($ansi.GetBytes($root)) -ne $root) {
    throw "Java and fastText cannot run from this folder: its path has characters outside this Windows' code page ($($ansi.CodePage)). Move the repo to a plain path such as C:\tools\language-tool and re-run."
}

# Browser selection, asked first so the rest can run unattended. The watcher starts the server when one of the
# selected browsers opens: browsers.txt holds their process names, one per line.
$pages = @()
if (-not ($KeepBrowsers -and (Test-Path "$root\browsers.txt"))) {
    # LanguageTool extension ids: Firefox Add-ons, Chrome Web Store, Edge Add-ons
    $gecko = 'languagetool-webextension@languagetool.org'
    $chrome = 'oldceeleldhonbafppcapldpdifcinji'
    $edge = 'hfjadhjooeceemgojogkhlppanjkbobc'
    $saved = @(Get-Content "$root\browsers.txt" -ErrorAction SilentlyContinue)

    # Every browser registered with Windows, minus Internet Explorer (no extension exists for it)
    $browsers = @('HKLM:\SOFTWARE', 'HKLM:\SOFTWARE\WOW6432Node', 'HKCU:\SOFTWARE' | ForEach-Object {
        Get-ChildItem "$_\Clients\StartMenuInternet" -ErrorAction SilentlyContinue | ForEach-Object {
            $cmd = (Get-ItemProperty -LiteralPath "$($_.PSPath)\shell\open\command" -ErrorAction SilentlyContinue).'(default)'
            $exe = if ("$cmd" -match '^"?([^"]+?\.exe)') { $Matches[1] }
            if ($exe -and $exe -notlike '*iexplore*' -and (Test-Path -LiteralPath $exe)) {
                $dir = Split-Path $exe
                $ini = Join-Path $dir 'application.ini'
                if (Test-Path -LiteralPath $ini) {
                    # Firefox family: profiles are in %APPDATA%\<Profile>, or <Vendor>\<Name> when application.ini names no Profile
                    $app = @{}
                    foreach ($line in Get-Content -LiteralPath $ini) {
                        if ($line -match '^(Vendor|Name|Profile)=(.+)' -and -not $app[$Matches[1]]) { $app[$Matches[1]] = $Matches[2] }
                    }
                    $profiles = if ($app.Profile) { $app.Profile } else { (@($app.Vendor, $app.Name) | Where-Object { $_ }) -join '\' }
                    $has = Test-Path "$env:APPDATA\$profiles\Profiles\*\extensions\$gecko.xpi"
                    $page = 'https://addons.mozilla.org/firefox/addon/languagetool/'
                }
                else {
                    # Chromium family: <vendor>\<product>\Application\x.exe keeps its profiles in %LOCALAPPDATA%\<vendor>\<product>\User Data
                    $parts = (Split-Path $dir).Split('\')
                    $data = "$env:LOCALAPPDATA\$($parts[-2])\$($parts[-1])\User Data", "$env:LOCALAPPDATA\$($parts[-1])\User Data" |
                        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
                    # $null = unknown: profiles not where expected (Opera, portable builds...)
                    $has = if ($data) { [bool](Test-Path "$data\*\Extensions\$chrome", "$data\*\Extensions\$edge" | Where-Object { $_ }) }
                    $page = if ($exe -like '*\msedge.exe') { "https://microsoftedge.microsoft.com/addons/detail/$edge" } else { "https://chromewebstore.google.com/detail/$chrome" }
                }
                $image = Split-Path $exe -Leaf
                $name = (Get-ItemProperty -LiteralPath $_.PSPath).'(default)'
                [pscustomobject]@{
                    Name = if ($name) { $name } else { $_.PSChildName }
                    Exe = $exe; Image = $image; Has = $has; Page = $page
                    Default = if ($saved) { $saved -contains $image } else { $has -eq $true }
                }
            }
        }
    } | Sort-Object Exe -Unique | Sort-Object Name)
    if (-not $browsers) { throw 'No browser found on this computer.' }

    Write-Host "`nBrowsers found on this computer:"
    for ($i = 0; $i -lt $browsers.Count; $i++) {
        $b = $browsers[$i]
        $state = if ($b.Has) { 'installed' } elseif ($null -eq $b.Has) { 'unknown' } else { 'not installed' }
        Write-Host ('  [{0}] {1}. {2,-22} LanguageTool extension: {3}' -f $(if ($b.Default) { 'x' } else { ' ' }), ($i + 1), $b.Name, $state)
    }
    $answer = Read-Host 'Browsers to use LanguageTool in - numbers separated by commas, or Enter to keep the [x] ones'
    $chosen = if ("$answer".Trim()) {
        @("$answer" -split '\D+' | Where-Object { $_ -and [int]$_ -ge 1 -and [int]$_ -le $browsers.Count } | ForEach-Object { $browsers[[int]$_ - 1] } | Sort-Object Exe -Unique)
    }
    else { @($browsers | Where-Object { $_.Default }) }
    if (-not $chosen) { throw 'No browser selected.' }
    [IO.File]::WriteAllLines("$root\browsers.txt", [string[]]@($chosen.Image | Select-Object -Unique), [Text.Encoding]::ASCII)
    Write-Host ('Selected: ' + ($chosen.Name -join ', ') + "`n")
    $pages = @($chosen | Where-Object { -not $_.Has })
}

# 1. Java 17+ (installs Temurin 21 when the java on the PATH is missing or older)
function Get-JavaMajor {
    if (-not (Get-Command javaw -ErrorAction SilentlyContinue)) { return 0 }
    # java prints its version on stderr; Java 8 reports "1.8", which is rightly below 17
    if ((cmd /c 'java -version 2>&1' | Out-String) -match 'version "(\d+)') { return [int]$Matches[1] }
    return 0
}
if ((Get-JavaMajor) -lt 17) {
    winget install -e --id EclipseAdoptium.Temurin.21.JRE --accept-source-agreements --accept-package-agreements
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    if ((Get-JavaMajor) -lt 17) {
        throw 'Java 17+ is still not the first java on the PATH: the winget install failed, or an older Java comes before it. Fix the PATH and re-run.'
    }
}

# 2. LanguageTool server, flattened into server\ (the zip wraps everything in LanguageTool-x.y\).
#    Unpacked into server.tmp\ and renamed at the end, so an interrupted run never leaves a half-filled server\.
if (-not (Test-Path "$root\server\languagetool-server.jar")) {
    $zip = "$env:TEMP\LanguageTool-stable.zip"
    curl.exe -fL -o $zip https://languagetool.org/download/LanguageTool-stable.zip
    if ($LASTEXITCODE) { throw 'LanguageTool download failed' }
    foreach ($d in "$root\server.tmp", "$root\server") { if (Test-Path $d) { Remove-Item $d -Recurse -Force } }
    New-Item -ItemType Directory "$root\server.tmp" | Out-Null
    & "$env:SystemRoot\System32\tar.exe" -xf $zip -C "$root\server.tmp" --strip-components=1
    if ($LASTEXITCODE) { throw 'LanguageTool unzip failed' }
    Rename-Item "$root\server.tmp" server
    Remove-Item $zip
}

# 3. server.properties: absolute paths, backslashes doubled, non-ASCII as \uXXXX (read the same whatever the encoding)
$ft = [regex]::Replace("$root\fasttext".Replace('\', '\\'), '[^\x20-\x7E]', { param($m) '\u{0:x4}' -f [int][char]$m.Value })
[IO.File]::WriteAllText("$root\server.properties",
    "fasttextBinary=$ft\\fasttext.exe`nfasttextModel=$ft\\lid.176.ftz`n",
    [Text.Encoding]::ASCII)

# 4. Auto-start at login. wscript and its engine are named explicitly, so a re-associated .js extension cannot break it
$lnk = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Startup') + '\lt-watch.lnk')
$lnk.TargetPath = "$env:SystemRoot\System32\wscript.exe"
$lnk.Arguments = "//B //E:JScript `"$root\lt-watch.js`""
$lnk.Save()

# 5. Start now and verify (javaw hides startup errors, so on failure rerun in the foreground)
cmd /c "`"$root\lt-up.bat`""
curl.exe -sf -o NUL --retry 30 --retry-delay 2 --retry-connrefused http://localhost:8081/v2/languages
if ($LASTEXITCODE) {
    Write-Host 'Server did not answer on port 8081. Running it in the foreground to show why:' -ForegroundColor Red
    java -cp "$root\server\languagetool-server.jar" org.languagetool.server.HTTPServer --port 8081 --allow-origin --config "$root\server.properties"
    exit 1
}
Write-Host 'OK: LanguageTool answers on http://localhost:8081/v2 - now set the browser extension to "Local server".' -ForegroundColor Green

# 6. Selected browsers that lack the extension: open its store page in each
foreach ($b in $pages) {
    Write-Host "Opening the LanguageTool extension page in $($b.Name)..."
    Start-Process -FilePath $b.Exe -ArgumentList $b.Page
}
