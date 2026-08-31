//
//  SpotifyQueueService.swift
//  Lyric Fever
//
//  Created by Antigravity on 2026-08-31.
//

import Foundation
import AppKit

struct QueueTrack: Identifiable, Hashable {
    let id: String
    let name: String
    let artist: String
    let album: String
    let artworkURL: URL?
    let durationMS: Int
    let uri: String
    let isCurrentlyPlaying: Bool
}

@MainActor
@Observable final class SpotifyQueueService {
    static let shared = SpotifyQueueService()
    
    var currentlyPlayingTrack: QueueTrack?
    var upcomingTracks: [QueueTrack] = []
    var isLoading: Bool = false
    var errorMessage: String?
    
    private let session = URLSession.shared
    
    private init() {}
    
    func fetchQueue() async {
        isLoading = true
        errorMessage = nil
        
        // Check if Spotify is running and playing
        let vm = ViewModel.shared
        guard vm.playerType == .spotify else {
            isLoading = false
            return
        }
        
        // If a Spotify Web API cookie / token is stored in userDefaultStorage, use it
        let token = vm.userDefaultStorage.cookie
        guard !token.isEmpty else {
            // Populate fallback queue from currently playing track information
            if let name = vm.currentlyPlayingName, let artist = vm.currentlyPlayingArtist {
                currentlyPlayingTrack = QueueTrack(
                    id: vm.currentlyPlaying ?? UUID().uuidString,
                    name: name,
                    artist: artist,
                    album: vm.currentAlbumName ?? "",
                    artworkURL: vm.currentArtworkURL,
                    durationMS: vm.duration,
                    uri: "spotify:track:\(vm.currentlyPlaying ?? "")",
                    isCurrentlyPlaying: true
                )
            }
            isLoading = false
            return
        }
        
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/queue") else {
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                isLoading = false
                return
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Parse currently_playing
                if let cp = json["currently_playing"] as? [String: Any],
                   let track = parseTrack(cp, isCurrent: true) {
                    currentlyPlayingTrack = track
                }
                
                // Parse queue
                if let queueList = json["queue"] as? [[String: Any]] {
                    upcomingTracks = queueList.compactMap { parseTrack($0, isCurrent: false) }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func parseTrack(_ dict: [String: Any], isCurrent: Bool) -> QueueTrack? {
        guard let name = dict["name"] as? String,
              let id = dict["id"] as? String ?? dict["uri"] as? String else {
            return nil
        }
        
        let uri = dict["uri"] as? String ?? "spotify:track:\(id)"
        let durationMS = dict["duration_ms"] as? Int ?? 0
        
        var artistName = ""
        if let artists = dict["artists"] as? [[String: Any]], !artists.isEmpty {
            artistName = artists.compactMap { $0["name"] as? String }.joined(separator: ", ")
        }
        
        var albumName = ""
        var artworkURL: URL? = nil
        if let album = dict["album"] as? [String: Any] {
            albumName = album["name"] as? String ?? ""
            if let images = album["images"] as? [[String: Any]], let first = images.first, let urlStr = first["url"] as? String {
                artworkURL = URL(string: urlStr)
            }
        }
        
        return QueueTrack(
            id: id,
            name: name,
            artist: artistName,
            album: albumName,
            artworkURL: artworkURL,
            durationMS: durationMS,
            uri: uri,
            isCurrentlyPlaying: isCurrent
        )
    }
    
    func playTrack(uri: String) {
        if let spotifyPlayer = ViewModel.shared.currentPlayerInstance as? SpotifyPlayer {
            spotifyPlayer.spotifyScript?.playTrack?(uri, inContext: "")
        }
    }
}
