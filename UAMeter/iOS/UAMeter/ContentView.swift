import SwiftUI

struct ContentView: View {
    @State private var readings: [MeterScreenType: String] = [:]
    @State private var torchOn = false

    var allCaptured: Bool {
        MeterScreenType.allCases.filter { $0 != .time }.allSatisfy { readings[$0] != nil }
    }

    var body: some View {
        VStack(spacing: 12) {
            CameraView { reading in
                DispatchQueue.main.async {
                    readings[reading.type] = reading.value
                }
            }
            .frame(height: 400)
            .cornerRadius(16)
            .shadow(radius: 4)

            VStack(alignment: .leading, spacing: 8) {
                meterRow(label: "💰 Сума", type: .total)
                meterRow(label: "🌙 Ніч", type: .night)
                meterRow(label: "☀️ День", type: .day)
                meterRow(label: "📅 Дата", type: .date)
            }
            .padding()

            if allCaptured {
                Button("📋 Copy") {
                    let text = readings
                        .sorted(by: { $0.key.rawValue < $1.key.rawValue })
                        .map { "\($0.key): \($0.value)" }
                        .joined(separator: "\n")
                    UIPasteboard.general.string = text
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    torchOn.toggle()
                    NotificationCenter.default.post(name: .toggleTorch, object: torchOn)
                } label: {
                    Label(torchOn ? "Вимкнути ліхтарик" : "Увімкнути ліхтарик", systemImage: torchOn ? "flashlight.off.fill" : "flashlight.on.fill")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }

    @ViewBuilder
    private func meterRow(label: String, type: MeterScreenType) -> some View {
        HStack {
            Text(label)
            Spacer()
            if let value = readings[type] {
                Text(value).font(.headline)
            } else {
                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
            }
        }
    }
}

extension Notification.Name {
    static let toggleTorch = Notification.Name("toggleTorch")
}
