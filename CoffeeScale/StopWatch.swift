//
//  StopWatch.swift
//  CoffeeScale
//
//  Created by Dmitry on 10.06.2024.
//

import Foundation
import SwiftUI

class StopWatch: ObservableObject {
    
    enum stopWatchState {
        case running
        case stopped
        case paused
    }
    
    @Published var state: stopWatchState = .stopped
    @Published var elapsedTime: Float = 0.0
    private var timer = Timer()
    
    func start() {
        state = .running
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            timer in
            self.elapsedTime += 0.1
        }
    }
    
    func pause() {
        timer.invalidate()
        state = .paused
    }
    
    func stop() {
        timer.invalidate()
        elapsedTime = 0
        state = .stopped
    }
    
}
