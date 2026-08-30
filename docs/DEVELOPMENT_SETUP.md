---
summary: "Development setup: stable signing and reducing Keychain prompts."
read_when:
  - Setting up local development
  - Reducing Keychain prompts during rebuilds
  - Configuring dev signing
---

# Development Setup Guide

## Reducing Keychain Permission Prompts

When developing AgentBar, you may see frequent keychain permission prompts like:

> **AgentBar wants to access key "Claude Code-credentials" in your keychain.**

This happens because each rebuild creates a new code signature, and macOS treats it as a "different" app.
That can affect both AgentBar-owned entries (`com.vadikhq.AgentBar`, `com.vadikhq.agentbar.cache`) and
third-party items such as `Claude Code-credentials`, so an ad-hoc-signed rebuild can keep re-triggering
password/keychain approval dialogs even after you previously chose **Always Allow**.

### Quick Fix (Temporary)

When the prompt appears, click **"Always Allow"** instead of just "Allow". This grants access to the current build.

### Permanent Fix (Recommended)

Use a stable development certificate that doesn't change between rebuilds:

#### 1. Create Development Certificate

```bash
./Scripts/setup_dev_signing.sh
```

This creates a self-signed certificate named "AgentBar Development".

#### 2. Trust the Certificate

1. Open **Keychain Access.app**
2. Find **"AgentBar Development"** in the **login** keychain
3. Double-click it
4. Expand the **"Trust"** section
5. Set **"Code Signing"** to **"Always Trust"**
6. Close the window (enter your password when prompted)

#### 3. Configure Your Shell

Add this to your `~/.zshrc` (or `~/.bashrc` if using bash):

```bash
export APP_IDENTITY='AgentBar Development'
```

Then restart your terminal:

```bash
source ~/.zshrc
```

#### 4. Rebuild

```bash
./Scripts/compile_and_run.sh
```

Now your builds will use the stable certificate, and keychain prompts will be much less frequent!

> Note: `compile_and_run.sh` now auto-detects a valid signing identity (Developer ID or AgentBar Development).
> Set `APP_IDENTITY` to override the auto-detected choice.

---

## Cleaning Up Old App Bundles

If you see multiple `AgentBar *.app` bundles in your project directory, you can clean them up:

```bash
# Remove all numbered builds
rm -rf "AgentBar "*.app

# The .gitignore already excludes these patterns:
# - AgentBar.app
# - AgentBar *.app/
```

The build script creates `AgentBar.app` in the project root. Old numbered builds (like `AgentBar 2.app`) are created when Finder can't overwrite the running app.

---

## Development Workflow

### Standard Build & Run

```bash
./Scripts/compile_and_run.sh
```

This script:
1. Kills existing AgentBar instances
2. Runs `swift build` (release mode)
3. Runs the sharded full test suite when `--test` is passed
4. Packages the app with `./Scripts/package_app.sh`
5. Launches `AgentBar.app`
6. Verifies it stays running

Launching an unbundled `AgentBar` executable, including SwiftPM builds using `.build` or a custom scratch path, disables
Keychain access for that process to avoid repeated password prompts. Use the packaged `AgentBar.app` when local
validation needs browser cookies or stored credentials; packaged app bundles keep their normal Keychain behavior
regardless of signing mode.

When the script falls back to ad-hoc signing, it preserves AgentBar-owned keychain state by default.
That means you may still see keychain prompts for existing AgentBar cache entries, but allowing those prompts keeps the
cached browser/OAuth state available across normal rebuilds.
If you want a clean reset of AgentBar-owned keychain state for an ad-hoc build, run
`./Scripts/compile_and_run.sh --clear-adhoc-keychain` before relaunching.
Third-party keychain items still need stable signing if you want macOS to remember **Always Allow** across rebuilds.

### Quick Build (No Tests)

```bash
swift build -c release
./Scripts/package_app.sh
```

### Run Tests Only

```bash
make test
```

### Debug Build

```bash
swift build  # defaults to debug
./Scripts/package_app.sh debug
```

---

## Troubleshooting

### "AgentBar is already running"

The compile_and_run script should kill old instances, but if it doesn't:

```bash
pkill -x AgentBar || pkill -f AgentBar.app || true
```

### "Permission denied" when accessing keychain

Make sure you clicked **"Always Allow"** or set up the development certificate (see above).

### Multiple app bundles keep appearing

This happens when the running app locks the bundle. The compile_and_run script handles this by killing the app first.

If you still see old bundles:

```bash
rm -rf "AgentBar "*.app
```

### App doesn't reflect latest changes

Always rebuild and restart:

```bash
./Scripts/compile_and_run.sh
```

Or manually:

```bash
./Scripts/package_app.sh
pkill -x AgentBar || pkill -f AgentBar.app || true
open -n AgentBar.app
```
