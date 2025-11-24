//
//  MLPredictor.swift
//  FlashRearLatest
//
//  Created by AI Assistant on 20/11/25.
//

import Foundation

enum Mood: String {
    case relaxed
    case focused
    case excited
}

struct Prediction {
    let mood: Mood
    let energy: Double   // 0..1
}

/// Simple online k-means over 3 clusters using features [bpm, rmssd, quality]
final class OnlineKMeansPredictor {
    private var centroids: [[Double]]
    private var counts: [Int]
    private let learningRate: Double
    
    init() {
        // Seed centroids:
        // relaxed: lower bpm, higher rmssd, good quality
        // focused: mid bpm, mid rmssd
        // excited: higher bpm, lower rmssd
        centroids = [
            [60.0, 0.08, 0.8],
            [85.0, 0.05, 0.7],
            [115.0, 0.02, 0.7]
        ]
        counts = [1, 1, 1]
        learningRate = 0.1
    }
    
    func predictAndUpdate(bpm: Double?, rmssd: Double, quality: Double) -> Prediction {
        // If bpm unknown, guess mid
        let hr = bpm ?? 80.0
        let feature = [hr, rmssd, quality]
        let idx = nearestCentroidIndex(to: feature)
        updateCentroid(index: idx, with: feature)
        
        let mood: Mood
        switch idx {
        case 0: mood = .relaxed
        case 1: mood = .focused
        default: mood = .excited
        }
        
        // Energy heuristic combining bpm and quality
        let normalizedHR = min(1.0, max(0.0, (hr - 50.0) / 80.0))
        let energy = 0.7 * normalizedHR + 0.3 * quality
        return Prediction(mood: mood, energy: energy)
    }
    
    private func nearestCentroidIndex(to feature: [Double]) -> Int {
        var bestIdx = 0
        var bestDist = Double.greatestFiniteMagnitude
        for (i, c) in centroids.enumerated() {
            let d = squaredDistance(a: c, b: feature)
            if d < bestDist {
                bestDist = d
                bestIdx = i
            }
        }
        return bestIdx
    }
    
    private func squaredDistance(a: [Double], b: [Double]) -> Double {
        zip(a, b).map { ($0 - $1) * ($0 - $1) }.reduce(0, +)
    }
    
    private func updateCentroid(index: Int, with feature: [Double]) {
        counts[index] += 1
        // Exponential moving average update
        let lr = learningRate
        centroids[index] = zip(centroids[index], feature).map { $0 + lr * ($1 - $0) }
    }
}


