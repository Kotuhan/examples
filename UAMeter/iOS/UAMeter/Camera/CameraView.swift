import SwiftUI
import AVFoundation

struct CameraView: UIViewRepresentable {
    var onValueDetected: (MeterReading) -> Void
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "ua.meter.camera.session")

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.setup(session: session)
        setupVideoOutput(for: view) // ✅ додаємо відео-аутпут ТУТ
        view.setValueHandler(onValueDetected)

        DispatchQueue.global(qos: .userInitiated).async {
            configureSession() // ⚙️ тільки інпут + старт
            session.startRunning()
        }

        // 🔦 Torch listener
        NotificationCenter.default.addObserver(
            forName: .toggleTorch,
            object: nil,
            queue: .main
        ) { notification in
            if let state = notification.object as? Bool {
                toggleTorch(state)
            }
        }

        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    // ⚙️ Тільки вхідна камера
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }

        session.addInput(input)
        session.commitConfiguration()
    }

    // ✅ Додаємо відео-аутпут, бо тут ми бачимо view
    private func setupVideoOutput(for view: PreviewView) {
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(view, queue: DispatchQueue(label: "videoQueue"))
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
    }

    // MARK: - Torch Control
    private func toggleTorch(_ isOn: Bool) {
        sessionQueue.async {
            guard let currentInput = session.inputs.first as? AVCaptureDeviceInput else { return }

            let newDevice: AVCaptureDevice? = {
                if isOn {
                    return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                } else {
                    return AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
                        ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                }
            }()

            guard let selectedDevice = newDevice else { return }

            if selectedDevice.uniqueID != currentInput.device.uniqueID {
                do {
                    session.beginConfiguration()
                    session.removeInput(currentInput)
                    let newInput = try AVCaptureDeviceInput(device: selectedDevice)
                    if session.canAddInput(newInput) {
                        session.addInput(newInput)
                    }
                    session.commitConfiguration()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        setTorchForDevice(selectedDevice, isOn: isOn)
                    }
                } catch {
                    print("⚠️ Camera switch error: \(error)")
                }
            } else {
                setTorchForDevice(selectedDevice, isOn: isOn)
            }
        }
    }

    private func setTorchForDevice(_ device: AVCaptureDevice, isOn: Bool) {
        guard device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if isOn {
                try device.setTorchModeOn(level: 0.9)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            print("⚠️ Torch config error: \(error)")
        }
    }
}
