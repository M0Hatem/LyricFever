import SwiftUI
import AppKit

@MainActor
struct ArtworkFluidBackgroundView: View {
    @Environment(ViewModel.self) var viewmodel
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    let artworkImage: NSImage?
    let isPlaying: Bool
    
    @State private var currentImage: NSImage?
    @State private var previousImage: NSImage?
    @State private var crossfadeOpacity: Double = 1.0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let minDim = min(size.width, size.height)
            let maxDim = max(size.width, size.height)
            
            ZStack {
                Color.black
                
                if let previousImage {
                    fluidLayerStack(image: previousImage, size: size, minDim: minDim, maxDim: maxDim)
                        .opacity(1.0 - crossfadeOpacity)
                }
                
                if let currentImage {
                    fluidLayerStack(image: currentImage, size: size, minDim: minDim, maxDim: maxDim)
                        .opacity(crossfadeOpacity)
                } else {
                    Color(red: 0.08, green: 0.08, blue: 0.12)
                }
                
                // Subtle darkening and radial vignette for high legibility
                RadialGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.20), Color.black.opacity(0.55)]),
                    center: .center,
                    startRadius: minDim * 0.2,
                    endRadius: maxDim * 0.8
                )
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .onAppear {
            currentImage = artworkImage
        }
        .onChange(of: artworkImage) { oldValue, newValue in
            guard oldValue != newValue else { return }
            previousImage = currentImage
            currentImage = newValue
            crossfadeOpacity = 0.0
            withAnimation(.easeInOut(duration: 0.6)) {
                crossfadeOpacity = 1.0
            }
        }
    }
    
    @ViewBuilder
    private func fluidLayerStack(image: NSImage, size: CGSize, minDim: CGFloat, maxDim: CGFloat) -> some View {
        let isFullscreen = viewmodel.fullscreen
        let isVisible = viewmodel.isFullscreenVisible
        let isPaused = reduceMotion || !isFullscreen || !isVisible || ProcessInfo.processInfo.isLowPowerModeEnabled
        
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: isPaused)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            // Layer 4 (Largest background layer: 125% max dimension)
            let layer4Scale = maxDim * 1.25
            let layer4Angle = Angle.degrees((time * 3.0).truncatingRemainder(dividingBy: 360.0))
            
            // Layer 3 (Large layer: 85% max dimension)
            let layer3Scale = maxDim * 0.85
            let layer3Angle = Angle.degrees((-time * 5.0).truncatingRemainder(dividingBy: 360.0))
            
            // Layer 2 (Medium orbiting layer: 55% min dimension)
            let layer2Scale = minDim * 0.55
            let layer2Angle = Angle.degrees((time * 8.0).truncatingRemainder(dividingBy: 360.0))
            let orbit2Radius = minDim * 0.22
            let orbit2Angle = time * 0.25
            let orbit2Offset = CGSize(
                width: cos(orbit2Angle) * orbit2Radius,
                height: sin(orbit2Angle) * orbit2Radius
            )
            
            // Layer 1 (Smallest fast orbiting layer: 38% min dimension)
            let layer1Scale = minDim * 0.38
            let layer1Angle = Angle.degrees((-time * 12.0).truncatingRemainder(dividingBy: 360.0))
            let orbit1Radius = minDim * 0.32
            let orbit1Angle = -time * 0.35
            let orbit1Offset = CGSize(
                width: cos(orbit1Angle) * orbit1Radius,
                height: sin(orbit1Angle) * orbit1Radius
            )
            
            // Twist distortion parameters
            let twistOrigin = CGPoint(x: size.width * 0.5 + sin(time * 0.2) * 50.0, y: size.height * 0.5 + cos(time * 0.2) * 50.0)
            let twistRadius = Float(maxDim * 0.7)
            let twistAngle = Float(0.45 + sin(time * 0.15) * 0.25)
            
            ZStack {
                // Base saturated blurred backdrop
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: layer4Scale, height: layer4Scale)
                    .rotationEffect(layer4Angle)
                    .scaleEffect(1.2)
                
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: layer3Scale, height: layer3Scale)
                    .rotationEffect(layer3Angle)
                
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: layer2Scale, height: layer2Scale)
                    .rotationEffect(layer2Angle)
                    .offset(orbit2Offset)
                
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: layer1Scale, height: layer1Scale)
                    .rotationEffect(layer1Angle)
                    .offset(orbit1Offset)
            }
            .frame(width: size.width, height: size.height)
            .colorEffect(ShaderLibrary.boostSaturation(.float(1.55)))
            .distortionEffect(
                ShaderLibrary.twistDistortion(
                    .float2(Float(twistOrigin.x), Float(twistOrigin.y)),
                    .float(twistRadius),
                    .float(twistAngle)
                ),
                maxSampleOffset: CGSize(width: 100, height: 100)
            )
            .blur(radius: 65, opaque: true)
            .scaleEffect(1.08) // Prevents edge bleed under heavy blur
        }
    }
}
