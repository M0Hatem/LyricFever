//
//  FullscreenTimelineView.swift
//  Lyric Fever
//
//  Created by Antigravity on 2026-08-31.
//

import SwiftUI

@MainActor
struct FullscreenTimelineView: View {
    @Environment(ViewModel.self) var viewmodel
    var idleCoordinator: FullscreenIdleCoordinator?
    
    @State private var isDragging: Bool = false
    @State private var isHovering: Bool = false
    @State private var dragPosition: Double = 0.0 // 0.0 to 1.0
    
    private var totalDurationSeconds: Double {
        if let durSec = viewmodel.currentPlayerInstance.durationSeconds, durSec > 0 {
            return durSec
        }
        guard let dur = viewmodel.currentPlayerInstance.duration, dur > 0 else {
            return 1.0
        }
        return Double(dur) / 1000.0
    }
    
    private var rawPositionSeconds: Double {
        if let pos = viewmodel.currentPlayerInstance.playerPositionSeconds {
            return max(0.0, pos)
        }
        if let cur = viewmodel.currentPlayerInstance.currentTime {
            return max(0.0, cur / 1000.0)
        }
        return 0.0
    }
    
    private var currentProgress: Double {
        if isDragging {
            return dragPosition
        }
        guard totalDurationSeconds > 0 else {
            return 0.0
        }
        return min(max(rawPositionSeconds / totalDurationSeconds, 0.0), 1.0)
    }
    
    private var displayedElapsedSeconds: Double {
        if isDragging {
            return dragPosition * totalDurationSeconds
        }
        return rawPositionSeconds
    }
    
    private var displayedRemainingSeconds: Double {
        return max(0.0, totalDurationSeconds - displayedElapsedSeconds)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Elapsed time text
            Text(formatTime(displayedElapsedSeconds))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .frame(width: 40, alignment: .trailing)
            
            // Interactive Scrubber Bar
            GeometryReader { barGeo in
                let width = barGeo.size.width
                let height = barGeo.size.height
                let progressWidth = width * CGFloat(currentProgress)
                let isThumbActive = isHovering || isDragging
                
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color.white.opacity(0.20))
                        .frame(height: isThumbActive ? 6 : 4)
                    
                    // Filled progress
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, progressWidth), height: isThumbActive ? 6 : 4)
                    
                    // Thumb
                    if isThumbActive {
                        Circle()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
                            .frame(width: 12, height: 12)
                            .offset(x: max(0, min(progressWidth - 6, width - 12)))
                    }
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            idleCoordinator?.isHoveringOrScrubbing = true
                            let progress = max(0.0, min(1.0, Double(value.location.x / width)))
                            dragPosition = progress
                        }
                        .onEnded { value in
                            let finalProgress = max(0.0, min(1.0, Double(value.location.x / width)))
                            let targetSeconds = finalProgress * totalDurationSeconds
                            viewmodel.currentPlayerInstance.seek(to: targetSeconds)
                            isDragging = false
                            idleCoordinator?.isHoveringOrScrubbing = isHovering
                        }
                )
            }
            .frame(height: 18)
            .onHover { hover in
                isHovering = hover
                idleCoordinator?.isHoveringOrScrubbing = hover || isDragging
            }

            // Remaining time text
            Text("-" + formatTime(displayedRemainingSeconds))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .frame(width: 44, alignment: .leading)
        }
        .padding(.horizontal, 8)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
