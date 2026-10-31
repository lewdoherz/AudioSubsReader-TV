# Changelog

## 1.0.0 — Android TV fork

- Separate AudioSubs Reader TV application (`com.audiosubs.audiosubs_reader.tv`), Leanback launcher/banner, landscape layout and no touchscreen requirement.
- Project-scoped Flutter3.32.8/Dart3.8.1/JDK17, pinned Gradle8.12/AGP8.7.3/Kotlin2.1.0 and API23 ARMv7 AOT release with stable private signing and v1/v2 verification.
- Native remote-operated Download browser plus content-provider picker/copy. Bounded file streams, current free-space checks/reserve, partial-import recovery and existing package safety preserved.
- High-contrast remote focus, focusable reading page, remote lists/appearance/exact RGB, non-trapping sliders and stable playback focus across file preparation.
- Fullscreen reveal/explicit Hide controls and fullscreen-first Back; no Home interception or boot/background service.
- Original ebook emphasis, highlighting ranges, independent bold/color, width/font/theme, all clocks/jumps/chapters/tracks/speed/resume and automatic following retained.
- Explicit Android MediaPlayer start in versioned MIT-licensed native plugin; native-owned audio focus and pause/save without automatic interruption recovery.
- Clock-only updates do not rebuild the ebook page. No transcription/translation/desktop runtime remains in the TV working tree or APK.
- Real Xiaomi xmen/API23 exercise, owner-confirmed audible/synchronized output, 49 passing tests and measured APK/memory/storage evidence. See VERIFICATION.md for exact coverage and limits.
