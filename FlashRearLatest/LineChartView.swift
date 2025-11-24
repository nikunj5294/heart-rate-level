//
//  LineChartView.swift
//  FlashRearLatest
//
//  Created by AI Assistant on 20/11/25.
//

import UIKit

final class PPGChartView: UIView {
    private var data: [Double] = []
    private var maxPoints: Int = 300
    
    private let lineColor = UIColor.systemGreen
    private let axisColor = UIColor.secondaryLabel
    private let bgColor = UIColor.systemBackground
    
    func configure(maxPoints: Int) {
        self.maxPoints = max(30, maxPoints)
        setNeedsDisplay()
    }
    
    func append(value: Double) {
        data.append(value)
        if data.count > maxPoints {
            data.removeFirst(data.count - maxPoints)
        }
        DispatchQueue.main.async {
            self.setNeedsDisplay()
        }
    }
    
    func reset() {
        data.removeAll()
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setFillColor(bgColor.cgColor)
        ctx.fill(rect)
        
        // Axes
        ctx.setStrokeColor(axisColor.cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: rect.minX, y: rect.midY))
        ctx.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        ctx.strokePath()
        
        guard data.count >= 2 else { return }
        let minVal = data.min() ?? 0
        let maxVal = data.max() ?? 1
        let range = max(1e-6, maxVal - minVal)
        
        ctx.setStrokeColor(lineColor.cgColor)
        ctx.setLineWidth(2)
        let stepX = rect.width / CGFloat(max(1, data.count - 1))
        for i in 0..<(data.count - 1) {
            let x1 = rect.minX + CGFloat(i) * stepX
            let x2 = rect.minX + CGFloat(i + 1) * stepX
            let y1 = rect.maxY - CGFloat((data[i] - minVal) / range) * rect.height
            let y2 = rect.maxY - CGFloat((data[i + 1] - minVal) / range) * rect.height
            ctx.move(to: CGPoint(x: x1, y: y1))
            ctx.addLine(to: CGPoint(x: x2, y: y2))
            ctx.strokePath()
        }
    }
}


