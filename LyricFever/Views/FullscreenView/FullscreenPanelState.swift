//
//  FullscreenPanelState.swift
//  Lyric Fever
//
//  Created by Antigravity on 2026-08-31.
//

import Foundation

enum FullscreenPanelState: String, CaseIterable, Equatable {
    case none    // State A: Centered artwork, timeline, controls
    case lyrics  // State B: Docked left, synced lyrics right
    case queue   // State C: Docked left, up-next queue right
}
