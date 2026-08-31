//
//  SpotifyLyricsInMenubarApp.swift
//  SpotifyLyricsInMenubar
//
//  Created by Avi Wadhwa on 26/07/23.
//

import SwiftUI
#if canImport(Translation)
import Translation
#endif
import LaunchAtLogin

extension NSScreen {
    static var mainWidth: CGFloat {
        NSScreen.main?.frame.width ?? 1920
    }
    static var mainHeight: CGFloat {
        NSScreen.main?.frame.height ?? 1080
    }
}

enum MusicType {
    case spotify
    case appleMusic
}

@MainActor
struct MenuBarLabelContainerView: View {
    @Bindable var viewmodel: ViewModel
    @Environment(\.openWindow) var openWindow
    @Environment(\.openURL) var openURL

    var body: some View {
        MenubarLabelView()
            .environment(viewmodel)
            .task(id: viewmodel.currentlyPlaying) {
                if viewmodel.currentPlayer == .appleMusic {
                    print("Ignoring currentlyPlaying task because Apple Music album art workaround is active.")
                    return
                }
                if viewmodel.currentlyPlaying == nil {
                    print("Incorrect task fired. Ignored on nil currentlyPlaying value")
                    return
                }
                print("Artwork Fetch Service:Fetching new artwork image for currentlyPlaying change")
                if let artworkImage = await viewmodel.currentPlayerInstance.artworkImage {
                    print("Artwork Fetch Service: Fetched from player")
                    viewmodel.artworkImage = artworkImage
                } else if let artistName = viewmodel.currentlyPlayingArtist, let currentAlbumName = viewmodel.currentAlbumName {
                    if let mbid = await MusicBrainzArtworkService.findMbid(albumName: currentAlbumName, artistName: artistName) {
                        print("Artwork Fetch Service: MusicBrainz Success")
                        viewmodel.artworkImage = await MusicBrainzArtworkService.artworkImage(for: mbid)
                    }
                } else {
                    print("Artwork Fetch Service: couldn't grab mbid image nor player image")
                }
            }
            .task(id: viewmodel.userDefaultStorage.latestUpdateWindowShown) {
                if viewmodel.userDefaultStorage.latestUpdateWindowShown < 33 {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    openWindow(id: "update")
                    viewmodel.userDefaultStorage.latestUpdateWindowShown = 33
                }
            }
            .task(id: viewmodel.userDefaultStorage.hasOnboarded) {
                if !viewmodel.userDefaultStorage.hasOnboarded {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    openWindow(id: "onboarding")
                } else {
                    guard !viewmodel.isFirstFetch else {
                        print("Onboarding Task: ignoring false runtime call, cannot refresh as first fetch")
                        return
                    }
                    do {
                        try await viewmodel.refreshLyrics()
                    } catch {
                        print("Couldn't refresh lyrics on hasOnboarding: \(error)")
                    }
                }
            }
            .onChange(of: viewmodel.showLyrics) {
                viewmodel.toggleLyrics()
            }
            .floatingPanel(isPresented: $viewmodel.displayKaraoke) {
                KaraokeView()
                    .animation(.easeIn(duration: 0.2))
                    .environment(viewmodel)
            }
            .onAppear {
                viewmodel.onAppear(openWindow)
            }
            .onReceive(DistributedNotificationCenter.default().publisher(for: Notification.Name(rawValue:  "com.apple.Music.playerInfo"))) { notification in
                viewmodel.appleMusicPlaybackDidChange(notification)
            }
            .onReceive(DistributedNotificationCenter.default().publisher(for: Notification.Name(rawValue:  "com.spotify.client.PlaybackStateChanged"))) { notification in
                viewmodel.spotifyPlaybackDidChange(notification)
            }
#if canImport(Translation)
            .translationTask(viewmodel.translationSessionConfig) { session in
                await viewmodel.translationTask(session)
            }
#endif
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                viewmodel.saveKaraokeFontOnTermination()
            }
            .onChange(of: viewmodel.translationSourceLanguage) {
                if viewmodel.userDefaultStorage.translate {
#if canImport(Translation)
                    viewmodel.translationSessionConfig = TranslationSession.Configuration(source: viewmodel.translationSourceLanguage, target: viewmodel.userLocaleLanguage)
#endif
                }
            }
            .onChange(of: viewmodel.userLocaleLanguage) {
                let _ = viewmodel.reloadTranslationConfigIfTranslating()
            }
            .onChange(of: viewmodel.userDefaultStorage.chinesePreference) {
                viewmodel.chinesePreferenceDidChange()
            }
            .onChange(of: viewmodel.userDefaultStorage.romanize) {
                viewmodel.romanizeDidChange()
            }
            .onChange(of: viewmodel.userDefaultStorage.translate) {
                if !viewmodel.reloadTranslationConfigIfTranslating() {
                    viewmodel.translatedLyric = []
                }
            }
            .onChange(of: viewmodel.currentPlayer) {
                print("Setting hasOnboarded to false due to player change")
                viewmodel.userDefaultStorage.hasOnboarded = false
            }
            .onChange(of: viewmodel.fullscreen) {
                if viewmodel.fullscreen {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "fullscreen")
                }
            }
            .onChange(of: viewmodel.userDefaultStorage.hasOnboarded) {
                if viewmodel.userDefaultStorage.hasOnboarded {
                    viewmodel.didOnboard()
                } else {
                    viewmodel.stopLyricUpdater()
                }
            }
            .onChange(of: viewmodel.userDefaultStorage.translate) {
                viewmodel.openTranslationHelpOnFirstRun(openURL)
            }
            .onChange(of: viewmodel.userDefaultStorage.cookie) {
                viewmodel.spotifyLyricProvider.accessToken = nil
            }
            .onChange(of: viewmodel.isPlaying) {
                if viewmodel.isPlaying, viewmodel.showLyrics, viewmodel.userDefaultStorage.hasOnboarded {
                    if !viewmodel.currentlyPlayingLyrics.isEmpty  {
                        print("timer started for spotify change, lyrics not nil")
                        viewmodel.startLyricUpdater()
                    }
                } else {
                    viewmodel.stopLyricUpdater()
                }
            }
            .task(id: viewmodel.currentlyPlayingAppleMusicPersistentID) {
                if viewmodel.currentlyPlayingAppleMusicPersistentID != nil {
                    print("Apple Music: calling Starter on new persistent ID")
                    await viewmodel.appleMusicStarter()
                }
            }
            .onChange(of: viewmodel.currentlyPlaying) {
                print("song change")
                Task {
                    await viewmodel.onCurrentlyPlayingIDChange()
                }
            }
    }
}

@main
struct SpotifyLyricsInMenubarApp: App {
    @State var viewmodel = ViewModel.shared
    @Environment(\.openWindow) var openWindow
    @Environment(\.openURL) var openURL
    
    var body: some Scene {
        MenuBarExtra {
            MenubarWindowView()
                .preferredColorScheme(.dark)
                .environment(viewmodel)
        } label: {
            MenuBarLabelContainerView(viewmodel: viewmodel)
        }
        .menuBarExtraStyle(.window)
        Window("Lyric Fever: Fullscreen", id: "fullscreen") {
            FullscreenView()
                .preferredColorScheme(.dark)
                .environment(viewmodel)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    
                    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { (aEvent) -> NSEvent? in
                        if aEvent.keyCode == 53 { // if esc pressed
                            Task { @MainActor in
                                for window in NSApp.windows where window.title.contains("Fullscreen") || window.identifier?.rawValue == "fullscreen" {
                                    if window.styleMask.contains(.fullScreen) {
                                        window.toggleFullScreen(nil)
                                    }
                                    window.close()
                                }
                            }
                            return nil
                        }
                        return aEvent
                    }
                }
                .onDisappear {
                    viewmodel.fullscreen = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if !viewmodel.fullscreen {
                            let hasOtherVisible = NSApp.windows.contains(where: { $0.isVisible && ($0.identifier?.rawValue == "onboarding" || $0.identifier?.rawValue == "search" || $0.identifier?.rawValue == "update") })
                            if !hasOtherVisible {
                                NSApp.setActivationPolicy(.accessory)
                            }
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: NSScreen.mainWidth, height: NSScreen.mainHeight)
        Window("Lyric Fever: Onboarding", id: "onboarding") {
            OnboardingWindow().frame(minWidth: 700, maxWidth: 700, minHeight: 600, maxHeight: 600, alignment: .center)
                .environment(viewmodel)
                .preferredColorScheme(.dark)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                }
                .onDisappear {
                    if !viewmodel.fullscreen {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        Window("Lyric Fever: Searching for \(viewmodel.currentlyPlayingName ?? "-") by \(viewmodel.currentlyPlayingArtist ?? "-")", id: "search") {
            SearchWindow().frame(minWidth: 700, maxWidth: 700, minHeight: 500, maxHeight: 500, alignment: .center)
                .environment(viewmodel)
                .preferredColorScheme(.dark)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                }
                .onDisappear {
                    if !viewmodel.fullscreen {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
        }
        .windowResizability(.contentSize)
        Window("Lyric Fever: Update 2.3", id: "update") {
            UpdateWindow().frame(minWidth: 700, maxWidth: 700, alignment: .center)
                .environment(viewmodel)
                .preferredColorScheme(.dark)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                }
                .onDisappear {
                    if !viewmodel.fullscreen {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}


extension String {
    @MainActor
    func trunc(length: Int? = nil, trailing: String = "…") -> String {
        let length = length ?? ViewModel.shared.userDefaultStorage.truncationLength
        return (self.count > length) ? self.prefix(length) + trailing : self
    }
}
