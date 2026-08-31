//
//  MenubarLabelView.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa on 2025-08-05.
//

import SwiftUI

@MainActor
struct MenubarLabelView: View {
    @Environment(ViewModel.self) var viewmodel
    
    var menuBarTitle: String? {
        // Update message takes priority
        if viewmodel.mustUpdateUrgent {
            return String(localized: "⚠️ Please Update (Click Check Updates)")
        } else if viewmodel.userDefaultStorage.hasOnboarded {
            // Try to work through lyric logic if onboarded
            if !viewmodel.userDefaultStorage.karaoke, viewmodel.showLyrics, let currentlyPlayingLyricsIndex = viewmodel.currentlyPlayingLyricsIndex, currentlyPlayingLyricsIndex < viewmodel.currentlyPlayingLyrics.count {
                // Attempt to display translations
                // Implicit assumption: translatedLyric.count == currentlyPlayingLyrics.count
                if viewmodel.translationExists, currentlyPlayingLyricsIndex < viewmodel.translatedLyric.count {
                    // I don't localize, because I deliver the lyric verbatim
                    return viewmodel.translatedLyric[currentlyPlayingLyricsIndex]
                } else {
                    // Attempt to display Romanization
                    if !viewmodel.romanizedLyrics.isEmpty, currentlyPlayingLyricsIndex < viewmodel.romanizedLyrics.count {
                        return viewmodel.romanizedLyrics[currentlyPlayingLyricsIndex]
                    } else if !viewmodel.chineseConversionLyrics.isEmpty, currentlyPlayingLyricsIndex < viewmodel.chineseConversionLyrics.count {
                        return viewmodel.chineseConversionLyrics[currentlyPlayingLyricsIndex]
                    } else {
                        return viewmodel.currentlyPlayingLyrics[currentlyPlayingLyricsIndex].words
                    }
                }
            // Backup: Display name and artist
            } else if viewmodel.userDefaultStorage.showSongDetailsInMenubar, let currentlyPlayingName = viewmodel.currentlyPlayingName, let currentlyPlayingArtist = viewmodel.currentlyPlayingArtist {
                if viewmodel.isPlaying {
                    return String(localized: "Now Playing: \(currentlyPlayingName) - \(currentlyPlayingArtist)")
                } else {
                    return String(localized: "Now Paused: \(currentlyPlayingName) - \(currentlyPlayingArtist)")
                }
            }
            // Onboarded but app is not open
            return nil
        } else {
            // Hasn't onboarded
            return String(localized: "⚠️ Complete Setup (Click Settings)")
        }
    }

    var body: some View {
        Group {
            if let menuBarTitle {
                Text(menuBarTitle.trunc())
            } else {
                Image(systemName: "music.note.list")
            }
        }
    }
}
