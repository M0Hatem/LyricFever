//
//  BackgroundView.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa on 2025-07-26.
//

import SwiftUI
import Combine
import AppKit

struct BackgroundView: View {
    var style: FullscreenBackgroundStyle = .fluidArtwork
    var artworkImage: NSImage? = nil
    var isPlaying: Bool = true
    
    @Binding var colors: [SwiftUI.Color]
    @Binding var timer: Publishers.Autoconnect<Timer.TimerPublisher>
    @Binding var points: ColorSpots

    static let animationDuration: Double = 20
    @State var bias: Float = 0.002
    @State var power: Float = 2.5
    @State var noise: Float = 2

    var body: some View {
        switch style {
        case .fluidArtwork:
            ArtworkFluidBackgroundView(artworkImage: artworkImage, isPlaying: isPlaying)
        case .classicMesh:
            MulticolorGradient(
                points: points,
                bias: bias,
                power: power,
                noise: noise
            )
            .onAppear {
                withAnimation(.easeInOut(duration: BackgroundView.animationDuration/4)){
                    points = self.colors.map { .random(withColor: $0) }
                }
            }
            .onChange(of: colors) {
                withAnimation(.easeInOut(duration: BackgroundView.animationDuration/4)){
                    points = self.colors.map { .random(withColor: $0) }
                }
            }
            .onReceive(timer) { _ in
                withAnimation(.easeInOut(duration: BackgroundView.animationDuration)) {
                    points = self.colors.map { .random(withColor: $0) }
                }
            }
        case .solidColor:
            if let firstColor = colors.first {
                firstColor.overlay(Color.black.opacity(0.65))
            } else {
                Color(red: 0.08, green: 0.08, blue: 0.12)
            }
        case .off:
            Color.black
        }
    }
}
