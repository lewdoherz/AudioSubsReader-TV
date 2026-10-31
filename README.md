# AudioSubs Reader TV

Remote-first, ebook-first audiobook player for Android TV, including the 32-bit Android 6 Xiaomi xmen platform. Based on [AudioSubs Reader 0.5.0](https://github.com/lewdoherz/AudioSubsReader/releases/tag/v0.5.0); the Windows/mobile project and its published releases are separate and unchanged.

**Player only.** Import desktop-prepared `.abook` packages, read the original ebook formatting, and follow timed narration. No Python, transcription/model runtime, CUDA, translation, cloud processing, Google Play Services, background server, boot launcher or accessibility/device-admin service is included.

## Identity and target

- Display name: **AudioSubs Reader TV**.
- Application ID: `com.audiosubs.audiosubs_reader.tv`; coexists with `com.audiosubs.audiosubs_reader`.
- Version: **1.0.0**, versionCode **1**.
- Release target: **android-arm / armeabi-v7a**, effective minSDK **23**, compile/target SDK **35**.
- Rendering: **Skia/OpenGL**, using the pinned engine's supported `EnableImpeller=false` manifest option. No forced 4K resolution or `largeHeap`.
- Device verification and measured limitations: [VERIFICATION.md](VERIFICATION.md).

## Remote controls

No mouse, touch, hardware keyboard or long-press is required.

| Context | Remote action |
|---|---|
| Library, dialogs, menus, controls | D-pad moves focus; OK activates; Back closes or returns. Focus is visibly outlined/tinted. |
| Focused reading page | Up/Down scrolls manually and pauses following. Left selects Chapters; Right selects Play/Pause. OK selects Read page / Hide controls. |
| Focused seek slider | Left/Right seeks in five-second increments; Up/Down leaves the slider. Direction keys elsewhere do not seek. |
| Appearance font slider | Left/Right adjusts one size step; Up/Down leaves it. Separate minus/plus buttons are also available. |
| Chapter/track dialog | Up/Down selects; OK opens; Back cancels. Long lists remain lazy. |
| Fullscreen with hidden controls | OK or Left/Right reveals controls without activating a button. Menu also requests controls where delivered by the remote/firmware. |
| Fullscreen controls visible | Focused controls stay visible. Activate **Read / Hide controls** to return to the page and hide chrome. |
| Back in fullscreen | First exits fullscreen, retaining the reader. A subsequent Back saves progress and returns to the library. |
| Home | Not intercepted. Backgrounding pauses playback; returning never auto-resumes it. |

Allow the loading indicator to finish when changing files. Playback actions are serialized. **Play/Pause**, previous/next file, track list, chapters, speed, whole-book/current-file clocks, ±15-second jumps across files, word/phrase/sentence highlighting and Resume following remain available.

Appearance retains light/dark/system themes; bundled serif/sans/mono fonts and original emphasis; **14–64** book sizes (default **28**); Standard/Wide/Full width; colored background/underline/text or no added color; independent bold; preset/custom colors. Exact RGB ±1/±16 controls avoid requiring a keyboard. Default reading width is Wide.

## Import and storage

1. Prepare a `.abook` with the separate Windows application. The format is unchanged.
2. Copy it to the TV's **Download** folder or a subfolder using your chosen file-transfer method.
3. Choose **Open reading book → Browse Download folder**. Allow Android6 storage access when explicitly requested. Navigate with D-pad and OK; Back ascends a folder, then cancels at Download.
4. Alternatively choose **System document picker**. Content URIs are read through Android's `ContentResolver`, not converted into filesystem paths. If no provider exists, the app reports the Download alternative. Provider/Cx-specific proof limits are recorded in VERIFICATION.md.

Only the selected Download subtree is enumerated, on demand. No unrestricted background storage scanning, root, Shizuku, MANAGE_EXTERNAL_STORAGE or network server is required. Android6 describes READ_EXTERNAL_STORAGE broadly as photos/media/files; this is its legacy runtime permission, not an additional Android11 permission.

**Budget space before copying/importing:** Download already contains the compressed source; import adds the expanded book. A document provider also needs a temporary compressed copy while extracting. Actual free app-storage space is checked before copying and extraction, with a **64 MiB reserve**. Streaming copy uses a 64-KiB buffer; ZIP extraction runs off the UI thread using file streams. Source files are not overwritten or deleted. Failed/abandoned import staging is removed; existing books and per-book progress remain intact.

Unsafe paths, links, case-folding collisions, duplicate entries, invalid alignment, missing media and imported playback-state files remain rejected. The existing limits are 100,000 entries, 64 GiB declared expanded package size and 64 MiB manifest size; the TV's actual storage/RAM is much smaller. Prefer books that fit comfortably with the reserve. Do not use the numerical format limits as capacity estimates.

On this old ADB implementation, replacing a larger file with a smaller one was observed to leave trailing bytes. Use a **new destination filename** when transferring a revised package, or remove only your own previous copy first. Byte-for-byte validation was used for the public-domain device fixture.

## Reproducible scoped build (Windows x64)

Required externally: Git, PowerShell, curl, and an Android SDK containing platform **35**, build-tools **35.0.0**, NDK **28.2.13676358**, and platform-tools. Install/accept Android SDK components yourself if missing; scripts do not accept vendor terms on your behalf.

From this repository:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap_tv.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/init_tv_signing.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build_android.ps1 -Check
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify_tv_apk.ps1 -Apk dist/1.0.0/AudioSubsReaderTV-1.0.0-android6-armeabi-v7a.apk
```

Pass `-AndroidSdk C:/path/to/sdk` to bootstrap/build/verification when needed. `build_android.ps1` uses `flutter build apk --release --no-pub --target-platform android-arm --split-per-abi`, never the global Flutter executable. It enforces `pubspec.lock`, optionally runs format/analysis/tests, verifies Android23 signing, and writes the named APK plus `SHA256SUMS.txt` into `dist/<version>/`.

Pins are recorded in [toolchain.lock.json](toolchain.lock.json), Gradle files and `pubspec.lock`:

| Component | Pin / decision |
|---|---|
| Flutter / Dart | **3.32.8 / 3.8.1**, framework `edada7c56edf4a183c1735310e123c7f923584f1`, engine `ef0cd000916d64fa0c5d09cc809fa7ad244a5767` |
| Host Java | Temurin **17.0.17+10**, downloaded with a fixed official SHA256; Java/JVM bytecode target 17 |
| Gradle / AGP / Kotlin | **8.12 / 8.7.3 / 2.1.0**; Gradle distribution checksum pinned |
| Desugaring | `desugar_jdk_libs` **2.1.4** |
| audioplayers | **6.5.1**, Dart >=3.6 / Flutter >=3.27 compatible |
| Android audio implementation | Vendored **5.2.1+tv.1**, upstream minSDK19, pure Kotlin/Java; explicit native `MediaPlayer.start()` after playback-parameter setup |
| path_provider / Android implementation | **2.1.5 / 2.2.17**, native minSDK21, no ABI-specific JNI payload |
| archive / path / positioned list | **4.0.7 / 1.9.1 / 0.3.8**, compatible Dart constraints; file-backed ZIP handling retained |
| file_picker | Removed. Native API23 document APIs plus the remote Download browser replace the incompatible modern plugin. |

Official compatibility evidence: [3.32.8 Android extension](https://github.com/flutter/flutter/blob/3.32.8/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt), [engine API21 manifest](https://github.com/flutter/flutter/blob/3.32.8/engine/src/flutter/shell/platform/android/AndroidManifest.xml), [android-arm/ARMv7 mapping](https://github.com/flutter/flutter/blob/3.32.8/packages/flutter_tools/lib/src/build_info.dart), [supported renderer setting](https://github.com/flutter/flutter/blob/3.32.8/engine/src/flutter/shell/platform/android/io/flutter/embedding/engine/loader/FlutterLoader.java). Flutter3.35.7 was rejected after its official extension declared minSDK24. A lone ARMv7 JNI library in an otherwise ARM64 APK is not sufficient; verification checks complete ELF32 ARM `libapp.so` and `libflutter.so`.

SDK/JDK/pub caches live under ignored `.toolchains`. Flutter's Windows APPDATA-based configuration is scoped there so Android Studio's Java25 cannot override this JDK17. Gradle's cache is isolated by a hash of this checkout path under `%LOCALAPPDATA%/AudioSubsReaderTV/gradle-cache`, outside source indexing to avoid observed Windows immutable-workspace locks. No global toolchain is downgraded. Bootstrap corrects a literal `$git` typo in the upstream Windows wrapper's revision lookup; Android engine/compiler sources remain unchanged.

## Audio/lifecycle policy

One native audio-focus owner requests focus only on explicit Play. Loss, transient loss, duck requests, noisy output, window-focus loss and backgrounding pause/save without auto-resume. Seek and track advancement reuse the active session. Back/exit stops and releases playback. Returning from Home or standby requires explicit Play. There is no background service, automatic boot launch or promise of Xiaomi background reliability.

The vendored Android audio source is included with its original [MIT licence](third_party/audioplayers_android/LICENSE). `start()` explicitly starts the MediaPlayer after setting rate instead of depending solely on OEM playback-parameter side effects. The device smoke procedure checks advancing clocks and audible output, not just the Dart `playing` state.

## Signing, updates and removal

`init_tv_signing.ps1` creates/reuses a private RSA3072 identity outside Git, normally `%USERPROFILE%/.audiosubs-reader-tv/`. Passwords are random, not printed, and saved with the keystore in that restricted directory. **Back up the whole directory securely.** Set `AUDIOSUBS_TV_SIGNING_PROPERTIES` to another private properties file if necessary. Never commit/upload signing material.

Release builds require this identity; there is no debug-signing fallback. Both **v1/JAR** (Android6) and **v2** signatures are enabled. Apksigner's META-INF/version/service metadata warnings are retained in inspection output; the verified v2 signature covers the whole APK, while Android6 uses the standard v1 scheme. No store publication/signing is configured.

For updates, retain application ID, key and ARMv7 target, increase `pubspec.yaml` version/build number, and install over the existing TV package. Xiaomi may ask for individual installation confirmation; leave **Apply to all** unchecked unless you deliberately want to change that policy. Losing the key prevents in-place upgrades. Never uninstall just to work around signing without first accepting that local books/resume/settings will be deleted.

Safe recovery: Back out of the reader first to save; force-stop **only** `com.audiosubs.audiosubs_reader.tv` if needed, then reopen. Uninstall **AudioSubs Reader TV** through Settings or `adb -P 5038 -s <TV-endpoint> uninstall com.audiosubs.audiosubs_reader.tv` only when you intend to delete its private data. Download source packages and other apps are separate. Do not clear data, alter HOME defaults, disable the stock launcher/security/VPN services, root, flash, reboot or factory-reset as a repair step.
