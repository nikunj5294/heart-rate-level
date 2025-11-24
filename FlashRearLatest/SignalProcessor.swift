//
//  SignalProcessor.swift
//  FlashRearLatest
//
//  Created by AI Assistant on 20/11/25.
//

import Foundation

struct HeartRateEstimate {
    let bpm: Double?
    let quality: Double
    let rrIntervals: [Double]
}

enum SignalProcessor {
    static func movingAverage(values: [Double], window: Int) -> [Double] {
        guard window > 1, values.count >= window else { return values }
        var result = [Double](repeating: 0.0, count: values.count)
        var sum = 0.0
        for i in 0..<values.count {
            sum += values[i]
            if i >= window {
                sum -= values[i - window]
            }
            let denom = Double(min(i + 1, window))
            result[i] = sum / denom
        }
        return result
    }
    
    static func detrend(values: [Double], window: Int) -> [Double] {
        let ma = movingAverage(values: values, window: window)
        guard ma.count == values.count else { return values }
        return zip(values, ma).map { $0 - $1 }
    }
    
    static func lowPass(values: [Double], alpha: Double) -> [Double] {
        guard !values.isEmpty else { return [] }
        var output = [Double](repeating: 0.0, count: values.count)
        output[0] = values[0]
        for i in 1..<values.count {
            output[i] = output[i - 1] + alpha * (values[i] - output[i - 1])
        }
        return output
    }
    
    static func normalizeZeroMeanUnitVar(values: [Double]) -> [Double] {
        guard !values.isEmpty else { return [] }
        let mean = values.reduce(0, +) / Double(values.count)
        let centered = values.map { $0 - mean }
        let varVal = centered.map { $0 * $0 }.reduce(0, +) / max(1.0, Double(values.count - 1))
        let std = sqrt(max(varVal, 1e-9))
        return centered.map { $0 / std }
    }
    
    static func detectPeaks(values: [Double], timestamps: [Double], minDistanceSec: Double, threshold: Double) -> [Int] {
        guard values.count == timestamps.count, values.count > 2 else { return [] }
        var peaks: [Int] = []
        var lastPeakTime: Double = -Double.greatestFiniteMagnitude
        
        for i in 1..<(values.count - 1) {
            let isPeak = values[i] > values[i - 1] && values[i] > values[i + 1] && values[i] > threshold
            if isPeak {
                let t = timestamps[i]
                if (t - lastPeakTime) >= minDistanceSec {
                    peaks.append(i)
                    lastPeakTime = t
                }
            }
        }
        return peaks
    }
    
    static func estimateHeartRate(timestamps: [Double], rawSignal: [Double]) -> HeartRateEstimate {
        guard rawSignal.count >= 60, rawSignal.count == timestamps.count else {
            return HeartRateEstimate(bpm: nil, quality: 0.0, rrIntervals: [])
        }
        
        // Preprocess: detrend and low-pass
        // Window ~ 1 sec moving average (assume ~30-60 fps)
        let detrended = detrend(values: rawSignal, window: 30)
        let smoothed = lowPass(values: detrended, alpha: 0.2)
        let normalized = normalizeZeroMeanUnitVar(values: smoothed)
        
        // Estimate sample rate
        let duration = (timestamps.last! - timestamps.first!)
        let sampleRate = duration > 0 ? Double(rawSignal.count) / duration : 30.0
        
        // Expect HR between 40 - 180 BPM -> period 0.33 - 1.5 sec
        let minDistance = 0.33
        // Adaptive threshold
        let std = max(1e-6, normalized.map { $0 * $0 }.reduce(0, +) / Double(normalized.count)).squareRoot()
        let threshold = 0.3 * std
        
        let peaks = detectPeaks(values: normalized, timestamps: timestamps, minDistanceSec: minDistance, threshold: threshold)
        guard peaks.count >= 3 else {
            let quality = min(0.3, Double(peaks.count) / 3.0)
            return HeartRateEstimate(bpm: nil, quality: quality, rrIntervals: [])
        }
        
        var intervals: [Double] = []
        for i in 1..<peaks.count {
            let dt = timestamps[peaks[i]] - timestamps[peaks[i - 1]]
            if dt > 0.25 && dt < 2.0 {
                intervals.append(dt)
            }
        }
        guard !intervals.isEmpty else {
            return HeartRateEstimate(bpm: nil, quality: 0.2, rrIntervals: [])
        }
        let meanDt = intervals.reduce(0, +) / Double(intervals.count)
        let bpm = 60.0 / meanDt
        
        // Quality metric: peak count consistency and signal std
        let expectedPeaks = Int(duration / meanDt)
        let consistency = min(1.0, Double(peaks.count) / Double(max(1, expectedPeaks)))
        let quality = max(0.0, min(1.0, 0.5 * consistency + 0.5 * min(1.0, std)))
        
        return HeartRateEstimate(bpm: bpm, quality: quality, rrIntervals: intervals)
    }
    
    static func rmssd(from intervals: [Double]) -> Double {
        guard intervals.count >= 2 else { return 0.0 }
        var diffsSquared: [Double] = []
        for i in 1..<intervals.count {
            let diff = intervals[i] - intervals[i - 1]
            diffsSquared.append(diff * diff)
        }
        let mean = diffsSquared.reduce(0, +) / Double(diffsSquared.count)
        return sqrt(mean)
    }
}


