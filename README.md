# languagetool-local

Self-hosted [LanguageTool](https://github.com/languagetool-org/languagetool) server running natively on Windows (no Docker), with automatic startup whenever [Zen Browser](https://zen-browser.app/) is launched.

**Why:** the official LanguageTool browser extension went Premium-only, but it still works with a self-hosted server — for free, with full privacy (text never leaves the machine).

## How it works

- `lt-watch.vbs` runs invisibly at login and waits (near-zero cost) until `zen.exe` appears.
- It then calls `lt-up.bat`, which starts the LanguageTool server as a background `javaw` process (port 8081, localhost only).
- The browser extension is set to **Local server** and talks to `http://localhost:8081/v2`.
- Language detection: `fasttext/fasttext.exe` (MSVC build, committed) + the quantized `lid.176.ftz` model (<1 MB, committed) — near-identical accuracy to the full 130 MB model.

**Footprint:** one `javaw` process, ~400-500 MB RAM (`-Xmx512m`, serial GC), idle CPU ≈ 0%. Roughly 3x lighter than the previous Docker Desktop + WSL2 setup.

## Setup (new machine)

Everything needed is in the repo except Java, the LanguageTool zip, and one local config file:

1. **Install Java 21:**
```powershell
   winget install -e --id EclipseAdoptium.Temurin.21.JRE
```

2. **Get the LanguageTool server:** download
   <https://languagetool.org/download/LanguageTool-stable.zip>
   and unzip its *contents* directly into `server/` — the jar must end up at
   `server/languagetool-server.jar` (flatten the extra `LanguageTool-x.y/` folder the zip creates).

3. **Create `server.properties`** at the repo root (gitignored — absolute local paths, escaped backslashes):
```properties
   fasttextBinary=C:\\path\\to\\languagetool-local\\fasttext\\fasttext.exe
   fasttextModel=C:\\path\\to\\languagetool-local\\fasttext\\lid.176.ftz
```

4. **Enable auto-start:** `Win+R` → `shell:startup` → drop a shortcut to `lt-watch.vbs` there.

5. **Configure the extension:** LanguageTool add-on options → server section → check **Local server**. No URL to type (8081 is the port the extension expects).

6. **Verify:** launch Zen, wait a few seconds, open <http://localhost:8081/v2/languages> — a JSON list of languages means everything works.

## Tuning

JVM flags live in `lt-up.bat`: `-Xms128m -Xmx512m -XX:+UseSerialGC`.
512 MB heap is enough for everyday email/docs in 2 languages. If very long texts fail or slow down noticeably (OutOfMemory in the logs), raise to `-Xmx768m`.

## Troubleshooting

- **Server won't start / detection seems off:** run it in a visible console:
```powershell
  java -cp ".\server\languagetool-server.jar" org.languagetool.server.HTTPServer --port 8081 --allow-origin --config ".\server.properties"
```
  Expect `Started fastText process for language identification` (pointing at the `.ftz`) and `Server started`.
- **Changes to `lt-up.bat` don't seem to apply:** the old server is probably still running — `lt-up.bat` is idempotent and won't replace it. Check with:
```powershell
  Get-CimInstance Win32_Process -Filter "name='javaw.exe'" | Select -Expand CommandLine
```
  then `taskkill /f /im javaw.exe` and relaunch.
- **`ClassNotFoundException`:** you're not running from the repo root, or the zip wasn't flattened into `server/` (step 2).
- **Poor language detection:** fastText isn't loading — check the paths in `server.properties`. As a fallback, the full model works too: download `lid.176.bin` from <https://dl.fbaipublicfiles.com/fasttext/supervised-models/lid.176.bin> and point `fasttextModel` at it (+130 MB RAM).
- **Stop the server manually:** `taskkill /f /im javaw.exe` (careful if other Java apps are running).
- **`fasttext.exe` on a new architecture (ARM etc.):** recompile from [facebookresearch/fastText](https://github.com/facebookresearch/fastText) — with MSVC: `cl /O2 /EHsc /std:c++17 /Fe:fasttext.exe src\*.cc` from a *x64 Native Tools Command Prompt* (the CMake build's `fasttext-bin` target is broken on Windows: it links against `pthread`).

## Repo contents

| File | Role |
|---|---|
| `lt-watch.vbs` / `lt-watch.bat` | Invisible login watcher — starts the server when Zen appears |
| `lt-up.bat` | Starts the server (idempotent: exits if already running) — JVM flags live here |
| `fasttext/fasttext.exe` | Language detection binary (committed, Windows x64) |
| `fasttext/lid.176.ftz` | Quantized language-ID model (committed) |
| `server/`, `server.properties` | Local-only, gitignored |
