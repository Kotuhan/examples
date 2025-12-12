import UIKit
import AVFoundation

final class PreviewView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let overlayLayer = CAShapeLayer()
    private let debugImageView = UIImageView()

    private var onValueDetected: ((MeterReading) -> Void)?
    private var mlScreenDetector: MeterScreenDetector?

    func setValueHandler(_ handler: @escaping (MeterReading) -> Void) {
        self.onValueDetected = handler
    }

    func emitValue(_ reading: MeterReading) {
        onValueDetected?(reading)
    }

    func setup(session: AVCaptureSession) {
        // 🎥 Створюємо preview layer
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        self.layer.addSublayer(layer)
        previewLayer = layer

        // 🎨 Створюємо overlay для рамки
        overlayLayer.strokeColor = UIColor.systemYellow.cgColor
        overlayLayer.lineWidth = 2
        overlayLayer.fillColor = UIColor.clear.cgColor
        overlayLayer.lineDashPattern = [6, 4]
        overlayLayer.zPosition = 10
        layer.addSublayer(overlayLayer)

        // Debug preview for ROI
        debugImageView.contentMode = .scaleAspectFit
        debugImageView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        debugImageView.layer.borderColor = UIColor.systemYellow.cgColor
        debugImageView.layer.borderWidth = 1
        debugImageView.layer.cornerRadius = 8
        debugImageView.layer.masksToBounds = true
        addSubview(debugImageView)
        bringSubviewToFront(debugImageView)

        // 🤖 Ініціалізуємо ML детектор
        mlScreenDetector = MeterScreenDetector(overlayLayer: overlayLayer)
        mlScreenDetector?.onReadingDetected = { [weak self] reading in
            self?.emitValue(reading)
        }
        mlScreenDetector?.onDebugImage = { [weak self] image in
            self?.showDebugImage(image)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
        debugImageView.frame = CGRect(x: 12, y: 12, width: 200, height: 120)
    }

    private func showDebugImage(_ image: UIImage) {
        debugImageView.image = image
    }
}

extension PreviewView: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        mlScreenDetector?.detect(in: pixelBuffer)
    }
}
