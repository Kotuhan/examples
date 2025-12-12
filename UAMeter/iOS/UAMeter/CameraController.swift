import Foundation
import Combine

final class CameraController: ObservableObject {
    /// Це замикання встановлює сам `CameraView`
    var triggerCapture: (() -> Void)?
    var toggleTorch: ((_ isOn: Bool) -> Void)?


    /// Викликається з SwiftUI (наприклад, по натисканню кнопки)
    func capturePhoto() {
        triggerCapture?()
    }
    
    func setTorch(on: Bool) {
        toggleTorch?(on)
    }
}