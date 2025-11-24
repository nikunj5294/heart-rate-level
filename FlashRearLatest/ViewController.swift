//
//  ViewController.swift
//  FlashRearLatest
//
//  Created by Inexture Solutions Limited on 20/11/25.
//

import UIKit
import AVFoundation
import DGCharts

class ViewController: UIViewController {
    private let ppgManager = CameraPPGManager()
    private let predictor = OnlineKMeansPredictor()
    private let audioEngine = AIAudioEngine()
    
    private var chartView: LineChartView!
    private var chartDataSet: LineChartDataSet!
    private var sampleIndex: Double = 0
    private let maxVisiblePoints: Double = 300
    private var heartRateLabel: UILabel!
    private var moodLabel: UILabel!
    private var bpmDetailLabel: UILabel!
    private var explanationLabel: UILabel!
    private var torchStatusLabel: UILabel!
    private var startButton: UIButton!
    private var stopButton: UIButton!
    private var infoCard: UIView!
    private var headerStack: UIStackView!
    private var buttonsStack: UIStackView!
    private var infoScrollView: UIScrollView!
    
    private var gradientLayer: CAGradientLayer?
    private var isTorchOn: Bool = false
    private var isContact: Bool = false
    private var noContactFrames: Int = 0
    
    private var timestamps: [Double] = []
    private var values: [Double] = []
    private let maxBufferSeconds: Double = 15.0
    
    private var lastEstimate: HeartRateEstimate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        ppgManager.delegate = self
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if gradientLayer == nil {
            let g = CAGradientLayer()
            g.colors = [
                UIColor.systemIndigo.withAlphaComponent(0.18).cgColor,
                UIColor.systemBackground.cgColor
            ]
            g.locations = [0.0, 1.0]
            g.startPoint = CGPoint(x: 0.5, y: 0.0)
            g.endPoint = CGPoint(x: 0.5, y: 1.0)
            g.frame = view.bounds
            view.layer.insertSublayer(g, at: 0)
            gradientLayer = g
        } else {
            gradientLayer?.frame = view.bounds
        }
        if let infoCard = infoCard {
            infoCard.layer.shadowPath = UIBezierPath(roundedRect: infoCard.bounds, cornerRadius: 14).cgPath
        }
    }
    
    private func setupUI() {
        chartView = LineChartView(frame: .zero)
        chartView.translatesAutoresizingMaskIntoConstraints = false
        configureChart()
        
        heartRateLabel = UILabel()
        heartRateLabel.translatesAutoresizingMaskIntoConstraints = false
        heartRateLabel.text = "HR: -- bpm"
        heartRateLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .semibold)
        
        moodLabel = UILabel()
        moodLabel.translatesAutoresizingMaskIntoConstraints = false
        moodLabel.text = "Mood: --"
        moodLabel.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        moodLabel.textColor = .secondaryLabel
        
        torchStatusLabel = UILabel()
        torchStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        torchStatusLabel.text = "Torch: --"
        torchStatusLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        torchStatusLabel.textColor = .secondaryLabel
        
        startButton = UIButton(type: .system)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.setTitle("Start", for: .normal)
        startButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        startButton.addTarget(self, action: #selector(onStart), for: .touchUpInside)
        
        stopButton = UIButton(type: .system)
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.setTitle("Stop", for: .normal)
        stopButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        stopButton.addTarget(self, action: #selector(onStop), for: .touchUpInside)
        stopButton.isEnabled = false
        
        // Style buttons
        stylePrimaryButton(startButton)
        styleSecondaryButton(stopButton)
        
        // Detailed BPM explanation label
        bpmDetailLabel = UILabel()
        bpmDetailLabel.translatesAutoresizingMaskIntoConstraints = false
        bpmDetailLabel.text = "Place your fingertip over the rear camera and flash. Hold still for 20–30 seconds."
        bpmDetailLabel.numberOfLines = 0
        bpmDetailLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        bpmDetailLabel.textColor = .secondaryLabel
        
        // On-screen explanation of centroids
        explanationLabel = UILabel()
        explanationLabel.translatesAutoresizingMaskIntoConstraints = false
        explanationLabel.numberOfLines = 0
        explanationLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        explanationLabel.textColor = .secondaryLabel
        explanationLabel.text =
        """
        Seed centroids:
        • Relaxed: lower BPM, higher RMSSD, good quality
        • Focused: mid BPM, mid RMSSD
        • Excited: higher BPM, lower RMSSD
        
        Levels (BPM → Mood examples):
        • 20–40 → Relaxed
        • 41–60 → Relaxed
        • 61–80 → Focused
        • 81–100 → Focused
        • 101–130 → Excited
        • 131+ → Excited
        
        Notes:
        • RMSSD reflects beat‑to‑beat variability; higher often means calmer state.
        • Hold finger steady fully covering camera + flash for best quality.
        • If contact is lost, HR may show 0 and the chart will flatten.
        """
        
        headerStack = UIStackView(arrangedSubviews: [heartRateLabel, UIView(), moodLabel])
        headerStack.axis = .horizontal
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.alignment = .center
        
        buttonsStack = UIStackView(arrangedSubviews: [startButton, stopButton, torchStatusLabel])
        buttonsStack.axis = .horizontal
        buttonsStack.spacing = 16
        buttonsStack.alignment = .center
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Card to hold header + details
        infoCard = makeCard()
        infoCard.translatesAutoresizingMaskIntoConstraints = false
        infoCard.addSubview(headerStack)
        infoCard.addSubview(bpmDetailLabel)
        
        view.addSubview(infoCard)
        view.addSubview(chartView)
        view.addSubview(buttonsStack)
        
        // Scrollable container for the bottom description
        infoScrollView = UIScrollView()
        infoScrollView.translatesAutoresizingMaskIntoConstraints = false
        infoScrollView.alwaysBounceVertical = true
        view.addSubview(infoScrollView)
        infoScrollView.addSubview(explanationLabel)
        
        NSLayoutConstraint.activate([
            infoCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            infoCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            infoCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            headerStack.topAnchor.constraint(equalTo: infoCard.topAnchor, constant: 12),
            headerStack.leadingAnchor.constraint(equalTo: infoCard.leadingAnchor, constant: 12),
            headerStack.trailingAnchor.constraint(equalTo: infoCard.trailingAnchor, constant: -12),
            
            bpmDetailLabel.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
            bpmDetailLabel.leadingAnchor.constraint(equalTo: infoCard.leadingAnchor, constant: 12),
            bpmDetailLabel.trailingAnchor.constraint(equalTo: infoCard.trailingAnchor, constant: -12),
            bpmDetailLabel.bottomAnchor.constraint(equalTo: infoCard.bottomAnchor, constant: -12),
            
            chartView.topAnchor.constraint(equalTo: infoCard.bottomAnchor, constant: 12),
            chartView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            chartView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            chartView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5),
            
            buttonsStack.topAnchor.constraint(equalTo: chartView.bottomAnchor, constant: 16),
            buttonsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            buttonsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // Scroll view layout
            infoScrollView.topAnchor.constraint(equalTo: buttonsStack.bottomAnchor, constant: 12),
            infoScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            infoScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            infoScrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            
            // Explanation inside scroll view (content layout)
            explanationLabel.topAnchor.constraint(equalTo: infoScrollView.contentLayoutGuide.topAnchor),
            explanationLabel.leadingAnchor.constraint(equalTo: infoScrollView.contentLayoutGuide.leadingAnchor),
            explanationLabel.trailingAnchor.constraint(equalTo: infoScrollView.contentLayoutGuide.trailingAnchor),
            explanationLabel.bottomAnchor.constraint(equalTo: infoScrollView.contentLayoutGuide.bottomAnchor),
            explanationLabel.widthAnchor.constraint(equalTo: infoScrollView.frameLayoutGuide.widthAnchor)
        ])
    }
    
    @objc private func onStart() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                guard granted else {
                    let alert = UIAlertController(title: "Camera Access Needed",
                                                  message: "Please allow camera permission to measure heart rate using the rear camera and flash.",
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                    return
                }
                self.resetBuffers()
                self.audioEngine.start()
                self.ppgManager.start()
                self.startButton.isEnabled = false
                self.stopButton.isEnabled = true
            }
        }
    }
    
    @objc private func onStop() {
        ppgManager.stop()
        audioEngine.stop()
        startButton.isEnabled = true
        stopButton.isEnabled = false
    }
    
    private func resetBuffers() {
        timestamps.removeAll()
        values.removeAll()
        resetChart()
        lastEstimate = nil
    }
    
    private func pruneBuffers() {
        guard let lastTs = timestamps.last else { return }
        var firstValidIndex = 0
        for (i, t) in timestamps.enumerated() {
            if lastTs - t <= maxBufferSeconds {
                firstValidIndex = i
                break
            }
        }
        if firstValidIndex > 0 {
            timestamps.removeFirst(firstValidIndex)
            values.removeFirst(firstValidIndex)
        }
    }
    
    private func configureChart() {
        chartView.rightAxis.enabled = false
        chartView.legend.enabled = false
        chartView.chartDescription.enabled = false
        chartView.xAxis.labelPosition = .bottom
        chartView.xAxis.drawGridLinesEnabled = false
        chartView.xAxis.labelTextColor = .secondaryLabel
        chartView.leftAxis.labelTextColor = .secondaryLabel
        chartView.leftAxis.gridColor = .tertiaryLabel
        chartView.setScaleEnabled(false)
        chartView.setVisibleXRangeMaximum(maxVisiblePoints)
        
        chartDataSet = LineChartDataSet(entries: [], label: "")
        chartDataSet.mode = .cubicBezier
        chartDataSet.drawCirclesEnabled = false
        chartDataSet.lineWidth = 2
        chartDataSet.setColor(.systemGreen)
        chartDataSet.drawValuesEnabled = false
        chartDataSet.drawFilledEnabled = true
        let gradientColors = [UIColor.systemGreen.withAlphaComponent(0.35).cgColor,
                              UIColor.clear.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors, locations: [0.0, 1.0]) {
            chartDataSet.fill = LinearGradientFill(gradient: gradient, angle: 90.0)
        }
        
        chartView.data = LineChartData(dataSet: chartDataSet)
        chartView.animate(xAxisDuration: 0.3)
    }
    
    private func resetChart() {
        sampleIndex = 0
        chartDataSet?.replaceEntries([])
        chartView.data = LineChartData(dataSet: chartDataSet)
        chartView.setVisibleXRangeMaximum(maxVisiblePoints)
        chartView.moveViewToX(0)
        chartView.setNeedsDisplay()
    }
    
    private func appendChart(value: Double) {
        DispatchQueue.main.async {
            let entry = ChartDataEntry(x: self.sampleIndex, y: value)
            self.chartDataSet.append(entry)
            self.sampleIndex += 1
            
            self.chartView.data?.notifyDataChanged()
            self.chartView.notifyDataSetChanged()
            self.chartView.moveViewToX(self.sampleIndex)
        }
    }
    
    private func detectContact() -> Bool {
        // Heuristic: require recent window and torch on
        let window = min(values.count, 25)
        guard window >= 15, isTorchOn else { return false }
        let recent = values.suffix(window)
        let mean = recent.reduce(0, +) / Double(window)
        let variance = recent.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(window)
        let std = sqrt(max(variance, 0))
        // With finger, mean red tends to be higher and variance moderate due to pulse
        return mean > 110.0 && std < 30.0
    }
    
    private func updateStatusLabel() {
        let contactText = isContact ? "Contact: Yes" : "Contact: No"
        DispatchQueue.main.async {
            self.torchStatusLabel.text = "Torch: " + (self.isTorchOn ? "On" : "Off") + " • " + contactText
        }
    }
    
    private func showNoContactState() {
        DispatchQueue.main.async {
            self.heartRateLabel.text = "HR: 0 bpm"
            self.moodLabel.text = "Mood: No contact"
            self.bpmDetailLabel.text = "No fingertip detected. Cover the rear camera and flash fully and hold still."
        }
        audioEngine.setMuted(true)
    }
    
    private func showContactState() {
        audioEngine.setMuted(false)
    }
    
    private func stylePrimaryButton(_ b: UIButton) {
        b.backgroundColor = UIColor.systemBlue
        b.tintColor = UIColor.white
        b.layer.cornerRadius = 10
        b.contentEdgeInsets = UIEdgeInsets(top: 10, left: 18, bottom: 10, right: 18)
    }
    
    private func styleSecondaryButton(_ b: UIButton) {
        b.backgroundColor = UIColor.systemGray5
        b.tintColor = UIColor.label
        b.layer.cornerRadius = 10
        b.contentEdgeInsets = UIEdgeInsets(top: 10, left: 18, bottom: 10, right: 18)
    }
    
    private func makeCard() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.secondarySystemBackground
        v.layer.cornerRadius = 14
        v.layer.shadowColor = UIColor.black.withAlphaComponent(0.15).cgColor
        v.layer.shadowOpacity = 1
        v.layer.shadowRadius = 12
        v.layer.shadowOffset = CGSize(width: 0, height: 6)
        return v
    }
    
    private func interpretationText(for bpm: Double?, quality: Double) -> String {
        guard quality > 0.2 else {
            return "Signal quality is low. Keep your finger steady and fully covering the camera and flash."
        }
        guard let bpm = bpm else {
            return "Measuring... Typical resting is ~60–100 bpm. Athletes can be lower."
        }
        let rangeHint: String
        if bpm < 50 {
            rangeHint = "Lower than typical resting. If you feel unwell, consult a professional."
        } else if bpm < 60 {
            rangeHint = "On the lower side. Can be normal for well-trained individuals."
        } else if bpm <= 100 {
            rangeHint = "Within typical resting range for adults."
        } else if bpm <= 120 {
            rangeHint = "Slightly elevated. Movement, stress, or caffeine may raise it."
        } else {
            rangeHint = "High. Consider resting. If persistent and you feel unwell, seek advice."
        }
        return "Your estimated heart rate is \(Int(bpm)) bpm. \(rangeHint)"
    }
}

extension ViewController: CameraPPGManagerDelegate {
    func ppgManager(didOutput value: Double, at timestamp: TimeInterval) {
        timestamps.append(timestamp)
        values.append(value)
        pruneBuffers()
        
        // Determine contact state
        let contactNow = detectContact()
        if contactNow {
            noContactFrames = 0
        } else {
            noContactFrames += 1
        }
        isContact = contactNow
        updateStatusLabel()
        
        // Graph should reflect contact: zero when no contact
        appendChart(value: contactNow ? value : 0.0)
        
        if values.count % 15 == 0 {
            if contactNow {
                let estimate = SignalProcessor.estimateHeartRate(timestamps: timestamps, rawSignal: values)
                lastEstimate = estimate
                
                let bpmStr: String
                if let bpm = estimate.bpm, estimate.quality > 0.2 {
                    bpmStr = String(format: "%.0f", bpm)
                } else {
                    bpmStr = "--"
                }
                DispatchQueue.main.async {
                    self.heartRateLabel.text = "HR: \(bpmStr) bpm"
                    self.bpmDetailLabel.text = self.interpretationText(for: estimate.bpm, quality: estimate.quality)
                }
                
                let rmssd = SignalProcessor.rmssd(from: estimate.rrIntervals)
                let prediction = predictor.predictAndUpdate(bpm: estimate.bpm, rmssd: rmssd, quality: estimate.quality)
                DispatchQueue.main.async {
                    self.moodLabel.text = "Mood: \(prediction.mood.rawValue.capitalized)"
                }
                audioEngine.update(prediction: prediction, bpm: estimate.bpm)
                showContactState()
            } else {
                // After brief loss, clear buffers to avoid stale estimates
                if noContactFrames >= 30 {
                    timestamps.removeAll()
                    values.removeAll()
                }
                DispatchQueue.main.async {
                    self.showNoContactState()
                }
                // Drive audio to muted state
                audioEngine.update(prediction: Prediction(mood: .focused, energy: 0.0), bpm: 0)
            }
        }
    }
    
    func ppgManager(didChangeTorch isOn: Bool) {
        isTorchOn = isOn
        DispatchQueue.main.async { self.updateStatusLabel() }
    }
}

