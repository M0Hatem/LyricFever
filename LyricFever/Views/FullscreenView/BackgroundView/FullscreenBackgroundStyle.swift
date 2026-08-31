//
//  FullscreenBackgroundStyle.swift
//  Lyric Fever
//
//  Created by Antigravity on 2026-08-31.
//

import Foundation

enum FullscreenBackgroundStyle: String, CaseIterable, Identifiable, Codable {
    case fluidArtwork = "Fluid Artwork"
    case classicMesh = "Classic Mesh"
    case solidColor = "Solid Color"
    case off = "Off"

    var id: String { rawValue }
}
