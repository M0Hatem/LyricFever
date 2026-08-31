# Design Specification: Apple Music Fullscreen Player & Queue for LyricFever

**Date:** 2026-08-31  
**Target:** macOS (Apple Silicon & Intel)  
**Status:** Approved by user  

---

## 1. Overview & Objective
Transform LyricFever's fullscreen view into an exact visual and behavioral match of **Apple Music's Full Screen Player**, supporting two core states plus an added Queue panel:
- **State A (Artwork Only / Lyrics Off)**: Centered artwork with soft shadow, timeline scrubber directly below, single minimal control row, clean aesthetic with idle metadata reveal.
- **State B (Lyrics On)**: Artwork smoothly docks to the left (~40% width), full-height left-aligned synced lyrics right.
- **State C (Queue Panel - Addition)**: Artwork remains docked left, slide-in "Up Next" queue panel on the right.

---

## 2. Core Architecture & State Machine

### 2.1 FullscreenPanelState
```swift
enum FullscreenPanelState: String, CaseIterable, Equatable {
    case none    // State A: Centered artwork, timeline, controls
    case lyrics  // State B: Docked left, synced lyrics right
    case queue   // State C: Docked left, up-next queue right
}
```

### 2.2 Shared Spring Layout Animation
- Artwork is a single persistent view whose frame, corner radius, and shadow animate seamlessly with `.spring(response: 0.4, dampingFraction: 0.82)`.
- No separate views swapped with fade cuts; artwork, timeline, and controls move in a single coordinated transaction.
- Panel switches (e.g. from `lyrics` to `queue`) transition directly without flickering through `none`.

### 2.3 Idle Engine & Metadata Display
- Monitored by a dedicated idle coordinator tracking mouse movement and keyboard input.
- **After 3.0 seconds of idle** (suppressed while hovering controls or scrubbing):
  - Control bar and timeline fade out (0.35s ease-out).
  - Cursor is hidden using `NSCursor.setHiddenUntilMouseMoves(true)`.
  - Song title + artist text smoothly fades in below the artwork / bottom-center.
- Any mouse movement immediately restores the controls/timeline and hides the idle title/artist label.

---

## 3. Ambient Background Engine

### 3.1 Pipeline
1. **Artwork Input**: Downsampled to 512×512 texture, boosted saturation.
2. **Layered Stack**: 4 copies at 25%, 50%, 80%, 125% viewport width. Two largest rotate in place; two smallest rotate and orbit on circular tracks.
3. **Metal Twist Distortion**:
   ```metal
   float2 twist(float2 coord, float2 offset, float radius, float angle) {
       coord -= offset;
       float dist = length(coord);
       if (dist < radius) {
           float ratioDist = (radius - dist) / radius;
           float angleMod = ratioDist * ratioDist * angle;
           float s = sin(angleMod);
           float c = cos(angleMod);
           coord = float2(coord.x * c - coord.y * s, coord.x * s + coord.y * c);
       }
       coord += offset;
       return coord;
   }
   ```
4. **Heavy Gaussian Blur & Composite**: Heavy blur with subtle darkening vignette for contrast.
5. **Frame Pacing & Power**: Frame rate capped at 15–30 fps, freezes on pause, low power on battery, respects `accessibilityDisplayShouldReduceMotion`.

---

## 4. Control Bar, Timeline & Shortcuts HUD

### 4.1 Timeline Scrubber (`FullscreenTimelineView`)
- Positioned directly below artwork in all states.
- Format: `[Elapsed Time] ───●─────────── [-Remaining Time]`.
- Thin subtle pill track; circular thumb reveals on hover/drag.
- Smooth scrubbing bound to `currentTime` / `duration` and calls `player.seek(to:)` on release.

### 4.2 Control Bar (`FullscreenControlsView`)
- Single-row layout:
  - **Left**: `···` (More menu: Volume slider, Translation toggle, Fullscreen options).
  - **Center**: `⏮` (Rewind / restart if >3s), `⏯` (Play/Pause), `⏭` (Next track).
  - **Right**: `💬` (Lyrics toggle; disabled if no timed lyrics), `☰` (Queue toggle; hidden if unsupported).

### 4.3 Shortcuts Overlay HUD
- Triggerable via `?` or `⌘/` (or via `···` menu).
- Dark frosted glass modal showing keybindings:
  - `Space`: Play / Pause
  - `←` / `→`: Seek 5s backward / forward
  - `⌘←` / `⌘→`: Previous / Next track
  - `↑` / `↓`: Volume up / down
  - `L` / `H`: Toggle Lyrics
  - `Q`: Toggle Queue
  - `T`: Toggle Translation
  - `?`: Shortcuts HUD
  - `Esc`: Exit Fullscreen

---

## 5. Lyrics & Queue Subsystems

### 5.1 Synced Lyrics (`LyricsNSScrollView`)
- Apple Music typography (large, bold, left-aligned, scales with window height).
- Current line full white (1.0 opacity); past/upcoming lines dimmed (0.45–0.65) with progressive blur.
- Active line anchored at ~40% from top with spring easing.
- Click-to-seek on any line calls `player.seek(to:)`.
- 3-dot pulse animation during instrumental breaks.

### 5.2 Up-Next Queue (`QueueView` & `SpotifyQueueService`)
- Lightweight Spotify Web API OAuth PKCE (`GET /v1/me/player/queue`).
- Row design: 48pt height, rounded artwork thumbnail, track name, artist, duration / playing indicator.
- Click-to-play sends playback command.
- Apple Music: `supportsQueue` flag hides the queue button when unavailable via ScriptingBridge.

---

## 6. Player Protocol Extensions
- `Player.swift`:
  ```swift
  func seek(to seconds: Double)
  var supportsQueue: Bool { get }
  ```
- Implemented in `SpotifyPlayer.swift` and `AppleMusicPlayer.swift` using `setPlayerPosition`.
