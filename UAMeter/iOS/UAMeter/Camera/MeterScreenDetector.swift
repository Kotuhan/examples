import CoreML
import UIKit
import Vision

final class MeterScreenDetector {
    private let model: VNCoreMLModel
    private weak var overlayLayer: CAShapeLayer?
    var onReadingDetected: ((MeterReading) -> Void)? // 👈 новий колбек
    var onDebugImage: ((UIImage) -> Void)?
    private let ciContext = CIContext()

    init?(overlayLayer: CAShapeLayer) {
        self.overlayLayer = overlayLayer
        guard let mlModel = try? ScreenBoundaryML(configuration: MLModelConfiguration()).model,
              let vnModel = try? VNCoreMLModel(for: mlModel)
        else {
            print("❌ Не вдалося завантажити ML модель")
            return nil
        }
        self.model = vnModel
    }

    func detect(in pixelBuffer: CVPixelBuffer) {
        let request = VNCoreMLRequest(model: model) { [weak self] req, _ in
            guard
                let self,
                let results = req.results as? [VNRecognizedObjectObservation],
                let best = results.first
            else { return }

            DispatchQueue.main.async {
                self.drawBox(for: best)
                self.detectText(in: pixelBuffer, region: best.boundingBox)
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)
        try? handler.perform([request])
    }

    // MARK: - OCR в межах рамки
    private func detectText(in pixelBuffer: CVPixelBuffer, region: CGRect) {
        guard let processed = preprocess(pixelBuffer: pixelBuffer, region: region) else { return }
        let debugBase = processed.debug

        let request = VNRecognizeTextRequest { [weak self] req, _ in
            guard
                let self,
                let results = req.results as? [VNRecognizedTextObservation]
            else { return }

            let rawLines = results.compactMap { $0.topCandidates(1).first?.string }
            print("🧾 OCR raw lines:", rawLines)

            // Повний лог OCR-результатів
            for (idx, obs) in results.enumerated() {
                let candidates = obs.topCandidates(5)
                for (cIdx, cand) in candidates.enumerated() {
                    print("🧾 OCR[\(idx)] cand[\(cIdx)] conf=\(cand.confidence): \"\(cand.string)\" box=\(obs.boundingBox)")
                }
            }

            if let annotated = self.annotate(image: debugBase, with: results) {
                DispatchQueue.main.async { [weak self] in
                    self?.onDebugImage?(annotated)
                }
            }

            if let reading = self.detectReading(from: results) {
                print("📟 Розпізнано: \(reading.type.rawValue) = \(reading.value)")
                self.onReadingDetected?(reading)
            }
        }

        request.recognitionLanguages = ["en-US"]
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.03 // ігноруємо занадто дрібний текст

        let handler = VNImageRequestHandler(cgImage: processed.cgImage, orientation: .up)
        try? handler.perform([request])
    }

    // MARK: - Малювання рамки

    private func drawBox(for observation: VNRecognizedObjectObservation) {
        guard let overlay = overlayLayer, let view = overlay.superlayer else { return }

        var rect = observation.boundingBox
        rect.origin.y = 1 - rect.origin.y - rect.height

        var converted = VNImageRectForNormalizedRect(rect,
                                                     Int(view.bounds.width),
                                                     Int(view.bounds.height))

        let expand: CGFloat = 10
        converted = converted.insetBy(dx: -expand, dy: -expand)

        let path = UIBezierPath(roundedRect: converted, cornerRadius: 8)
        overlay.path = path.cgPath
        overlay.strokeColor = UIColor.systemGreen.cgColor
        overlay.lineWidth = 2
        overlay.fillColor = UIColor.clear.cgColor
    }

    private func preprocess(pixelBuffer: CVPixelBuffer, region: CGRect) -> (cgImage: CGImage, debug: UIImage)? {
        // Спершу повертаємо картинку так, як її бачить Vision (.right)
        let oriented = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
        let width = Int(oriented.extent.width)
        let height = Int(oriented.extent.height)

        // boundingBox уже у normalized coords (origin bottom-left) після обертання .right,
        // тому додатковий фліп для кропу не потрібен — беремо як є
        let cropRect = VNImageRectForNormalizedRect(region, width, height)

        let cropped = oriented.cropped(to: cropRect)
        let grayscale = cropped.applyingFilter("CIColorControls",
                                               parameters: [
                                                kCIInputSaturationKey: 0,
                                                kCIInputContrastKey: 1.2
                                               ])
        let upscaled = grayscale.applyingFilter("CILanczosScaleTransform",
                                                parameters: [
                                                    kCIInputScaleKey: 2.0,
                                                    kCIInputAspectRatioKey: 1.0
                                                ])

        guard let cg = ciContext.createCGImage(upscaled, from: upscaled.extent) else { return nil }

        let debugImage = UIImage(cgImage: cg)
        DispatchQueue.main.async { [weak self] in
            self?.onDebugImage?(debugImage)
        }

        return (cgImage: cg, debug: debugImage)
    }

    private func pickDigitBiasedStrings(from results: [VNRecognizedTextObservation]) -> [String] {
        // Беремо топ-кандидата кожного рядка, потім застосуємо правила нижче
        return results.compactMap { $0.topCandidates(1).first?.string }
    }

    // Визначення показника з урахуванням позицій (як у рамках)
    private func detectReading(from observations: [VNRecognizedTextObservation]) -> MeterReading? {
        let items: [(rect: CGRect, normalized: String, type: MeterScreenType?)] = observations.compactMap { obs in
            guard let text = obs.topCandidates(1).first?.string else { return nil }
            var rect = obs.boundingBox
            rect.origin.y = 1 - rect.origin.y - rect.height
            let norm = normalize(text)
            return (rect, norm, codeType(for: norm))
        }

        let digitsOnly: (String) -> String = { value in
            value.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")
        }

        let isEightDigits: (String) -> Bool = { value in
            digitsOnly(value).range(of: #"^\d{8}$"#, options: .regularExpression) != nil
        }

        let codeItems = items.compactMap { item -> (rect: CGRect, type: MeterScreenType)? in
            if let t = item.type { return (item.rect, t) }
            return nil
        }
        let digitItems = items.filter { isEightDigits($0.normalized) }

        for code in codeItems {
            for digits in digitItems {
                let isBelow = digits.rect.minY > code.rect.maxY
                let overlapsX = digits.rect.maxX > code.rect.minX && digits.rect.minX < code.rect.maxX
                guard isBelow && overlapsX else { continue }

                let value = digitsOnly(digits.normalized)
                return MeterReading(type: code.type, value: value)
            }
        }

        return nil
    }

    private func annotate(image: UIImage, with observations: [VNRecognizedTextObservation]) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(image.size, false, 0)
        defer { UIGraphicsEndImageContext() }

        image.draw(in: CGRect(origin: .zero, size: image.size))
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.setLineWidth(2)

        // Попередньо готуємо всі прямокутники в пікселях
        let items: [(rect: CGRect, normalized: String, type: MeterScreenType?)] = observations.compactMap { obs in
            guard let text = obs.topCandidates(1).first?.string else { return nil }
            var rect = obs.boundingBox
            rect.origin.y = 1 - rect.origin.y - rect.height
            rect.origin.x *= image.size.width
            rect.origin.y *= image.size.height
            rect.size.width *= image.size.width
            rect.size.height *= image.size.height
            let norm = normalize(text)
            return (rect, norm, codeType(for: norm))
        }

        let isEightDigits: (String) -> Bool = { value in
            let digitsOnly = value.replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: "")
            return digitsOnly.range(of: #"^\d{8}$"#, options: .regularExpression) != nil
        }

        // Малюємо зелені рамки для кодів
        let codeItems = items.compactMap { item -> (rect: CGRect, type: MeterScreenType)? in
            if let t = item.type { return (item.rect, t) }
            return nil
        }
        for code in codeItems {
            ctx?.setStrokeColor(UIColor.systemGreen.cgColor)
            ctx?.stroke(code.rect)
        }

        // Малюємо фіолетові рамки для 8 цифр, що знаходяться нижче коду
        for code in codeItems {
            for candidate in items where isEightDigits(candidate.normalized) {
                // Нижче коду (y зростає вниз) і має горизонтальне перекриття
                let isBelow = candidate.rect.minY > code.rect.maxY
                let overlapsX = candidate.rect.maxX > code.rect.minX && candidate.rect.minX < code.rect.maxX
                guard isBelow && overlapsX else { continue }
                ctx?.setStrokeColor(UIColor.systemPurple.cgColor)
                ctx?.stroke(candidate.rect)
            }
        }

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    private func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "..", with: ".")
    }

    private func codeType(for text: String) -> MeterScreenType? {
        let digitsOnly = text.filter { $0.isNumber }
        guard digitsOnly.count >= 4 else { return nil }

        let code4 = String(digitsOnly.prefix(4))
        let variants = [code4, replaceLeadingSevenWithOne(code4)]

        if variants.contains("1580") { return .total }
        if variants.contains("1581") { return .night }
        if variants.contains("1582") { return .day }
        return nil
    }

    private func replaceLeadingSevenWithOne(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        if text.first == "7" {
            var chars = Array(text)
            chars[0] = "1"
            return String(chars)
        }
        return text
    }
}
