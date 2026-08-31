# Apple Music Fullscreen Player & Queue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild LyricFever's fullscreen player to match Apple Music's Full Screen Player across all states (State A artwork-only, State B synced lyrics, State C up-next queue), with a fluid Metal twist-shader ambient background, timeline scrubber, idle auto-hide controls with metadata fade-in, shortcuts overlay HUD, and Spotify Web Queue integration.

**Architecture:** A modular SwiftUI + Metal architecture. The background is powered by a multi-layer twist distortion Metal shader engine; fullscreen states are governed by a single explicit `FullscreenPanelState` enum driving a shared spring layout transaction; playback controls and scrubbing communicate through an extended `Player` protocol (`seek(to:)`, `supportsQueue`); and the queue is powered by a dedicated OAuth PKCE `SpotifyQueueService`.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit / ScriptingBridge, Metal / MetalKit / MetalPerformanceShaders, URLSession (Spotify Web API PKCE).

## Global Constraints
- Target: macOS 14.0+ (Sonoma/Sequoia)
- License: Keep MIT license and all original copyright attributions intact.
- Backward Compatibility: Do not break existing Menubar or Karaoke floating windows (`ImageColorGeneration.swift` and ColorKit dependencies remain untouched).
- Background performance: Capped at 15–30 fps, freezes when playback is paused, respects `accessibilityDisplayShouldReduceMotion`.

---

### Task 0: Build Environment & MediaRemoteAdapter Dependency Pin

**Files:**
- Modify: `Lyric Fever.xcodeproj/project.pbxproj`
- Modify: `LyricFever/ViewModel.swift:25-30`

**Interfaces:**
- Consumes: SPM dependency `ejbills/mediaremote-adapter`
- Produces: Cleanly compiling project under Xcode 15/16

- [ ] **Step 1: Check project compilation error**
Run: `xcodebuild -scheme "Lyric Fever" -destination "platform=macOS" -dry-run build`

- [ ] **Step 2: Fix MediaController initialization in ViewModel.swift**
Update `LyricFever/ViewModel.swift` to initialize `MediaController` safely with the updated signature:
```swift
let musicController = MediaController()
```

- [ ] **Step 3: Verify clean build dry-run**
Run: `xcodebuild -scheme "Lyric Fever" -destination "platform=macOS" clean build -dry-run`
Expected: Build dry-run passes.

- [ ] **Step 4: Commit build fix**
```bash
git add LyricFever/ViewModel.swift "Lyric Fever.xcodeproj/project.pbxproj"
git commit -m "fix: resolve MediaController initialization and project build"
```

---

### Task 1: Player Protocol Extensions (`seek(to:)` & `supportsQueue`)

**Files:**
- Modify: `LyricFever/Players/Player.swift:30-47`
- Modify: `LyricFever/Players/Spotify/SpotifyPlayer.swift:85-115`
- Modify: `LyricFever/Players/AppleMusic/AppleMusicPlayer.swift:85-112`

**Interfaces:**
- Consumes: `SpotifyApplication.setPlayerPosition`, `MusicApplication.setPlayerPosition`
- Produces: `Player.seek(to: Double)` (seconds), `Player.supportsQueue: Bool`

- [ ] **Step 1: Extend `Player` protocol with `seek(to:)` and `supportsQueue`**
In `LyricFever/Players/Player.swift`:
```swift
protocol Player {
    // ... existing properties ...
    var supportsQueue: Bool { get }
    func seek(to seconds: Double)
}

extension Player {
    var supportsQueue: Bool { false }
}
```

- [ ] **Step 2: Implement seek and queue capability in SpotifyPlayer**
In `LyricFever/Players/Spotify/SpotifyPlayer.swift`:
```swift
var supportsQueue: Bool {
    return true
}

func seek(to seconds: Double) {
    spotifyScript?.setPlayerPosition?(seconds)
}
```

- [ ] **Step 3: Implement seek in AppleMusicPlayer**
In `LyricFever/Players/AppleMusic/AppleMusicPlayer.swift`:
```swift
var supportsQueue: Bool {
    return false
}

func seek(to seconds: Double) {
    appleMusicScript?.setPlayerPosition?(seconds)
}
```

- [ ] **Step 4: Commit Player protocol changes**
```bash
git add LyricFever/Players/
git commit -m "feat(player): add seek(to:) and supportsQueue to Player protocol"
```

---

### Task 2: Ambient Background Engine (Metal Twist Shader)

**Files:**
- Create: `LyricFever/Views/FullscreenView/BackgroundView/ArtworkFluid.metal`
- Create: `LyricFever/Views/FullscreenView/BackgroundView/ArtworkFluidBackgroundView.swift`
- Create: `LyricFever/Views/FullscreenView/BackgroundView/FullscreenBackgroundStyle.swift`
- Modify: `LyricFever/Views/FullscreenView/BackgroundView/BackgroundView.swift`

**Interfaces:**
- Consumes: `artworkImage: NSImage?`, `isPlaying: Bool`
- Produces: `ArtworkFluidBackgroundView`, `FullscreenBackgroundStyle` (`.fluidArtwork`, `.classicMesh`, `.solidColor`, `.off`)

- [ ] **Step 1: Create Metal Twist Shader `ArtworkFluid.metal`**
Implement the twist distortion kernel:
```metal
#include <metal_stdlib>
using namespace metal;

[[stitchable]] float2 twistDistortion(float2 position, float2 origin, float radius, float angle) {
    float2 coord = position - origin;
    float dist = length(coord);
    if (dist < radius && radius > 0.0) {
        float ratioDist = (radius - dist) / radius;
        float angleMod = ratioDist * ratioDist * angle;
        float s = sin(angleMod);
        float c = cos(angleMod);
        coord = float2(coord.x * c - coord.y * s, coord.x * s + coord.y * c);
    }
    return coord + origin;
}
```

- [ ] **Step 2: Create `FullscreenBackgroundStyle.swift`**
```swift
import Foundation

enum FullscreenBackgroundStyle: String, CaseIterable, Identifiable, Codable {
    case fluidArtwork = "Fluid Artwork"
    case classicMesh = "Classic Mesh"
    case solidColor = "Solid Color"
    case off = "Off"

    var id: String { rawValue }
}
```

- [ ] **Step 3: Create `ArtworkFluidBackgroundView.swift`**
Build the 4-layer stacked rotating and orbiting artwork composition with twist distortion, multi-pass gaussian blur, and vignette:
- 4 layers scaled at 25%, 50%, 80%, 125% of viewport width.
- Continuous slow rotation and orbiting coordinates updated on a 20fps timeline when `isPlaying` is true.
- Freezes when paused or when reduce-motion is active.
- Smooth 600ms crossfade on artwork image changes.

- [ ] **Step 4: Update `BackgroundView.swift` to support styles**
Connect `FullscreenBackgroundStyle` switching cleanly to render `ArtworkFluidBackgroundView`, `MulticolorGradient`, solid color, or black.

- [ ] **Step 5: Commit background engine**
```bash
git add LyricFever/Views/FullscreenView/BackgroundView/
git commit -m "feat(background): implement Apple Music fluid twist shader ambient background"
```

---

### Task 3: Fullscreen State Machine, Layout & Idle Coordinator

**Files:**
- Create: `LyricFever/Views/FullscreenView/FullscreenPanelState.swift`
- Create: `LyricFever/Views/FullscreenView/FullscreenIdleCoordinator.swift`
- Modify: `LyricFever/Views/FullscreenView/FullscreenView.swift`
- Modify: `LyricFever/ViewModel.swift`

**Interfaces:**
- Consumes: `ViewModel.artworkImage`, `ViewModel.isPlaying`, `ViewModel.currentlyPlayingLyrics`
- Produces: `FullscreenPanelState` (`.none`, `.lyrics`, `.queue`), dynamic docking spring layout, idle auto-hide state (`isControlsVisible`, `isIdleMetadataVisible`)

- [ ] **Step 1: Define `FullscreenPanelState.swift`**
```swift
import Foundation

enum FullscreenPanelState: String, CaseIterable, Equatable {
    case none
    case lyrics
    case queue
}
```

- [ ] **Step 2: Create `FullscreenIdleCoordinator.swift`**
Create an `@Observable` or `ObservableObject` idle timer:
- Tracks mouse movements and keypresses.
- Default 3.0s timer. On expiry: sets `isControlsVisible = false`, hides mouse cursor (`NSCursor.setHiddenUntilMouseMoves(true)`), sets `isIdleMetadataVisible = true`.
- On user activity or hover/drag: resets timer, sets `isControlsVisible = true`, sets `isIdleMetadataVisible = false`.

- [ ] **Step 3: Update `ViewModel.swift` with panel state**
Add `fullscreenPanelState: FullscreenPanelState = .none` to `ViewModel`.

- [ ] **Step 4: Rebuild `FullscreenView.swift` layout**
- Single artwork view that transitions between centered (700pt / 550pt) and docked left (~40% width) using `.spring(response: 0.4, dampingFraction: 0.82)`.
- Left-docked artwork houses the right-side dynamic content (`lyrics` or `queue`).
- Top/bottom idle metadata crossfade.

- [ ] **Step 5: Commit layout and state machine**
```bash
git add LyricFever/Views/FullscreenView/ LyricFever/ViewModel.swift
git commit -m "feat(fullscreen): implement FullscreenPanelState spring layout and idle coordinator"
```

---

### Task 4: Timeline Scrubber & Apple Music Control Bar

**Files:**
- Create: `LyricFever/Views/FullscreenView/FullscreenTimelineView.swift`
- Create: `LyricFever/Views/FullscreenView/FullscreenControlsView.swift`
- Modify: `LyricFever/Views/FullscreenView/FullscreenView.swift`

**Interfaces:**
- Consumes: `currentTime`, `duration`, `player.seek(to:)`, `player.togglePlayback()`, `player.rewind()`, `player.forward()`
- Produces: `FullscreenTimelineView` (scrubber pill + time labels), `FullscreenControlsView` (More menu, transport controls, lyrics & queue toggle buttons)

- [ ] **Step 1: Implement `FullscreenTimelineView.swift`**
- Formatted elapsed (`m:ss`) and remaining (`-m:ss`) text labels.
- Interactive drag scrubber pill with thumb revealing on hover.
- Binds to `viewmodel.currentTime` (interpolated) and triggers `viewmodel.currentPlayerInstance.seek(to:)` upon drag release.
- Reports scrubbing active state to suppress idle auto-hide.

- [ ] **Step 2: Implement `FullscreenControlsView.swift`**
- `···` More button: frosted popover with volume slider, translation toggle, and background style picker.
- Transport buttons: `⏮` (rewinds if >3s, else skips previous), `⏯` (play/pause with smooth icon morph), `⏭` (next track).
- Panel toggles: `💬` (lyrics toggle; disabled if no timed lyrics), `☰` (queue toggle; hidden if `!player.supportsQueue`).
- Apple Music glyph sizes, weights, and subtle active glow states.

- [ ] **Step 3: Integrate into `FullscreenView.swift`**
Position timeline directly below artwork, and controls bar below timeline.

- [ ] **Step 4: Commit timeline and controls**
```bash
git add LyricFever/Views/FullscreenView/FullscreenTimelineView.swift LyricFever/Views/FullscreenView/FullscreenControlsView.swift LyricFever/Views/FullscreenView/FullscreenView.swift
git commit -m "feat(fullscreen): add Apple Music timeline scrubber and controls bar"
```

---

### Task 5: Shortcuts Overlay HUD & Keyboard Navigation

**Files:**
- Create: `LyricFever/Views/FullscreenView/FullscreenShortcutsOverlayView.swift`
- Modify: `LyricFever/Views/FullscreenView/FullscreenView.swift`

**Interfaces:**
- Consumes: Key equivalents (`Space`, `←`, `→`, `⌘←`, `⌘→`, `↑`, `↓`, `L`, `H`, `Q`, `T`, `A`, `?`, `Esc`)
- Produces: Centered frosted-glass HUD cheat-sheet when `?` or `⌘/` is pressed

- [ ] **Step 1: Implement `FullscreenShortcutsOverlayView.swift`**
- Frosted glass HUD modal with semi-transparent dark background.
- Clean 2-column grid showing keycaps and localized action descriptions.
- Closes on click or pressing any key.

- [ ] **Step 2: Add keyboard shortcut handlers to `FullscreenView.swift`**
- `Space`: `viewmodel.currentPlayerInstance.togglePlayback()`
- `←` / `→`: seek -5s / +5s
- `⌘←` / `⌘→`: previous / next track
- `↑` / `↓`: volume up / down
- `L` / `H`: toggle `.lyrics` panel
- `Q`: toggle `.queue` panel
- `T`: toggle translation
- `A`: toggle animation
- `?` or `⌘/`: toggle `showShortcutsHUD`
- `Esc`: dismiss fullscreen

- [ ] **Step 3: Commit shortcuts overlay**
```bash
git add LyricFever/Views/FullscreenView/FullscreenShortcutsOverlayView.swift LyricFever/Views/FullscreenView/FullscreenView.swift
git commit -m "feat(fullscreen): implement shortcuts overlay HUD and keyboard navigation"
```

---

### Task 6: Lyrics Typography & Interactive Polish

**Files:**
- Modify: `LyricFever/Views/FullscreenView/LyricsNSScrollView.swift`

**Interfaces:**
- Consumes: `currentlyPlayingLyrics`, `currentlyPlayingLyricsIndex`, `player.seek(to:)`
- Produces: Scaled Apple Music typography, active line anchoring (~40%), click-to-seek, 3-dot instrumental gap pulse

- [ ] **Step 1: Update typography in `LyricsNSScrollView.swift`**
- Dynamic font sizing based on window height (e.g. 36–48pt bold/heavy).
- Left-aligned layout with active line full white (opacity 1.0) and inactive lines dimmed (0.50).
- Progressive blur for lines further away from active index.

- [ ] **Step 2: Add click-to-seek in `LyricsNSScrollView.swift`**
- Add click / mouse-down gesture on lyric lines that extracts the line's `startTime` and calls `ViewModel.shared.currentPlayerInstance.seek(to: Double(startTime) / 1000.0)`.

- [ ] **Step 3: Add instrumental break 3-dot pulse animation**
- Display animated 3-dot pulse indicator during extended instrumental intervals between lyric lines.

- [ ] **Step 4: Commit lyrics polish**
```bash
git add LyricFever/Views/FullscreenView/LyricsNSScrollView.swift
git commit -m "feat(lyrics): polish Apple Music typography, click-to-seek, and instrumental pulse"
```

---

### Task 7: Spotify Web Queue Service & Queue UI Panel

**Files:**
- Create: `LyricFever/Services/SpotifyQueueService.swift`
- Create: `LyricFever/Views/FullscreenView/Queue/QueueView.swift`
- Create: `LyricFever/Views/FullscreenView/Queue/QueueItemView.swift`
- Modify: `LyricFever/ViewModel.swift`

**Interfaces:**
- Consumes: Spotify OAuth PKCE, `/v1/me/player/queue`
- Produces: `SpotifyQueueService.fetchQueue()`, `QueueView`, `QueueItemView`

- [ ] **Step 1: Implement `SpotifyQueueService.swift`**
- OAuth PKCE client (`client_id`, code verifier/challenge, token refresh).
- Methods: `authenticate()`, `fetchQueue() async throws -> [QueueTrack]`, `playTrack(uri: String) async throws`.
- Token caching in `UserDefaults` / Keychain.

- [ ] **Step 2: Implement `QueueItemView.swift` and `QueueView.swift`**
- Header: *"Playing Next"*.
- Track rows: 48pt height, rounded artwork thumbnail, track name, artist, playing indicator.
- Hover effect with play button overlay $\to$ click calls `playTrack`.

- [ ] **Step 3: Bind Queue View to `FullscreenView.swift` State C**
- When `fullscreenPanelState == .queue`, slide in `QueueView` on the right side of the docked artwork.

- [ ] **Step 4: Commit Queue panel and service**
```bash
git add LyricFever/Services/SpotifyQueueService.swift LyricFever/Views/FullscreenView/Queue/
git commit -m "feat(queue): implement Spotify Web API PKCE queue service and slide-in queue panel"
```

---

### Task 8: Settings Persistence & End-to-End Verification

**Files:**
- Modify: `LyricFever/Support Files/UserDefaultStorage.swift`
- Modify: `LyricFever/Views/FullscreenView/FullscreenView.swift`

**Interfaces:**
- Consumes: `UserDefaultStorage`
- Produces: Persistent background style, idle delay preference, full end-to-end integration

- [ ] **Step 1: Add settings properties to `UserDefaultStorage.swift`**
```swift
@ObservableUserDefault(.init(key: "fullscreenBackgroundStyle", store: .standard), defaultValue: FullscreenBackgroundStyle.fluidArtwork.rawValue)
var fullscreenBackgroundStyle: String
```

- [ ] **Step 2: Connect settings in `···` More popover**
Provide background style selection and animation toggles.

- [ ] **Step 3: Verification & test run**
Run project build and verify state transitions across:
- State A (idle metadata, timeline scrub, transport controls)
- State B (lyrics click-to-seek, smooth scrolling, dimming)
- State C (queue fetch, item click)
- HUD shortcuts overlay (`?`)

- [ ] **Step 4: Commit final integration**
```bash
git add LyricFever/Support\ Files/UserDefaultStorage.swift LyricFever/Views/FullscreenView/
git commit -m "feat(fullscreen): finalize settings persistence and end-to-end integration"
```
