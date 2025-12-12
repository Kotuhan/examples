import CreateML
import Foundation

let trainURL = URL(fileURLWithPath: "DigitsDataset/train")
let valURL   = URL(fileURLWithPath: "DigitsDataset/validation")

print("📦 Loading training data...")
let trainingData = try MLDataTable(contentsOf: trainURL)
let validationData = try MLDataTable(contentsOf: valURL)

print("🚀 Training model...")
let model = try MLTextRecognizer(
    trainingData: trainingData,
    validationData: validationData,
    augmentationOptions: [.blur, .noise, .rotate]
)

let outputURL = URL(fileURLWithPath: "DigitsReader.mlmodel")
try model.write(to: outputURL)

print("✅ Model saved to \(outputURL.path)")
