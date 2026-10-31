# Android TV verification — 1.0.0

## Artifact and identity

- APK: `dist/1.0.0/AudioSubsReaderTV-1.0.0-android6-armeabi-v7a.apk`
- Size: **16,719,260 bytes**.
- SHA256: `b2444b636169bb1909afa43a9849ea04c0f7b81a8475b35abc37fb4053283645`.
- Package: `com.audiosubs.audiosubs_reader.tv`; versionName **1.0.0**, versionCode **1**.
- Effective minSDK **23**, target/compile SDK **35**.
- APK was built from the pinned source toolchain, not modified from the incompatible mobile release.
- `aapt dump badging` reports only `armeabi-v7a`, the TV label, and the Leanback launch activity.
- APK contains complete little-endian **ELF32 ARM** `libapp.so` (6,292,052 bytes) and `libflutter.so` (8,011,552 bytes). The Android plugins are Kotlin/Java, not extra ABI-specific JNI payloads.
- `llvm-readelf` reported the engine's DT_NEEDED libraries: libc, libdl, libm, libandroid, libEGL, libGLESv2, liblog and libjnigraphics. No mandatory Vulkan/ARM64 library dependency was present.
- `apksigner verify --verbose --print-certs --min-sdk-version 23` verified **v1/JAR and v2** signatures. RSA3072 certificate SHA256: `bf92148223e94287e64f3bb390f0ff7a4726620cbb22b18c32fa4d7babfaffed`.
- Apksigner's standard unsigned META-INF metadata warnings remain visible; they were not suppressed. Android6 uses v1; newer Android can verify v2's whole-APK protection.
- The installed `/data/app/.../base.apk` was pulled back and matched the final release SHA256 exactly.

## Actual device

Owner's Xiaomi L50M5-AD / **MiTV4-ANSM0**, device **xmen**, Android **6.0.1 / API23**, build **22.11.18.3386**. `armeabi-v7a,armeabi`; 32-bit userspace. Native `wm` reported **1920×1080**, density **320**. No 4K override was applied.

ADB used an isolated server on **5038**, not another application's 5037 server. Only the owner's known endpoint was connected; no network/device scan. Individual Xiaomi installation confirmations were requested from the owner. No UIAutomator, app_process/Java diagnostic probes, root, reboot, factory mode, HOME-default change, app disabling, VPN/profile/routing or security-service changes were used.

## Exercised scenarios

A small, locally synthesized public-domain excerpt from Kenneth Grahame's *The Wind in the Willows* was packaged with two PCM audio files, headings, bold/italic runs, unspoken paragraphs and deliberate unaligned intervals. Final source package was about 751 KB; its transfer was verified byte-for-byte. No private book was used or uploaded.

| Check | Observed result |
|---|---|
| Install and genuine launch | Release installed; native `am start -W` launched the actual Flutter reader on API23. Later signed updates retained its library/settings. |
| Clean launcher | Distinct AudioSubs Reader TV banner appeared in `com.gathin.tvhome`; D-pad Down and OK launched it. Stock Xiaomi HOME remained unchanged and was reached using Home. |
| Remote-only import | Open → Browse Download → Android6 runtime permission → selected test subfolder → `.abook` → reader, using D-pad/OK only. No touch/mouse/keyboard input. |
| System document picker | ACTION_OPEN_DOCUMENT opened Cx's PickerActivity. It was cancelled without capturing private document lists. Actual provider-copy import through Cx was **not** independently completed; Download import is the proven route. |
| Audible playback | Owner explicitly confirmed narration from TV speakers and reasonably synchronized highlighting. Native output plus moving source clocks/word highlights were observed, not merely the Dart playing flag. |
| Formatting/following | Original heading, bold and italic text remained; active words and phrases followed narration. Manual page scrolling paused following; Resume following restored it. |
| Unaligned intervals | Trailing silence cleared highlighting and displayed no aligned text rather than retaining a stale highlighted phrase. |
| Seeking/clocks | Whole-book and current-file clocks selected remotely; focused slider seek worked. Up/Down could leave the slider after the port fix. ±15 controls crossed from first file into second and back while paused. |
| Track/chapter navigation | Both remote dialogs opened; selection changed the actual file/chapter and position. Natural playback advanced to the second file and retained the end clock on completion. |
| Speed | 0.5×, 1×, 1.25× and 2× selections exercised. At 2×, screenshots showed about nine source seconds of progress over 4.501 wall seconds; not inferred solely from a saved label or AudioTrack's internal rate field. |
| Appearance | Dark theme, serif font, size 29, Full width, independent bold, gold background and phrase range selected with the remote. The font slider was left using Down. Exact RGB/button behavior also has regression coverage. |
| Fullscreen | Read / Hide controls produced book-only fullscreen. OK revealed controls; focused controls stayed visible past the hide interval. Back first exited fullscreen, then saved/returned to the library. |
| Persistence | Force-stop/relaunch retained book position, speed, font/theme/size/width and bold/color/range choices. |
| Home interruption | Active playback → Home released the TV app's native audio focus. Returning stayed paused until explicit Play. Exiting the reader returned to the library and released focus. |
| Standby/wake | Power metadata observed Asleep/OFF and Awake/ON. A later standby disconnected network ADB; the owner woke the TV with its remote. Xiaomi recreated the activity; reopening the book retained position/settings and was paused. Explicit Play worked after wake. This is **not** a claim of continuous background playback or seamless activity survival. |
| Safety | TV left at the library with reader playback stopped. No existing application was uninstalled or disabled. |

Remote operations used standard ADB-injected D-pad/OK/Back/Home events, plus the owner's physical install/wake confirmations and audible/synchronization observation. No touchscreen taps were used.

## Storage and memory observations

| Measurement | Observed value / limit |
|---|---|
| OS MemTotal | **1,663,152 KiB**, approximately 1.59 GiB, shared with other services/apps. |
| Initial MemAvailable | **874,648 KiB**; a point-in-time OS estimate, not reserved app capacity. |
| Initial free `/data` | **835.5 MiB**; immediately before first installation **821.6 MiB**. |
| Free `/data` after first install/import | About **774.4 / 773.3 MiB**. |
| Later free `/data`, after standby/system activity | **846.8 MiB**. OS/service/cache changes confound before/after differences; no storage-saving claim is made. |
| Visible installed directory | `du` reported **16,344 KiB** but denied access to `oat`; this is a **lower bound**, not total installed/private-data size. |
| Final APK | **16,719,260 bytes**; matching installed APK hash verified. |
| App process PSS samples | **49,553–61,965 KiB** during the short session. Final active-playback sample **55,629 KiB** (~54.3 MiB); GL mtrack **21,124 KiB** is already part of the total. |

These are observations, not peak-memory bounds, long-book benchmarks or fabricated improvement percentages. No largeHeap, system-service disabling or destructive disk-fill test was used. Actual full-storage rejection/partial cleanup is covered by deterministic extraction tests; a real TV out-of-space condition was not deliberately created.

## Checks and compatibility fixes

Pinned Flutter/Dart analysis of `lib test` is clean; **49 tests passed**. Coverage includes timing boundaries, formatting/contrast/bold persistence, whole-book arithmetic, extraction safety and low-space failures, abandoned-import recovery, remote import/back navigation, stale-route interruption listeners, fullscreen/back handling, exact RGB changes and the TV slider focus-trap regression.

The real-device session exposed issues not proven by compilation: stock sliders consumed vertical traversal keys, opaque focus tint obscured labels, and file preparation moved playback focus to unrelated controls. An initial playback attempt showed a playing icon without useful displayed-time advancement. The native plugin now explicitly starts MediaPlayer instead of depending solely on playback-parameter side effects; subsequent real playback progressed and the owner confirmed sound/following. [INFERENCE] OEM parameter/start behavior contributed, but that causal diagnosis was not isolated conclusively. In particular, the initial numeric AudioTrack state was not evidence that it was stopped. Final proof relies on moving clocks/highlights and the owner's audible observation, not the playing flag or an assumed native-state enum.

A failed test initially deadlocked by mixing widget-test fake timers with file persistence. Its interaction ran in the real async zone afterward; it passes without changing application persistence semantics. A mock-echo forwarding test was removed rather than counted as useful behavioral coverage.

## Remaining proof limits

- Short public-domain PCM fixture only: no entire multi-hour/private audiobook, huge manifest, all codec combinations, low-memory-kill endurance or sustained performance guarantee.
- Generic native focus-loss/duck/noisy handling is implemented, but no separate competing-app duck/noisy hardware scenario was isolated; active Home/window interruption and standby recovery were observed.
- Word/phrase rendering exercised on TV; sentence expansion is retained and regression-tested. Not every preset/font/color value was individually selected on physical hardware.
- Cx document-provider import/copy is not claimed proven; its picker was opened/cancelled, while the fallback Download route completed end to end.
- No boot startup/background-playback promise; Xiaomi may recreate/kill the activity in standby. The policy is pause/save and explicit resume.
- Android6 remains a legacy OS. This fork does not update firmware or provide current upstream Flutter/Android security support.

Raw owned-book screenshots and native reports are kept locally under ignored `.verification/`, not published with private device/account data. Reproduce the APK inspection with `scripts/verify_tv_apk.ps1`; build pins, remote mapping, import, signing/update and safe removal instructions are in README.md.
