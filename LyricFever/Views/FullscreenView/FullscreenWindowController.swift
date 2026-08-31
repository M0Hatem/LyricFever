//
//  FullscreenWindowController.swift
//  Lyric Fever
//

import SwiftUI
import AppKit

@MainActor
final class FullscreenWindowController: NSObject, NSWindowDelegate {
    static let shared = FullscreenWindowController()
    
    private var window: NSWindow?
    private var isTransitioning = false
    
    func toggle() {
        if ViewModel.shared.fullscreen {
            close()
        } else {
            show()
        }
    }
    
    func show() {
        guard !isTransitioning else { return }
        
        // 1. Promote to regular application so macOS creates a dedicated Full Screen Space
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // 2. Create or configure NSWindow
        let fullscreenWindow: NSWindow
        if let existing = window {
            fullscreenWindow = existing
        } else {
            let hosting = NSHostingController(
                rootView: FullscreenView()
                    .preferredColorScheme(.dark)
                    .environment(ViewModel.shared)
            )
            
            let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let win = NSWindow(
                contentRect: screenFrame,
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullScreen],
                backing: .buffered,
                defer: false
            )
            win.title = "Lyric Fever: Fullscreen"
            win.titleVisibility = .hidden
            win.titlebarAppearsTransparent = true
            win.isOpaque = true
            win.tabbingMode = .disallowed
            win.collectionBehavior = [.fullScreenPrimary, .fullScreenAllowsTiling]
            win.contentViewController = hosting
            win.isReleasedWhenClosed = false
            win.delegate = self
            self.window = win
            fullscreenWindow = win
        }
        
        fullscreenWindow.makeKeyAndOrderFront(nil)
        ViewModel.shared.fullscreen = true
        
        // 3. Enter native macOS full screen space
        if !fullscreenWindow.styleMask.contains(.fullScreen) {
            isTransitioning = true
            DispatchQueue.main.async {
                fullscreenWindow.toggleFullScreen(nil)
            }
        }
    }
    
    func close() {
        guard let win = window else {
            cleanup()
            return
        }
        
        if win.styleMask.contains(.fullScreen) {
            isTransitioning = true
            win.toggleFullScreen(nil)
        } else {
            win.orderOut(nil)
            cleanup()
        }
    }
    
    private func cleanup() {
        ViewModel.shared.fullscreen = false
        isTransitioning = false
        
        let hasOtherRegularWindow = NSApp.windows.contains(where: {
            $0.isVisible && $0 != self.window && ($0.identifier?.rawValue == "onboarding" || $0.identifier?.rawValue == "search" || $0.identifier?.rawValue == "update")
        })
        if !hasOtherRegularWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    // MARK: - NSWindowDelegate
    
    func windowDidEnterFullScreen(_ notification: Notification) {
        isTransitioning = false
    }
    
    func windowDidExitFullScreen(_ notification: Notification) {
        isTransitioning = false
        window?.orderOut(nil)
        cleanup()
    }
    
    func windowWillClose(_ notification: Notification) {
        isTransitioning = false
        cleanup()
    }
}
