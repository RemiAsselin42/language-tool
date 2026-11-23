# language-tool

Self-hosted [LanguageTool](https://github.com/languagetool-org/languagetool) server running natively on Windows (no Docker), started automatically the first time [Zen Browser](https://zen-browser.app/) is launched after login.

**Why:** the official LanguageTool browser extension went Premium-only, but it still works with a self-hosted server — for free, with full privacy (text never leaves the machine).

## How it works

- At login, a Startup shortcut runs `lt-watch.js` (Windows Script Host), which starts `lt-watch.bat` with no window; it waits (near-zero cost) until `zen.exe` appears.
- It then calls `lt-up.bat`, which starts the LanguageTool server as a background `javaw` process (port 8081, localhost only), and exits. The server keeps running until logout, also after Zen is closed; nothing restarts it if it is killed before the next login (run `lt-up.bat` by hand).
- The browser extension is set to **Local server** and talks to `http://localhost:8081/v2`.
- Language detection: `fasttext/fasttext.exe` (MSVC build, committed) + the quantized `lid.176.ftz` model (<1 MB, committed) — near-identical accuracy to the full 130 MB model.

**Footprint:** one `javaw` process, ~400-500 MB RAM (`-Xmx512m`, serial GC), idle CPU ≈ 0%. Roughly 3x lighter than the previous Docker Desktop + WSL2 setup.

## Setup (new machine)

1. **Run the setup script** from the repo root (safe to re-run):
```powershell
   powershell -ExecutionPolicy Bypass -File setup.ps1
```
   It does, in order:
   - installs Java 21 (Temurin JRE, via winget) if the Java on the PATH is missing or older than 17;
   - downloads [LanguageTool-stable.zip](https://languagetool.org/download/LanguageTool-stable.zip) and unpacks it, flattened, into `server/` (skipped if `server/languagetool-server.jar` exists; an interrupted run is simply redone);
   - writes `server.properties` with this clone's absolute fastText paths;
   - puts a `lt-watch` shortcut in the Startup folder (auto-start at login);
   - starts the server and checks that <http://localhost:8081/v2/languages> answers — if it doesn't, it reruns the server in the foreground so the error is visible.

   The repo path may contain accents, but only characters of the Windows ANSI code page (on a Western European Windows, no Cyrillic, CJK, etc.): Java and fastText cannot open anything else, so the script refuses such a folder up front.

2. **Configure the extension:** LanguageTool add-on options → server section → check **Local server**. No URL to type (8081 is the port the extension expects).

## Tuning

JVM flags live in `lt-up.bat`: `-Xms128m -Xmx512m -XX:+UseSerialGC`.
512 MB heap is enough for everyday email/docs in 2 languages. If very long texts fail or slow down noticeably (OutOfMemory in the logs), raise to `-Xmx768m`.

## Troubleshooting

- **Restart everything:** `powershell -ExecutionPolicy Bypass -File reset.ps1` asks Zen to close (like clicking the X of each window, never forced — it stops there if Zen stays open), kills the LanguageTool `javaw` process, re-runs `setup.ps1` to start and check the server, then reopens Zen. If Zen isn't running, only the server is restarted.
- **Server won't start / detection seems off:** run it in a visible console:
```powershell
  java -cp ".\server\languagetool-server.jar" org.languagetool.server.HTTPServer --port 8081 --allow-origin --config ".\server.properties"
```
  Expect `Started fastText process for language identification` (pointing at the `.ftz`) and `Server started`.
- **Changes to `lt-up.bat` don't seem to apply:** the old server is probably still running — `lt-up.bat` is idempotent and won't replace it. Check with:
```powershell
  Get-CimInstance Win32_Process -Filter "name='javaw.exe'" | Select -Expand CommandLine
```
  then run `reset.ps1`.
- **Moved or renamed the repo folder:** `server.properties` and the Startup shortcut hold absolute paths, and the server refuses to start on a wrong fastText path — re-run `setup.ps1`.
- **`ClassNotFoundException`:** you're not running from the repo root, or `server/` is incomplete — delete `server/` and re-run `setup.ps1`.
- **Poor language detection:** a wrong path in `server.properties` is not the cause — it stops the server from starting at all (see the first point). To rule out the quantized model, try the full one: download `lid.176.bin` from <https://dl.fbaipublicfiles.com/fasttext/supervised-models/lid.176.bin> and point `fasttextModel` at it (+130 MB RAM), then restart the server. Note that re-running `setup.ps1` rewrites `server.properties`.
- **Stop the server manually:** `taskkill /f /im javaw.exe` (careful if other Java apps are running).
- **`fasttext.exe` on a new architecture (ARM etc.):** recompile from [facebookresearch/fastText](https://github.com/facebookresearch/fastText) — with MSVC: `cl /O2 /EHsc /std:c++17 /Fe:fasttext.exe src\*.cc` from a *x64 Native Tools Command Prompt* (the CMake build's `fasttext-bin` target is broken on Windows: it links against `pthread`).

## Repo contents

| File | Role |
|---|---|
| `setup.ps1` | One-shot setup: Java, server download, `server.properties`, Startup shortcut, verification |
| `reset.ps1` | Restarts the server and Zen (Zen is closed politely, never killed) |
| `lt-watch.js` / `lt-watch.bat` | Invisible login watcher — starts the server when Zen appears |
| `lt-up.bat` | Starts the server (idempotent: exits if already running) — JVM flags live here |
| `fasttext/fasttext.exe` | Language detection binary (committed, Windows x64) |
| `fasttext/lid.176.ftz` | Quantized language-ID model (committed) |
| `fasttext/LICENSE` | fastText's MIT licence (covers `fasttext.exe`) |
| `server/`, `server.properties` | Local-only, gitignored — created by `setup.ps1` |

## Third-party components

This repo redistributes two files from [fastText](https://github.com/facebookresearch/fastText):

- `fasttext/fasttext.exe` — built from the fastText sources. MIT License, Copyright (c) 2016-present, Facebook, Inc. (full text in `fasttext/LICENSE`).
- `fasttext/lid.176.ftz` — the official [language identification model](https://fasttext.cc/docs/en/language-identification.html), unmodified, distributed under the [Creative Commons Attribution-Share-Alike License 3.0](https://creativecommons.org/licenses/by-sa/3.0/).

LanguageTool itself is not redistributed: `setup.ps1` downloads it from languagetool.org.
