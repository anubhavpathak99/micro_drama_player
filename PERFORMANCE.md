# Performance audit

Profiled in profile mode on a **OnePlus CPH2569**:

- Snapdragon SM7325 with an Adreno 642L GPU
- Android 15, 7.5 GB RAM
- 1080×2412 screen at 480 dpi, refreshing at 60, 90 or 120 Hz

Software: Flutter 3.47.4, Impeller.

Two facts about this phone shape the numbers:

- **Impeller renders through OpenGL ES here.** It loads the Adreno Vulkan driver, then falls back. On GLES, every offscreen layer costs an extra full render pass. Offscreen layers include blurs, shadows and opacity over a group.
- **The app runs at about 60 fps on this phone.** The brief's 16 ms budget is the jank threshold used below.

## How it was measured

Everything is scripted and repeatable. Each script drives the real app, with real players and real Ad Manager test ads.

| What | Script | Mode |
|---|---|---|
| Frame timings per interaction, then memory over 3 full feed passes | `integration_test/perf_test.dart` | profile |
| Widget rebuilds per interaction | `integration_test/rebuild_audit_test.dart` | debug |
| Timelines of what a slow frame did | `integration_test/trace_test.dart` | profile |
| Six separately timed scrubs (used for an A/B) | `integration_test/scrub_probe_test.dart` | profile |

```sh
flutter drive --profile --no-dds --driver=test_driver/integration_test.dart \
  --target=integration_test/perf_test.dart -d <device-id>
# debug mode for the rebuild audit:
flutter drive --no-dds --driver=test_driver/integration_test.dart \
  --target=integration_test/rebuild_audit_test.dart -d <device-id>
```

Results land in `build/integration_response_data.json`. The interactions are:

- **Idle playback:** 5 s on a playing episode.
- **Swipe:** 4 swipes down the feed, across the first ad, then 4 back.
- **Scrub:** one scrub forward, then one back.
- **Double tap:** a double tap and two combo taps, until the hearts fade.
- **Paywall:** swiping onto locked E7, its entrance, and one shimmer of the Unlock button.

Frame timings come from `watchPerformance`, which reads the engine's `FrameTiming`. Rebuilds are counted with `debugOnRebuildDirtyWidget`, the hook behind DevTools' rebuild tracker.

**Methodology note.** On this phone the same build varies from run to run. Some runs have a whole interaction with every frame's raster time pinned at about 16–17 ms (more under "Noise in the raw numbers"). So "after" figures are the **median of five runs**, and the appendix lists every run.

## Results

The UI thread was never the problem: no frame's build went over 16 ms in any run, and the worst was 12.6 ms. All the jank was raster, meaning GPU time.

Before is one warm run; after is the median of five.

| Interaction | Raster avg (ms) | Raster p99 (ms) | Worst raster (ms) | Frames > 16 ms |
|---|---|---|---|---|
| Idle playback | 3.9 → 4.2 | 6.8 → 6.2 | 7.0 → 10.2 | 0 → 0 |
| Swipe | 3.5 → 3.5 | 9.4 → 10.2 | 13.8 → 18.9 | 0 → 2 |
| Scrub | 5.3 → 5.3 | 23.6 → **16.4** | 50.0 → **23.3** | 4 → 3 |
| Double tap | 8.8 → **7.5** | 15.7 → **12.2** | 16.7 → 17.2 | 1 → 1 |
| Paywall | 7.1 → **5.0** | 26.6 → **9.7** | 46.5 → **16.8** | 13 → **1** |

The cleanest after run (`final` in the appendix) is closer to what the code itself costs:

- **Double tap:** 4.6 ms average, worst 8.9 ms, nothing over 16 ms.
- **Paywall:** 5.0 ms average, p99 9.7 ms.

### 1. Paywall: a full-screen blur every frame

**Before:** 13 frames over 16 ms, worst 46.5 ms. The cold-cache run's worst paywall frame was 174.6 ms.

**Cause:** the overlay blurred the page behind it with a `BackdropFilter`, sigma 20, over the whole screen.

- It was clipped with a `ClipRect`, but the clip is the full page.
- So it re-blurred the entire screen on every frame of the entrance and of every Unlock-button shimmer.

**Fix:** behind a locked episode there is only its poster, which is static. So the poster is now blurred once and faded in ([blurred_poster.dart](lib/presentation/shared/blurred_poster.dart)):

- It's decoded at 64 px wide and blurred on the CPU in a background isolate ([box_blur.dart](lib/core/imaging/box_blur.dart), unit-tested).
- Each frame it is then a single texture.
- The dark scrim and the blurred poster fade separately. Each fade covers one draw, so neither needs an offscreen layer.

**After:** p99 26.6 → 9.7 ms. Frames over 16 ms went from 13 to 0 or 1 in four of five runs; the fifth was a pinned run (see "Noise in the raw numbers").

**Visible difference:** the blur now crossfades in instead of growing from sigma 0. At the speed of the entrance it reads the same.

### 2. Double tap: a live shadow per heart, every frame

**Before:** raster averaged 8.8 ms while hearts were on screen.

**Cause:** each heart was drawn as a path with `drawShadow` every frame, which is a blur pass per heart on GLES.

**Fix:** the heart (gradient plus shadow) and a white mini-heart are drawn once into sprite images. Every particle is then one textured quad, and sparks are tinted with a colour filter.

- The sprites are built when the first episode page appears, not on the first double tap.
- Building them on the first tap had cost that heart's first frame.

**After:** average 8.8 → 7.5 ms (median), and 4.6 ms in the clean run, with nothing over 16 ms.

### 3. Scrub: one fix, one residual

**Fixes:**

- **Thumb shadow:** the thumb's blurred shadow (a `MaskFilter` blur pass every frame it shows) is now a plain translucent halo.
- **Smooth-playhead ticker:** this repainted the progress bar every vsync during playback. Without it, the bar repaints only when the player reports its position, about every 100 ms, as the Phase 6 brief specified. Frame count during playback didn't change on this phone (about 60/s either way), because the video already drives that rate. On 30 fps video the ticker would have doubled the frames. The app now settles while a video plays, and `test/app_test.dart` checks that with `pumpAndSettle`.

**After:** p99 23.6 → 16.4 ms, worst 50 → 23 ms.

**Residual:** about one slow frame when a scrub starts.

- **The fade isn't the cause.** A probe of six scrubs with and without the chrome fade showed no difference: worst frames averaged 14.0 and 16.3 ms, with 2 frames over budget in each case.
- **Seeking is the likely cause.** The slow frames land when the player pauses and makes its first seek, while the decoder produces a frame at the new position.
- **No cheap seek is available.** video_player exposes no keyframe-only seek.

### 4. Swipe and idle playback: unchanged

None of the changes touches swiping's raster path.

- **Swipe:** both before runs had no frame over 16 ms. The five after runs had 2, 0, 3, 0 and 2. The average stayed at 3.5 ms.
- **Idle playback:** stayed at about 4 ms raster, with zero widget rebuilds.

### 5. Rebuilds

| Interaction | Before | After | What changed |
|---|---|---|---|
| Idle playback (5 s) | 0 | 0 | Playback rebuilds nothing. |
| Swipe (8 swipes) | 1066 | 574 | The episode page builds its poster, overlay, rail and paywall once, so a player arriving rebuilds only what shows it. The ad's platform-view widget is built once per ad. |
| Scrub | 619 | 311 | The feed's page delegate is built once per item list, so the physics swap at scrub start and end no longer rebuilds every cached page. |
| Double tap | 69 | 67 | The rest is the rail heart's spring, which is one `ScaleTransition` per frame. |
| Paywall | 437 | 353 | The backdrop no longer rebuilds per frame. |

The swipe and scrub fixes are pinned by widget tests: `a player arriving rebuilds only what shows it` and `a scrub starting or ending leaves the pages alone`.

### 6. Memory and disposal

Players and ads are logged as they're created and disposed ([lifecycle_log.dart](lib/core/diagnostics/lifecycle_log.dart); debug and profile builds only), for example:

```
[lifecycle] player+ ep-04 (live 2, created 4)
[lifecycle] player- ep-03 (live 1, created 4)
[lifecycle] ad+ ad#2 (live 2, created 2)
```

Three full passes over the whole feed (all 10 episodes and both ad slots, with E7 unlocked), in the final run:

| | Before passes | After pass 1 | After pass 2 | After pass 3 |
|---|---|---|---|---|
| Process RSS (MB) | 328.6 | 334.4 | 359.6 | 346.3 |
| Image cache (MB) | 31.6 | 35.2 | 35.2 | 35.2 |
| Live players / ads | 2 / 1 | 2 / 2 | 2 / 2 | 2 / 2 |
| Created so far (players / ads) | 14 / 3 | 24 / 7 | 40 / 11 | 56 / 15 |

- **RSS is flat.** It wanders by ±25 MB with no upward trend, the same in all seven runs.
- **Live players stay at 3 or fewer.**
- **Ads are released.** 15 were created, and 13 had been released by the end. Each slot keeps one ad preloaded.

### 7. Posters and blur clipping

- **Posters:** decoded two pages either side of the current one. A widget test now covers this: `decodes posters up to two pages either side`.
- **BackdropFilter:** it was already clipped (`ClipRect`). That didn't help, because the clip was the whole page. The paywall now uses the pre-blurred poster, so the app has no `BackdropFilter` left.

## Noise in the raw numbers

In 3 of the 7 runs, one interaction had every frame's raster time pinned at about 16–17 ms. It hit scrub, idle, double tap or paywall, with no pattern by code.

**It isn't app work:**

- **Little drawing.** Where a slow frame was traced, most of its time was in `SurfaceFrame::Submit` after a short encode: the raster thread waiting on the display's buffers, not drawing.
- **Same frame rate.** Frame counts stayed the same: 120 frames in the ~2 s double tap, about 60 fps.
- **Phone-side pattern.** It moved between interactions from run to run and appeared on a freshly cooled phone too. The phone's adaptive 60/90/120 Hz switching and GPU clock ramps are the likely triggers.

**Heat matters too:** after about an hour of back-to-back runs the phone reported light thermal throttling (CPU cores 64–74 °C). The final runs were taken after it cooled to about 41 °C.

## Appendix: every run

Each cell gives raster average, p99 and worst (all ms), then frames over 16 ms, then the total frame count.

| Run | Idle playback | Swipe | Scrub | Double tap | Paywall |
|---|---|---|---|---|---|
| before (cold cache) | 4.4 / 7.1 / 8.4 / 0 / 301 | 3.3 / 8.3 / 14.2 / 0 / 579 | 4.5 / 21.9 / 31.2 / 4 / 193 | 6.6 / 13.5 / 17.2 / 1 / 118 | 7.2 / 19.0 / 174.6 / 7 / 240 |
| before | 3.9 / 6.8 / 7.0 / 0 / 308 | 3.5 / 9.4 / 13.8 / 0 / 575 | 5.3 / 23.6 / 50.0 / 4 / 199 | 8.8 / 15.7 / 16.7 / 1 / 112 | 7.1 / 26.6 / 46.5 / 13 / 246 |
| after1 | 4.2 / 9.2 / 13.0 / 0 / 308 | 3.5 / 11.2 / 18.9 / 2 / 565 | 4.2 / 16.4 / 57.1 / 3 / 191 | 6.0 / 12.2 / 17.2 / 1 / 119 | 4.8 / 9.3 / 15.0 / 0 / 256 |
| after2 | 2.9 / 6.2 / 7.2 / 0 / 301 | 3.6 / 10.2 / 12.3 / 0 / 575 | 5.3 / 17.0 / 21.3 / 3 / 194 | 7.5 / 16.6 / 19.0 / 2 / 112 | 4.6 / 10.9 / 15.4 / 0 / 250 |
| after3 | 4.3 / 6.2 / 10.2 / 0 / 301 | 3.6 / 11.5 / 22.3 / 3 / 572 | 11.1 / 20.0 / 60.6 / 69 / 200 | 7.5 / 11.3 / 16.6 / 1 / 113 | 5.0 / 8.3 / 16.8 / 1 / 254 |
| final | 16.1 / 19.8 / 31.3 / 234 / 303 | 3.1 / 9.4 / 14.0 / 0 / 572 | 4.0 / 13.1 / 22.7 / 1 / 194 | 4.6 / 8.1 / 8.9 / 0 / 112 | 5.0 / 9.7 / 22.1 / 1 / 249 |
| final2 | 3.6 / 6.1 / 7.0 / 0 / 301 | 3.5 / 9.9 / 24.3 / 2 / 570 | 5.5 / 13.6 / 23.3 / 2 / 196 | 16.4 / 21.1 / 22.3 / 79 / 120 | 15.3 / 20.2 / 34.8 / 132 / 245 |

Runs after1–3 predate moving the heart sprites to page build; final and final2 include it.
