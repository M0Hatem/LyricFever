//
//  FullscreenIdleCoordinator.swift
//  Lyric Fever
//
//  Created by Antigravity on 2026-08-31.
//

import SwiftUI
import AppKit
import Combine

@MainActor
@Observable final class FullscreenIdleCoordinator {
    var isControlsVisible: Bool = true
    var isIdleMetadataVisible: Bool = false
    var isHoveringOrScrubbing: Bool = false {
        didSet {
            if isHoveringOrScrubbing {
                userActivityDetected()
            }
        }
    }
    
    private var idleTimer: Timer?
    private var eventMonitor: Any?
    private let idleTimeout: TimeInterval = 3.0
    
    init() {}
    
    func startMonitoring() {
        userActivityDetected()
        
        #if os(macOS)
        if eventMonitor == nil {
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]) { [weak self] event in
                self?.userActivityDetected()
                return event
            }
        }
        #endif
    }
    
    func stopMonitoring() {
        #if os(macOS)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        #endif
        idleTimer?.invalidate()
        idleTimer = nil
        isControlsVisible = true
        isIdleMetadataVisible = false
    }
    
    func userActivityDetected() {
        if !isControlsVisible {
            withAnimation(.easeOut(duration: 0.25)) {
                isControlsVisible = true
                isIdleMetadataVisible = false
            }
        }
        
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleIdleTimeout()
            }
        }
    }
    
    private func handleIdleTimeout() {
        guard !isHoveringOrScrubbing else {
            // Postpone if user is hovering over interactive elements or dragging scrubber
            userActivityDetected()
            return
        }
        
        withAnimation(.easeOut(duration: 0.35)) {
            isControlsVisible = false
            isIdleMetadataVisible = true
        }
        
        #if os(macOS)
        NSCursor.setHiddenUntilMouseMoves(true)
        #endif
    }
    
    deinit {
        // Cleanup resources
    }
}
