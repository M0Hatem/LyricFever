//
//  FullscreenShortcutsOverlayView.swift
//  Lyric Fever
//
//  Created by Antigravity on 2026-08-31.
//

import SwiftUI

struct FullscreenShortcutsOverlayView: View {
    @Binding var isPresented: Bool

    private let shortcuts: [(key: String, title: String)] = [
        ("Space", "Play / Pause"),
        ("← / →", "Seek 5s backward / forward"),
        ("⌘← / ⌘→", "Previous / Next track"),
        ("↑ / ↓", "Volume up / down"),
        ("L / H", "Toggle Lyrics"),
        ("Q", "Toggle Up Next Queue"),
        ("T", "Toggle Translation"),
        ("?", "Shortcuts cheat sheet"),
        ("Esc", "Exit Fullscreen")
    ]

    var body: some View {
        ZStack {
            // Semi-transparent backdrop to dismiss
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }

            // Frosted Glass HUD Card
            VStack(spacing: 20) {
                HStack {
                    Text("Keyboard Shortcuts")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 10) {
                    ForEach(shortcuts, id: \.key) { item in
                        HStack {
                            Text(item.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))

                            Spacer()

                            Text(item.key)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.white.opacity(0.18))
                                )
                        }
                    }
                }
            }
            .padding(22)
            .frame(width: 380)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.5), radius: 24, x: 0, y: 12)
        }
    }
}
