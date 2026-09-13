# languagetool-local

Self-hosted [LanguageTool](https://github.com/languagetool-org/languagetool) server running natively on Windows (no Docker), with automatic startup whenever [Zen Browser](https://zen-browser.app/) is launched.

**Why:** the official LanguageTool browser extension went Premium-only, but it still works with a self-hosted server — for free, with full privacy (text never leaves the machine).

## How it works

- `lt-watch.vbs` runs invisibly at login and waits (near-zero cost) until `zen.exe` appears.
- It then calls `lt-up.bat`, which starts the LanguageTool server as a background `javaw` process (~1 GB RAM, port 8081, localhost only).
- The browser extension is set to **Local server** and talks to `http://localhost:8081/v2`.
- `fasttext/fasttext.exe` (compiled with MSVC, committed in this repo) + the `lid.176.bin` model provide accurate automatic language detection.

## Setup (new machine)

1. **Install Java 21:**
```powershell
   winget install -e --id EclipseAdoptium.Temurin.21.JRE
```

2. **Get the LanguageTool server:** download
   <https://languagetool.org/download/LanguageTool-stable.zip>
   and unzip its *contents* directly into `server/` — the jar must end up at
   `server/languagetool-server.jar` (flatten the extra `LanguageTool-x.y/` folder the zip creates).

3. **Download the fastText language-identification model** (~130 MB, gitignored):
```powershell
   curl.exe -L -o fasttext/lid.176.bin https://dl.fbaipublicfiles.com/fasttext/supervised-models/lid.176.bin
```

4. **Create `server.properties`** at the repo root (gitignored — absolute local paths, escaped backslashes):
```properties
   fasttextBinary=C:\\path\\to\\languagetool-local\\fasttext\\fasttext.exe
   fasttextModel=C:\\path\\to\\languagetool-local\\fasttext\\lid.176.bin
```

5. **Enable auto-start:** `Win+R` → `shell:startup` → drop a shortcut to `lt-watch.vbs` there.

6. **Configure the extension:** LanguageTool add-on options → server section → check **Local server**. No URL to type (8081 is the port the extension expects).

7. **Verify:** launch Zen, wait a few seconds, open <http://localhost:8081/v2/languages> — a JSON list of languages means everything works.

## Troubleshooting

- **Server won't start:** run it in a visible console to see the logs:
```powershell
  java -cp ".\server\languagetool-server.jar" org.languagetool.server.HTTPServer --port 8081 --allow-origin --config ".\server.properties"
```
  Look for `Started fastText process for language identification` and `Server started`.
- **`ClassNotFoundException`:** you're not running from the repo root, or the zip wasn't flattened into `server/` (step 2).
- **Poor language detection:** fastText isn't loading — check the paths in `server.properties`.
- **Stop the server manually:** `taskkill /f /im javaw.exe` (careful if other Java apps are running).
- **`fasttext.exe` on a new architecture (ARM etc.):** recompile from [facebookresearch/fastText](https://github.com/facebookresearch/fastText) — with MSVC: `cl /O2 /EHsc /std:c++17 /Fe:fasttext.exe src\*.cc` from a *x64 Native Tools Command Prompt* (the CMake build's `fasttext-bin` target is broken on Windows: it links against `pthread`).

## Repo contents

| File | Role |
|---|---|
| `lt-watch.vbs` / `lt-watch.bat` | Invisible login watcher — starts the server when Zen appears |
| `lt-up.bat` | Starts the server (idempotent: exits if already running) |
| `fasttext/fasttext.exe` | Language detection binary (committed, Windows x64) |
| `server/`, `fasttext/lid.176.bin`, `server.properties` | Local-only, gitignored |
