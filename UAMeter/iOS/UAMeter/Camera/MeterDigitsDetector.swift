import AVFoundation
import CoreML
import UIKit
import Vision

final class MeterDigitsDetector: UIView {
    private let detector = MeterDetector()
    private var lastDetectionTime = Date()
    private let detectionInterval: TimeInterval = 1.0
    var onValueDetected: ((MeterReading) -> Void)?

    private lazy var yoloModel: DigitsYOLO? = {
        try? DigitsYOLO(configuration: MLModelConfiguration())
    }()
    private let confidenceThreshold: Float = 0.25
    private let classLabels: [String] = ["0", "1", "10", "2", "3", "4", "5", "6", "7", "8", "9"]

    func handleSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard Date().timeIntervalSince(lastDetectionTime) > detectionInterval else { return }
        lastDetectionTime = Date()
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        detectDigits(in: pixelBuffer)
    }
    
    func regionOfInterest() -> CGRect {
        // розрахунок прямокутника рамки у відносних координатах (Vision очікує normalized rect)
        let width: CGFloat = 0.7
        let height: CGFloat = 0.3
        let x = (1 - width) / 2
        let y = (1 - height) / 2
        return CGRect(x: x, y: y, width: width, height: height)
    }
    private func detectDigits(in pixelBuffer: CVPixelBuffer) {
        guard let model = yoloModel else { return }

        // Використовуємо Vision, щоб не турбуватися про масштабування CVPixelBuffer
        guard let vnModel = try? VNCoreMLModel(for: model.model) else { return }
        let request = VNCoreMLRequest(model: vnModel) { [weak self] req, _ in
            guard let self else { return }
            guard let results = req.results as? [VNCoreMLFeatureValueObservation] else { return }

            guard
                let confidence = results.first(where: { $0.featureName == "confidence" })?.featureValue.multiArrayValue,
                let coordinates = results.first(where: { $0.featureName == "coordinates" })?.featureValue.multiArrayValue
            else { return }

            let digits = self.decodeDigits(confidence: confidence, coordinates: coordinates)
            guard !digits.isEmpty else { return }

            print("🤖 YOLO digits:", digits)
            let lines = [digits]
            if let reading = self.detector.detect(from: lines) ?? self.fallbackReading(from: digits) {
                print("📟 \(reading.type.rawValue) = \(reading.value)")
                self.onValueDetected?(reading)
            }
        }
        request.imageCropAndScaleOption = .centerCrop
        request.regionOfInterest = regionOfInterest()

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([request])
    }

    private func decodeDigits(confidence: MLMultiArray, coordinates: MLMultiArray) -> String {
        guard confidence.shape.count == 2, coordinates.shape.count == 2 else { return "" }
        let numDetections = confidence.shape[0].intValue
        let numClasses = confidence.shape[1].intValue

        var detected: [(digit: String, x: Float)] = []

        for det in 0..<numDetections {
            var bestScore: Float = 0
            var bestClass = -1

            for cls in 0..<numClasses {
                let score = confidence[[NSNumber(value: det), NSNumber(value: cls)]].floatValue
                if score > bestScore {
                    bestScore = score
                    bestClass = cls
                }
            }

            guard bestScore >= confidenceThreshold, bestClass >= 0 else { continue }

            let cx = coordinates[[NSNumber(value: det), 0]].floatValue
            let w  = coordinates[[NSNumber(value: det), 2]].floatValue
            let digit = label(for: bestClass)
            detected.append((digit: digit, x: cx - w * 0.5))
        }

        let sorted = detected.sorted { $0.x < $1.x }
        return sorted.map { $0.digit }.joined()
    }

    private func label(for index: Int) -> String {
        if index < classLabels.count {
            return classLabels[index]
        } else {
            return "\(index)"
        }
    }

    private func fallbackReading(from digits: String) -> MeterReading? {
        // Якщо YOLO розпізнало тільки цифри без контексту, трактуємо 8-значне число як total.
        if digits.count == 8 {
            return MeterReading(type: .total, value: digits)
        }
        return nil
    }
}
