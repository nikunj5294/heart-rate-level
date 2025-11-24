//
//  CameraPPGManager.swift
//  FlashRearLatest
//
//  Created by AI Assistant on 20/11/25.
//

import Foundation
import AVFoundation
import CoreVideo
import UIKit

protocol CameraPPGManagerDelegate: AnyObject {
    func ppgManager(didOutput value: Double, at timestamp: TimeInterval)
    func ppgManager(didChangeTorch isOn: Bool)
}

final class CameraPPGManager: NSObject {
    weak var delegate: CameraPPGManagerDelegate?
    
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.ppg.session.queue")
    private let videoQueue = DispatchQueue(label: "camera.ppg.video.queue")
    
    private var isConfigured = false
    private var isRunning = false
    
    func start() {
        sessionQueue.async {
            self.configureIfNeeded()
            guard !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            self.setTorch(enabled: true)
            self.isRunning = true
        }
    }
    
    func stop() {
        sessionQueue.async {
            guard self.captureSession.isRunning else { return }
            self.setTorch(enabled: false)
            self.captureSession.stopRunning()
            self.isRunning = false
        }
    }
    
    private func configureIfNeeded() {
        guard !isConfigured else { return }
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .vga640x480
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            captureSession.commitConfiguration()
            return
        }
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.locked) { device.focusMode = .locked }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isWhiteBalanceModeSupported(.locked) { device.whiteBalanceMode = .locked }
            // Prefer higher frame rate for smoother PPG signal
            if let format = device.activeFormat.videoSupportedFrameRateRanges
                .filter({ $0.maxFrameRate >= 60 }).first {
                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(min(60.0, format.maxFrameRate)))
                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(min(60.0, format.maxFrameRate)))
            }
            device.unlockForConfiguration()
        } catch {
            // fallthrough
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
        } catch {
            captureSession.commitConfiguration()
            return
        }
        
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // Use portrait to keep ROI logic simple
        for connection in videoOutput.connections {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
        
        captureSession.commitConfiguration()
        isConfigured = true
    }
    
    private func setTorch(enabled: Bool) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              device.hasTorch else {
            delegate?.ppgManager(didChangeTorch: false)
            return
        }
        do {
            try device.lockForConfiguration()
            if enabled {
                try device.setTorchModeOn(level: 0.8)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
            delegate?.ppgManager(didChangeTorch: enabled)
        } catch {
            delegate?.ppgManager(didChangeTorch: false)
        }
    }
    
    private func averageRedIntensity(from pixelBuffer: CVPixelBuffer) -> Double {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return 0.0 }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        // BGRA format: 4 bytes per pixel
        let roiWidth = width / 3
        let roiHeight = height / 3
        let startX = (width - roiWidth) / 2
        let startY = (height - roiHeight) / 2
        
        var sum: Double = 0.0
        var count: Int = 0
        
        for y in startY..<(startY + roiHeight) {
            let rowPtr = baseAddress.advanced(by: y * bytesPerRow)
            for x in startX..<(startX + roiWidth) {
                let pixelPtr = rowPtr.advanced(by: x * 4)
                // BGRA
                let r = Double(pixelPtr.load(fromByteOffset: 2, as: UInt8.self))
                sum += r
                count += 1
            }
        }
        guard count > 0 else { return 0.0 }
        return sum / Double(count)
    }
}

extension CameraPPGManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let t = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let ts = CMTimeGetSeconds(t)
        
        let avgRed = averageRedIntensity(from: pixelBuffer)
        delegate?.ppgManager(didOutput: avgRed, at: ts)
    }
}


