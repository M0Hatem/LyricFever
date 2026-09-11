//
//  FullscreenView.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa on 2024-07-27.
//

import SwiftUI
import SDWebImage
import ColorKit
import Combine

@MainActor
struct FullscreenView: View {
    @Environment(ViewModel.self) var viewmodel

    @State private var idleCoordinator = FullscreenIdleCoordinator()
    @State private var showShortcutsHUD = false
    @State private var showSettingsPopover = false
    
    // Background gradient colors fallback
    @State var gradient = [Color(red: 33/255, green: 69/255, blue: 152/255), Color(red: 218/255, green: 62/255, blue: 136/255)]
    @State var timer = Timer
        .publish(every: BackgroundView.animationDuration, on: .main, in: .common)
        .autoconnect()
    @State var points: ColorSpots = .init()

    private var isDocked: Bool {
        viewmodel.fullscreenPanelState != .none
    }

    var body: some View {
        GeometryReader { geo in
            let windowWidth = geo.size.width
            let windowHeight = geo.size.height
            let isLandscape = windowWidth > windowHeight
            
            ZStack {
                // Ambient background
                BackgroundView(
                    style: FullscreenBackgroundStyle(rawValue: viewmodel.userDefaultStorage.fullscreenBackgroundStyle) ?? .fluidArtwork,
                    artworkImage: viewmodel.artworkImage,
                    isPlaying: viewmodel.isPlaying,
                    colors: $gradient,
                    timer: $timer,
                    points: $points
                )
                .ignoresSafeArea()

                // Main Content Layout
                HStack(spacing: 0) {
                    // Left Column (Artwork + Timeline + Controls or Centered in State A)
                    VStack(spacing: 24) {
                        Spacer(minLength: 20)
                        
                        artworkContainer(geo: geo)
                        
                        // Idle Song Metadata (Revealed when controls are hidden after 3s)
                        if idleCoordinator.isIdleMetadataVisible {
                            VStack(spacing: 6) {
                                Text(viewmodel.currentlyPlayingName ?? "Not Playing")
                                    .font(.system(size: isDocked ? 20 : 24, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                
                                Text(viewmodel.currentlyPlayingArtist ?? "")
                                    .font(.system(size: isDocked ? 15 : 18, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .frame(maxWidth: isDocked ? windowWidth * 0.38 : min(windowWidth * 0.6, 580))
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        }

                        // Controls & Timeline Chrome (Fades out when idle)
                        if idleCoordinator.isControlsVisible {
                            VStack(spacing: 16) {
                                FullscreenTimelineView(idleCoordinator: idleCoordinator)
                                    .frame(maxWidth: isDocked ? min(windowWidth * 0.38, 480) : min(windowWidth * 0.52, 580))

                                FullscreenControlsView(
                                    idleCoordinator: idleCoordinator,
                                    showShortcutsHUD: $showShortcutsHUD
                                )
                                .frame(maxWidth: isDocked ? min(windowWidth * 0.38, 480) : min(windowWidth * 0.52, 580))
                            }
                            .transition(.opacity)
                        }

                        Spacer(minLength: 20)
                    }
                    .frame(
                        width: isDocked ? windowWidth * 0.42 : windowWidth,
                        height: windowHeight
                    )
                    
                    // Right Column (State B: Lyrics or State C: Queue)
                    if isDocked {
                        Group {
                            switch viewmodel.fullscreenPanelState {
                            case .lyrics:
                                lyricsPanel(padding: windowHeight * 0.4)
                            case .queue:
                                QueueView()
                            case .none:
                                EmptyView()
                            }
                        }
                        .frame(width: windowWidth * 0.58, height: windowHeight)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity
                        ))
                    }
                }
                .animation(.spring(response: 0.42, dampingFraction: 0.82), value: viewmodel.fullscreenPanelState)

                // Shortcuts Overlay HUD
                if showShortcutsHUD {
                    FullscreenShortcutsOverlayView(isPresented: $showShortcutsHUD)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
        }
        .onAppear {
            idleCoordinator.startMonitoring()
            // Sync showLyrics with panel state
            if viewmodel.showLyrics && !viewmodel.currentlyPlayingLyrics.isEmpty {
                viewmodel.fullscreenPanelState = .lyrics
            } else if viewmodel.fullscreenPanelState == .lyrics && viewmodel.currentlyPlayingLyrics.isEmpty {
                viewmodel.fullscreenPanelState = .none
            }
        }
        .onDisappear {
            idleCoordinator.stopMonitoring()
        }
        .onChange(of: viewmodel.currentlyPlayingLyrics) { oldValue, newValue in
            if newValue.isEmpty {
                if viewmodel.fullscreenPanelState == .lyrics && !viewmodel.isFetching {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                        viewmodel.fullscreenPanelState = .none
                    }
                }
            } else {
                if viewmodel.showLyrics && viewmodel.fullscreenPanelState == .none {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                        viewmodel.fullscreenPanelState = .lyrics
                    }
                }
            }
        }
        .onChange(of: viewmodel.lyricsIsEmptyPostLoad) { oldValue, newValue in
            if newValue && viewmodel.currentlyPlayingLyrics.isEmpty {
                if viewmodel.fullscreenPanelState == .lyrics {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                        viewmodel.fullscreenPanelState = .none
                    }
                }
            }
        }
        .task(id: viewmodel.artworkImage) {
            let bgStyle = FullscreenBackgroundStyle(rawValue: viewmodel.userDefaultStorage.fullscreenBackgroundStyle) ?? .fluidArtwork
            guard viewmodel.fullscreen && (bgStyle == .classicMesh || bgStyle == .solidColor) else { return }
            if let artworkImage = viewmodel.artworkImage,
               let dominantColors = try? artworkImage.dominantColors(with: .best, algorithm: .kMeansClustering) {
                gradient = dominantColors.map { adjustedColor($0) }
            }
        }
        // Keyboard shortcuts
        .onKeyPress(.space) {
            viewmodel.currentPlayerInstance.togglePlayback()
            idleCoordinator.userActivityDetected()
            return .handled
        }
        .onKeyPress(KeyEquivalent("l")) {
            toggleLyricsPanel()
            idleCoordinator.userActivityDetected()
            return .handled
        }
        .onKeyPress(KeyEquivalent("h")) {
            toggleLyricsPanel()
            idleCoordinator.userActivityDetected()
            return .handled
        }
        .onKeyPress(KeyEquivalent("q")) {
            toggleQueuePanel()
            idleCoordinator.userActivityDetected()
            return .handled
        }
        .onKeyPress(KeyEquivalent("t")) {
            viewmodel.userDefaultStorage.translate.toggle()
            idleCoordinator.userActivityDetected()
            return .handled
        }
        .onKeyPress(KeyEquivalent("?")) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showShortcutsHUD.toggle()
            }
            idleCoordinator.userActivityDetected()
            return .handled
        }
        .onKeyPress(phases: .down) { press in
            if press.modifiers.contains(.command) {
                if press.key == .leftArrow {
                    viewmodel.currentPlayerInstance.rewind()
                    idleCoordinator.userActivityDetected()
                    return .handled
                } else if press.key == .rightArrow {
                    viewmodel.currentPlayerInstance.forward()
                    idleCoordinator.userActivityDetected()
                    return .handled
                }
            } else if press.modifiers.isEmpty {
                if press.key == .leftArrow {
                    let cur = viewmodel.effectivePlayerPositionSeconds
                    viewmodel.seek(to: max(0, cur - 5.0))
                    idleCoordinator.userActivityDetected()
                    return .handled
                } else if press.key == .rightArrow {
                    let cur = viewmodel.effectivePlayerPositionSeconds
                    viewmodel.seek(to: cur + 5.0)
                    idleCoordinator.userActivityDetected()
                    return .handled
                } else if press.key == .upArrow {
                    viewmodel.currentPlayerInstance.increaseVolume()
                    idleCoordinator.userActivityDetected()
                    return .handled
                } else if press.key == .downArrow {
                    viewmodel.currentPlayerInstance.decreaseVolume()
                    idleCoordinator.userActivityDetected()
                    return .handled
                } else if press.key == .escape {
                    FullscreenWindowController.shared.close()
                    return .handled
                }
            }
            return .ignored
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func artworkContainer(geo: GeometryProxy) -> some View {
        let windowHeight = geo.size.height
        let windowWidth = geo.size.width

        // Exact 57.6% height proportion matching Apple Music without artificial clamping
        let targetDimension: CGFloat = isDocked
            ? min(windowHeight * 0.52, windowWidth * 0.38)
            : min(windowHeight * 0.576, windowWidth * 0.85)
        let cornerRadius: CGFloat = 12

        Group {
            if let artwork = viewmodel.artworkImage {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.1)
                    Image(systemName: "music.note")
                        .font(.system(size: targetDimension * 0.3))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .frame(width: targetDimension, height: targetDimension)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.35), radius: isDocked ? 18 : 26, x: 0, y: isDocked ? 8 : 12)
    }

    @ViewBuilder
    private func lyricsPanel(padding: CGFloat) -> some View {
        let lyricsEmpty = viewmodel.currentlyPlayingLyrics.isEmpty

        ZStack {
            LyricsNSScrollView(
                lyrics: viewmodel.currentlyPlayingLyrics,
                currentIndex: viewmodel.currentlyPlayingLyricsIndex,
                romanizedLyrics: viewmodel.romanizedLyrics,
                chineseConversionLyrics: viewmodel.chineseConversionLyrics,
                translatedLyric: viewmodel.translatedLyric,
                blurFullscreen: viewmodel.userDefaultStorage.blurFullscreen,
                padding: padding
            )
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.12),
                        .init(color: .black, location: 0.88),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            if lyricsEmpty && viewmodel.isFetching {
                ProgressView()
                    .controlSize(.large)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.4), value: lyricsEmpty)
    }

    private func toggleLyricsPanel() {
        guard !viewmodel.currentlyPlayingLyrics.isEmpty else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            if viewmodel.fullscreenPanelState == .lyrics {
                viewmodel.fullscreenPanelState = .none
                viewmodel.showLyrics = false
            } else {
                viewmodel.fullscreenPanelState = .lyrics
                viewmodel.showLyrics = true
            }
        }
    }

    private func toggleQueuePanel() {
        guard viewmodel.currentPlayerInstance.supportsQueue else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            if viewmodel.fullscreenPanelState == .queue {
                viewmodel.fullscreenPanelState = .none
            } else {
                viewmodel.fullscreenPanelState = .queue
            }
        }
    }

    #if os(macOS)
    typealias PlatformColor = NSColor
    #else
    typealias PlatformColor = UIColor
    #endif

    private func adjustedColor(_ color: PlatformColor) -> Color {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        brightness = max(brightness - 0.2, 0.1)
        if saturation < 0.9 {
            saturation = max(0.1, saturation * 3)
        }
        let modifiedColor = NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
        return Color(modifiedColor)
    }
}
