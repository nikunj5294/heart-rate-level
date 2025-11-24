## FlashRearLatest — Real‑time heart‑rate from phone camera/flash

### Overview
FlashRearLatest is an iOS sample app that estimates heart rate in real time using photoplethysmography (PPG) from the iPhone’s rear camera with the flash as a light source. It visualizes the live signal, estimates BPM, infers a simple “mood” state from HRV‑like features, and adapts ambient audio accordingly.

> Important: This app is intended for research and educational use only. It is not a medical device and is not intended for diagnosis or treatment.

### How it works (high level)
- The rear camera captures frames while the torch (flash) illuminates the fingertip covering the lens.
- A PPG signal is derived from per‑frame intensity values.
- The signal is filtered and peak intervals are converted to BPM and RR intervals; RMSSD is computed as a simple HRV proxy.
- An online K‑Means style predictor classifies a coarse state (Relaxed / Focused / Excited).
- The UI shows the live waveform and updates BPM and “mood”; an audio engine adapts sound based on the prediction.

### Key features
- **Real‑time PPG** from camera + torch
- **Live chart** with DGCharts
- **Continuous BPM estimate** with quality gating
- **Simple mood inference** using online clustering (BPM + RMSSD)
- **Adaptive audio feedback**

### Requirements
- **Device**: iPhone with a rear camera and flash (torch)
- **iOS**: 15.0+
- **Xcode**: 15+ (Swift 5.9+)
- **Permissions**: Camera access

### Getting started
1. Open `FlashRearLatest.xcodeproj` in Xcode.
2. Ensure Swift Package dependencies resolve (DGCharts is included via SPM).
3. Connect a physical iPhone (simulators cannot access camera/torch).
4. Build and run. On first launch, grant camera permission.

### Usage
1. Tap “Start”.
2. Gently cover the rear camera and flash fully with your fingertip.
3. Hold still for 20–30 seconds for a stable reading.
4. Watch the live waveform and BPM. The “mood” label will update as the model adapts.
5. Tap “Stop” to end measurement.

Tips for better readings:
- Keep the fingertip steady and apply light, consistent pressure.
- Avoid excessive movement; keep the camera module fully covered.
- If contact is lost, the signal flattens and BPM may show 0 or “--”.

### Project structure (selected files)
- `FlashRearLatest/ViewController.swift`: Screen UI, live chart, start/stop, state updates
- `FlashRearLatest/CameraPPGManager.swift`: Camera session, torch control, raw intensity extraction
- `FlashRearLatest/SignalProcessor.swift`: Filtering, peak detection, BPM and RR extraction, RMSSD
- `FlashRearLatest/MLPredictor.swift`: Online K‑Means predictor producing coarse mood state
- `FlashRearLatest/AIAudioEngine.swift`: Simple audio engine reacting to prediction/BPM
- `FlashRearLatest/LineChartView.swift`: Chart configuration helpers (DGCharts)
- `FlashRearLatest/Info.plist`: Usage descriptions (e.g., camera permission)

### Data flow
Camera + Torch → `CameraPPGManager` → raw PPG values → `SignalProcessor` → {BPM, RR, RMSSD, quality} → `OnlineKMeansPredictor` → mood → UI + `AIAudioEngine`

### Permissions
The app requests Camera access to read frames for PPG. Add/update `NSCameraUsageDescription` in `Info.plist` with a clear explanation (already included in this project).

### Troubleshooting
- **No camera permission**: Grant in iOS Settings → Privacy → Camera.
- **Torch remains off**: Ensure device supports torch and battery level isn’t critically low.
- **Flat line / 0 BPM**: Improve contact and stillness; fully cover camera + flash.
- **Inconsistent BPM**: Wait 20–30 seconds; minimize motion and pressure changes.
- **Build errors on dependencies**: In Xcode, File → Packages → Reset Package Caches, then resolve.

### Privacy
All processing occurs on-device. No data is transmitted off the device by default.

### Disclaimer
This software is not a medical device and is not intended for diagnostic or therapeutic use. Do not rely on it for health decisions. Consult a qualified professional for medical advice.

### Roadmap
- Improved peak detection and motion artifact rejection
- Calibration flows and per‑device tuning
- Export/Share of anonymized summaries (opt‑in)
- Expanded audio biofeedback modes

### Acknowledgments
- Charts: `DGCharts` (Swift package)

### License
Specify a license for your project (e.g., MIT) or add a `LICENSE` file.


