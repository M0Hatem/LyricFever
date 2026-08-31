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
    private var lastActivityTime: TimeInterval = 0
    private var lastTimerScheduleTime: TimeInterval = 0
    
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
        let now = ProcessInfo.processInfo.systemUptime
        lastActivityTime = now
        
        if !isControlsVisible {
            withAnimation(.easeOut(duration: 0.25)) {
                isControlsVisible = true
                isIdleMetadataVisible = false
            }
        }
        
        // Debounce timer recreation: avoid creating new Timer on every mouseMoved event
        if idleTimer == nil || (now - lastTimerScheduleTime) > 0.5 {
            idleTimer?.invalidate()
            lastTimerScheduleTime = now
            idleTimer = Timer.scheduledTimer(withTimeInterval: idleTimeout, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.checkIdleTimeout()
                }
            }
        }
    }
    
    private func checkIdleTimeout() {
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = now - lastActivityTime
        if elapsed < idleTimeout {
            // Activity occurred recently, wait remaining time
            let remaining = max(0.5, idleTimeout - elapsed)
            idleTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.checkIdleTimeout()
                }
            }
            return
        }
        
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
}
