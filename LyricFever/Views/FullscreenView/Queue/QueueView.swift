//
//  QueueView.swift
//  Lyric Fever
//
//  Created by Antigravity on 2026-08-31.
//

import SwiftUI

struct QueueView: View {
    @State private var queueService = SpotifyQueueService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Playing Next")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                if queueService.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        Task {
                            await queueService.fetchQueue()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)

            // Queue List
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // Now Playing Section
                    if let current = queueService.currentlyPlayingTrack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NOW PLAYING")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.45))
                                .padding(.horizontal, 12)

                            QueueItemView(track: current) {
                                // Already playing
                            }
                        }
                    }

                    // Up Next Section
                    if !queueService.upcomingTracks.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("UP NEXT")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.45))
                                .padding(.horizontal, 12)

                            ForEach(queueService.upcomingTracks) { track in
                                QueueItemView(track: track) {
                                    queueService.playTrack(uri: track.uri)
                                }
                            }
                        }
                    } else if !queueService.isLoading && queueService.currentlyPlayingTrack == nil {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 36))
                                .foregroundStyle(.white.opacity(0.3))
                            Text("No Upcoming Tracks")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await queueService.fetchQueue()
        }
    }
}
