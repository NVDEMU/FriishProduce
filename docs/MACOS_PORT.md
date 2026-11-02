# macOS port status

This document records the actual migration boundary for FriishProduce. The Windows application must keep working while the macOS frontend and toolchain are brought up.

## Current application constraints

The existing `FriishProduce.csproj` targets .NET Framework 4.8 and is a Windows Forms/WPF desktop application. It depends on Windows-only controls and dialogs throughout `MainForm`, `ProjectForm`, and the platform option forms. Re-targeting that project to a modern .NET runtime does not make its UI portable.

The injection code is reusable in principle, but it is not yet a clean cross-platform library:

- `Method` and the Wii VC injectors use application globals for configuration, translations, paths, and logging.
- `ImageHelper` uses `System.Drawing` APIs. Microsoft documents `System.Drawing.Common` as Windows-only on modern .NET, so this needs a SkiaSharp/Avalonia-compatible implementation rather than a runtime switch.
- The project references a prebuilt `libWiiSharp.dll`. The macOS application needs a source-built, modern-targeted library or an audited replacement.
- Helper programs are currently Windows PE executables embedded through `FileDatas.Apps`: `wwcxtool`, `lzh8_cmp`, `lzh8_cmp_nonstrict`, `lzh8_dec`, `romc`, `romc0`, `gbalzss`, `flips`, `xdelta3`, `c1541`, `sns_boost`, and `OpenDolBoot`. macOS must receive native signed binaries for every helper needed by the feature being used.
- The legacy updater extracts files beside the running executable and is not suitable for a sealed `.app` bundle. The new frontend must use a bundle-aware updater or disable self-updating until that exists.

## Portability groundwork already in this fork

- `Paths` now distinguishes the executable folder, the macOS bundle's `Contents/Resources` folder, and writable per-user data under `~/Library/Application Support/FriishProduce`.
- `PlatformServices` centralizes URL opening, folder opening, and file reveal operations for Windows, macOS, and Linux.
- `Utils.Run` no longer attempts to run an embedded Windows executable on macOS. It resolves a native helper by name from `Contents/Resources/tools/native/macos`, drains stdout/stderr concurrently, and reports the missing helper by name.
- The Windows release workflow now builds on pushes, pull requests, and manual dispatch; verifies and packages the complete build output; publishes a ZIP and SHA-256 checksum; and no longer depends on the optional VirusTotal output parsing step.

These changes are compatibility seams. They do **not** yet constitute a runnable macOS app: the WinForms/WPF UI and Windows helper binaries are still present in the legacy project.

## Required migration work

1. **Create the cross-platform desktop frontend.** Use Avalonia on modern .NET for the desktop UI. Rebuild the main project workflow, platform-specific settings, banner editor, controller mapping, database selection, and export screens. Keep the existing Windows Forms app as the Windows legacy frontend until the new frontend reaches feature parity.
2. **Extract the injection engine.** Move WAD/ROM manipulation into a UI-independent project. Replace direct reads of `Program.Config`, `Program.Lang`, and form state with injected configuration, localization, logging, and progress/cancellation interfaces.
3. **Modernize binary/image dependencies.** Rebuild or replace `libWiiSharp.dll` for a supported modern .NET target. Replace `ImageHelper`'s GDI+ operations with a cross-platform image implementation and verify generated TPL/banner output against known-good Windows output.
4. **Build native helper tools.** Add universal macOS helper executables (arm64 + x86_64) under `tools/native/macos`. Do not copy or rename Windows `.exe` files into this directory. Each helper needs a source, license/attribution, architecture check, and a known-input/known-output test. Some helpers can be built from portable sources (for example, Flips and xdelta); the remaining WWCX/LZH8/ROMC/LZSS/C64/forwarder helpers need their compatible source builds or in-process replacements.
5. **Add cross-platform tests.** Test WAD parsing/repacking, U8/CCF handling, each helper's supported command line, and representative NES/SNES/N64/SEGA/PCE/NeoGeo injections. Compare resulting WAD metadata and changed contents against known-good fixtures. Never ship a feature as supported only because the app window opens.
6. **Package the macOS release.** Publish self-contained `osx-arm64` and `osx-x64` builds, bundle resources under `Contents/Resources`, set executable permissions on native helpers, create a valid `.app`, then create the `.dmg`.

## Gatekeeper / release requirements

A DMG by itself does not make an app trusted by macOS. For normal first-launch behavior without the unidentified-developer / damaged-app blocks, the release app must be signed with a valid **Developer ID Application** identity, use the hardened runtime, be notarized by Apple, and have the returned ticket stapled to the app and DMG. The packager must fail closed when signing or notarization credentials are absent; it must never publish an unsigned prototype as a safe public release.

The repository now contains:

- `packaging/macos/FriishProduce.entitlements`: the hardened-runtime exceptions required by the non-Native-AOT .NET runtime.
- `packaging/macos/create-notarized-dmg.sh`: signs nested Mach-O tools and the app host, verifies the bundle, notarizes and staples both the app and DMG, runs Gatekeeper assessments, and writes a SHA-256 checksum. It accepts an already-built `.app`; it does not build the application or make the Windows Forms interface portable.

To prepare a signing runner, import a Developer ID Application certificate (`.p12`) into a temporary macOS keychain, configure its partition list for `codesign`, and create a notarytool keychain profile. Example profile creation using an App Store Connect API key:

```sh
xcrun notarytool store-credentials FriishProduceNotary \
  --key /path/to/AuthKey_ABC123.p8 \
  --key-id ABC123DEF4 \
  --issuer 00000000-0000-0000-0000-000000000000
```

Then run the packager with `APPLE_SIGNING_IDENTITY` set to the exact Developer ID Application identity and `APPLE_NOTARY_PROFILE=FriishProduceNotary`. Keep the certificate, private key, API key, and passwords in GitHub Actions secrets; never commit them to the repository.

A Developer ID certificate and Apple notarization access are required for the no-warning public release target. An unsigned or ad-hoc-signed DMG cannot be advertised as Gatekeeper-clean. The packager must run on macOS with Xcode Command Line Tools installed.

## Current status

- [x] Windows build/release workflow cleanup
- [ ] Verify a successful Windows Actions run (the fork currently reports zero workflow runs and zero releases)
- [x] App-bundle-aware resource paths
- [x] User-writable macOS data directory
- [x] Cross-platform shell integration boundary
- [x] Native macOS helper-tool resolution boundary
- [x] Fail-closed .app/DMG signing and notarization packager
- [x] .NET hardened-runtime entitlement manifest
- [ ] Modern cross-platform engine project
- [ ] Avalonia desktop frontend and feature parity
- [ ] Native macOS helper binaries and tests
- [ ] arm64 + x86_64 macOS app bundles
- [ ] Developer ID signing, notarization, and stapled DMG
- [ ] End-to-end macOS validation on a Gatekeeper-enabled Mac
