import Foundation
import CreateML

let trainURL = URL(fileURLWithPath: "/Users/user/dev/UAMeter/dataset/DigitsDataset/train")
let valURL   = URL(fileURLWithPath: "/Users/user/dev/UAMeter/dataset/DigitsDataset/validation")

let trainingData = try MLDataTable(contentsOf: trainURL)
let validationData = try MLDataTable(contentsOf: valURL)

let model = try MLTextRecognizer(trainingData: trainingData,
                                 validationData: validationData,
                                 augmentationOptions: [.blur, .noise, .rotate])

try model.write(to: URL(fileURLWithPath: "/Users/user/dev/UAMeter/DigitsReader.mlmodel"))
print("✅ Model saved to ~/dev/UAMeter/DigitsReader.mlmodel")
