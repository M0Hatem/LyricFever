//
//  FullscreenControlsView.swift
//  Lyric Fever
//
//  Created by Antigravity on 2026-08-31.
//

import SwiftUI
import AppKit

struct FullscreenControlsView: View {
    @Environment(ViewModel.self) var viewmodel
    var idleCoordinator: FullscreenIdleCoordinator?
    @Binding var showShortcutsHUD: Bool
    
    @State private var showMorePopover: Bool = false
    @State private var volumeValue: Double = 50.0

    private var hasTimedLyrics: Bool {
        !viewmodel.currentlyPlayingLyrics.isEmpty
    }
    
    private var isLyricsActive: Bool {
        viewmodel.fullscreenPanelState == .lyrics
    }
    
    private var isQueueActive: Bool {
        viewmodel.fullscreenPanelState == .queue
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left Group: ··· More Menu
            HStack {
                Button {
                    showMorePopover.toggle()
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(showMorePopover ? 1.0 : 0.7))
                }
                .buttonStyle(.plain)
                .onHover { hover in
                    idleCoordinator?.isHoveringOrScrubbing = hover
                }
                .popover(isPresented: $showMorePopover, arrowEdge: .top) {
                    moreOptionsPopover
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)

            // Center Group: Transport Controls
            HStack(spacing: 28) {
                // Rewind
                Button {
                    handleRewind()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(FullscreenControlButtonStyle())

                // Play / Pause
                Button {
                    viewmodel.currentPlayerInstance.togglePlayback()
                } label: {
                    Image(systemName: viewmodel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(FullscreenControlButtonStyle())

                // Forward / Next
                Button {
                    viewmodel.currentPlayerInstance.forward()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(FullscreenControlButtonStyle())
            }
            .onHover { hover in
                idleCoordinator?.isHoveringOrScrubbing = hover
            }

            // Right Group: Lyrics & Queue
            HStack(spacing: 16) {
                Spacer()

                // Lyrics Button
                Button {
                    toggleLyrics()
                } label: {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(
                            isLyricsActive
                                ? Color.white
                                : (hasTimedLyrics ? Color.white.opacity(0.65) : Color.white.opacity(0.25))
                        )
                        .padding(6)
                        .background(
                            isLyricsActive
                                ? Circle().fill(Color.white.opacity(0.25))
                                : Circle().fill(Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!hasTimedLyrics)
                .help(hasTimedLyrics ? "Toggle Synced Lyrics (L)" : "No timed lyrics available")

                // Queue Button (Only displayed if supported)
                if viewmodel.currentPlayerInstance.supportsQueue {
                    Button {
                        toggleQueue()
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(
                                isQueueActive
                                    ? Color.white
                                    : Color.white.opacity(0.65)
                            )
                            .padding(6)
                            .background(
                                isQueueActive
                                    ? Circle().fill(Color.white.opacity(0.25))
                                    : Circle().fill(Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Up Next Queue (Q)")
                }
            }
            .frame(maxWidth: .infinity)
            .onHover { hover in
                idleCoordinator?.isHoveringOrScrubbing = hover
            }
        }
        .padding(.horizontal, 8)
        .onAppear {
            volumeValue = Double(viewmodel.currentPlayerInstance.volume)
        }
    }

    private func handleRewind() {
        if let cur = viewmodel.currentPlayerInstance.currentTime, cur > 3000 {
            viewmodel.currentPlayerInstance.seek(to: 0)
        } else {
            viewmodel.currentPlayerInstance.rewind()
        }
    }

    private func toggleLyrics() {
        guard hasTimedLyrics else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            if isLyricsActive {
                viewmodel.fullscreenPanelState = .none
                viewmodel.showLyrics = false
            } else {
                viewmodel.fullscreenPanelState = .lyrics
                viewmodel.showLyrics = true
            }
        }
    }

    private func toggleQueue() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            if isQueueActive {
                viewmodel.fullscreenPanelState = .none
            } else {
                viewmodel.fullscreenPanelState = .queue
            }
        }
    }

    // MARK: - More Options Popover
    @ViewBuilder
    private var moreOptionsPopover: some View {
        @Bindable var vm = viewmodel
        
        VStack(alignment: .leading, spacing: 14) {
            // Volume Slider
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                Slider(value: $volumeValue, in: 0...100) { _ in
                    vm.currentPlayerInstance.setVolume(to: volumeValue)
                }
                .frame(width: 140)
                
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)

            Divider()

            // Translation Toggle
            Toggle("Translate Lyrics", isOn: $vm.userDefaultStorage.translate)
                .toggleStyle(.switch)
                .disabled(!hasTimedLyrics)

            // Blur Surrounding Lyrics Toggle
            Toggle("Blur Distant Lyrics", isOn: $vm.userDefaultStorage.blurFullscreen)
                .toggleStyle(.switch)

            // Background Style Picker
            Picker("Background", selection: $vm.userDefaultStorage.fullscreenBackgroundStyle) {
                ForEach(FullscreenBackgroundStyle.allCases) { style in
                    Text(style.rawValue).tag(style.rawValue)
                }
            }
            .pickerStyle(.menu)

            Divider()

            // Keyboard Shortcuts HUD Button
            Button {
                showMorePopover = false
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showShortcutsHUD = true
                }
            } label: {
                Label("Keyboard Shortcuts (?)", systemImage: "keyboard")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)

            if let shareURL = vm.currentPlayerInstance.shareURL(for: vm.currentlyPlaying) {
                ShareLink(item: shareURL) {
                    Label("Share Track", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 220)
    }
}

struct FullscreenControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}
