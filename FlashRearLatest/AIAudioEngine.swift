//
//  AIAudioEngine.swift
//  FlashRearLatest
//
//  Created by AI Assistant on 20/11/25.
//

import Foundation
import AVFoundation

final class AIAudioEngine {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode!
    private let reverb = AVAudioUnitReverb()
    private let delay = AVAudioUnitDelay()
    
    private var baseFrequency: Double = 220.0
    private var vibratoDepth: Double = 2.0
    private var amplitude: Double = 0.15
    private var mood: Mood = .focused
    private var isMuted: Bool = false
    
    private var phase: Double = 0
    private var vibratoPhase: Double = 0
    private let twoPi = 2.0 * Double.pi
    
    init() {
        setupAudioGraph()
    }
    
    private func setupAudioGraph() {
        let sampleRate = AVAudioSession.sharedInstance().sampleRate
        
        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let frames = Int(frameCount)
            
            let vibratoRate = 5.5 // Hz
            for frame in 0..<frames {
                // Vibrato modulation
                let vibrato = self.vibratoDepth * sin(self.vibratoPhase)
                self.vibratoPhase += self.twoPi * vibratoRate / sampleRate
                if self.vibratoPhase > self.twoPi { self.vibratoPhase -= self.twoPi }
                
                let freq = max(60.0, self.baseFrequency + vibrato)
                self.phase += self.twoPi * freq / sampleRate
                if self.phase > self.twoPi { self.phase -= self.twoPi }
                
                // Two oscillators sum for richer tone
                let s1 = sin(self.phase)
                let s2 = sin(self.phase * 0.5)
                let mixed = 0.7 * s1 + 0.3 * s2
                let effectiveAmp = self.isMuted ? 0.0 : self.amplitude
                let value = Float(effectiveAmp * mixed)
                
                for buffer in ablPointer {
                    let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)
                    ptr[frame] = value
                }
            }
            return noErr
        }
        
        reverb.loadFactoryPreset(.largeHall)
        reverb.wetDryMix = 25
        delay.delayTime = 0.25
        delay.feedback = 20
        delay.wetDryMix = 15
        
        engine.attach(sourceNode)
        engine.attach(reverb)
        engine.attach(delay)
        
        let mainMixer = engine.mainMixerNode
        engine.connect(sourceNode, to: delay, format: nil)
        engine.connect(delay, to: reverb, format: nil)
        engine.connect(reverb, to: mainMixer, format: nil)
    }
    
    func start() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
        } catch {
            // Ignore for now
        }
    }
    
    func stop() {
        engine.stop()
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch { }
    }
    
    func update(prediction: Prediction, bpm: Double?) {
        mood = prediction.mood
        if bpm == nil || bpm == 0 {
            isMuted = true
            return
        } else {
            isMuted = false
        }
        // Map BPM and energy to audio params
        let targetBase: Double
        switch mood {
        case .relaxed:
            targetBase = 174.61 // F3
            reverb.wetDryMix = 35
            delay.wetDryMix = 10
        case .focused:
            targetBase = 220.0 // A3
            reverb.wetDryMix = 25
            delay.wetDryMix = 15
        case .excited:
            targetBase = 261.63 // C4
            reverb.wetDryMix = 20
            delay.wetDryMix = 20
        }
        let hrFactor = min(1.4, max(0.8, (bpm ?? 90.0) / 90.0))
        baseFrequency = targetBase * hrFactor
        amplitude = 0.12 + 0.18 * prediction.energy
        vibratoDepth = 0.5 + 4.0 * prediction.energy
        
        // Delay time subtly tied to HR for rhythmic feel
        if let bpm = bpm, bpm > 0 {
            let quarterNoteSec = 60.0 / bpm
            delay.delayTime = max(0.1, min(0.6, quarterNoteSec / 2.0))
        }
    }
    
    func setMuted(_ muted: Bool) {
        isMuted = muted
    }
}


