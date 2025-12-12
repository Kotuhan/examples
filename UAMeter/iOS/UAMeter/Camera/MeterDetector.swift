import Foundation
import Vision

enum MeterScreenType: String, CaseIterable {
    case total = "Загальна сума"
    case night = "Нічний показник"
    case day   = "Денний показник"
    case date  = "Дата"
    case time  = "Час"
}

struct MeterReading {
    let type: MeterScreenType
    let value: String
}

final class MeterDetector {

    func detect(from lines: [String]) -> MeterReading? {
        // 0️⃣ нормалізація
        let normalized = lines.map {
            $0.lowercased()
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ".", with: "")
        }

        guard let gamaIndex = normalized.firstIndex(where: { $0.contains("gama100") }) else {
            return nil
        }

        // 1️⃣ перевіряємо по черзі
        if let total = detectEnergy(type: .total, code: "1580", in: normalized, gamaIndex: gamaIndex) { return total }
        if let night = detectEnergy(type: .night, code: "1581", in: normalized, gamaIndex: gamaIndex) { return night }
        if let day   = detectEnergy(type: .day,   code: "1582", in: normalized, gamaIndex: gamaIndex) { return day }
        if let date  = detectDate(in: normalized) { return date }
        if let time  = detectTime(in: normalized) { return time }

        return nil
    }

    // MARK: - Енергетичні екрани
    private func detectEnergy(type: MeterScreenType, code: String, in lines: [String], gamaIndex: Int) -> MeterReading? {
        // знайдемо всі ключові позиції
        guard let codeIndex = lines[(gamaIndex + 1)...].firstIndex(where: { $0.contains(code) }) else { return nil }
        guard let kwhIndex = lines[(codeIndex + 1)...].firstIndex(where: { $0.contains("kwh") }) else { return nil }

        // шукаємо 8 цифр після kWh
        let pattern = #"(?<!\d)\d{8}(?:\.\d)?(?!\d)"#
        guard let valueIndex = lines[(kwhIndex + 1)...].firstIndex(where: { matchRegex(pattern, in: $0) != nil }),
              let match = matchRegex(pattern, in: lines[valueIndex]) else {
            return nil
        }

        // шукаємо 2000 imp нижче
        guard let impIndex = lines[(valueIndex + 1)...].firstIndex(where: { $0.contains("2000imp") }) else { return nil }

        // ✅ перевірка порядку — усе між GAMA і 2000 imp
        if gamaIndex < codeIndex, codeIndex < kwhIndex, kwhIndex < valueIndex, valueIndex < impIndex {
            return MeterReading(type: type, value: normalizeEnergyValue(match))
        } else {
            return nil
        }
    }

    // MARK: - Дата
    private func detectDate(in lines: [String]) -> MeterReading? {
        guard lines.contains(where: { $0.contains("092") }) else { return nil }
        let pattern = #"\b\d{1,2}[-/]\d{1,2}[-/]\d{2,4}\b"#
        if let match = findMatch(pattern, in: lines) {
            return MeterReading(type: .date, value: match)
        }
        return nil
    }

    // MARK: - Час
    private func detectTime(in lines: [String]) -> MeterReading? {
        guard lines.contains(where: { $0.contains("091") }) else { return nil }
        let pattern = #"\b\d{1,2}[:.]\d{2}\b"#
        if let match = findMatch(pattern, in: lines) {
            return MeterReading(type: .time, value: match)
        }
        return nil
    }

    // MARK: - Helpers
    private func matchRegex(_ pattern: String, in text: String) -> String? {
        if let range = text.range(of: pattern, options: .regularExpression) {
            return String(text[range])
        }
        return nil
    }

    private func findMatch(_ pattern: String, in lines: [String]) -> String? {
        for text in lines {
            if let range = text.range(of: pattern, options: .regularExpression) {
                return String(text[range])
            }
        }
        return nil
    }

    private func normalizeEnergyValue(_ raw: String) -> String {
        var cleaned = raw.replacingOccurrences(of: " ", with: "")
        if !cleaned.contains(".") && cleaned.count == 8 {
            cleaned.insert(".", at: cleaned.index(before: cleaned.endIndex))
        }
        return cleaned
    }
}
