//
//  QueueItemView.swift
//  Lyric Fever
//
//  Created by Antigravity on 2026-08-31.
//

import SwiftUI
import SDWebImageSwiftUI

struct QueueItemView: View {
    let track: QueueTrack
    let onPlay: () -> Void
    
    @State private var isHovering: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Artwork thumbnail
            ZStack {
                if let url = track.artworkURL {
                    WebImage(url: url)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.white.opacity(0.1)
                    Image(systemName: "music.note")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                // Hover play button overlay
                if isHovering {
                    Color.black.opacity(0.4)
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .shadow(radius: 2)

            // Title & Artist
            VStack(alignment: .leading, spacing: 3) {
                Text(track.name)
                    .font(.system(size: 14, weight: track.isCurrentlyPlaying ? .bold : .medium))
                    .foregroundStyle(track.isCurrentlyPlaying ? .white : .white.opacity(0.9))
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            // Indicator or duration
            if track.isCurrentlyPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
            } else if track.durationMS > 0 {
                Text(formatDuration(track.durationMS))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovering ? Color.white.opacity(0.12) : (track.isCurrentlyPlaying ? Color.white.opacity(0.06) : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { hover in
            isHovering = hover
        }
        .onTapGesture {
            onPlay()
        }
    }
    
    private func formatDuration(_ ms: Int) -> String {
        let seconds = ms / 1000
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
