import Foundation

/// The local Chinese edition has separate data and never changes the upstream app.
public enum ChineseEdition {
    public static let bundleIdentifier = "ai.xiaolai.checkmate.zh-Hans"
    public static var enabled: Bool {
        Bundle.main.bundleIdentifier == bundleIdentifier ||
        ProcessInfo.processInfo.environment["CHECKMATE_LANGUAGE"] == "zh-Hans"
    }
    public static var language: String { enabled ? "zh-Hans" : "en" }
}

/// Translation happens at presentation boundaries, not in IDs, rules or protocols.
public enum ChineseText {
    private static let catalog: [String: String] = {
        guard let data = try? Data(contentsOf: NativeResources.url("localization-zh-Hans.json")),
              let values = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return values
    }()
    private struct Template {
        let regex: NSRegularExpression
        let translation: String
    }
    private static let templates: [Template] = catalog.keys.filter { $0.contains("{0}") }.sorted { $0.count > $1.count }.compactMap { key in
        var pattern = NSRegularExpression.escapedPattern(for: key)
        for index in 0..<10 {
            pattern = pattern.replacingOccurrences(of: NSRegularExpression.escapedPattern(for: "{\(index)}"), with: "(.+?)")
        }
        guard let regex = try? NSRegularExpression(pattern: "^" + pattern + "$") else { return nil }
        return Template(regex: regex, translation: catalog[key]!)
    }
    public static func text(_ value: String) -> String {
        ChineseEdition.enabled ? translate(value) : value
    }
    public static func translate(_ value: String) -> String {
        if let translated = catalog[value] { return translated }
        // Core explanations join independently authored sentences. Localize each
        // sentence while preserving chess notation, user names and imported text.
        let sentences = value.components(separatedBy: ". ")
        if sentences.count > 1 && sentences.count <= 20 {
            let rendered = sentences.enumerated().map { index, part in
                translate(part + (index < sentences.count - 1 ? "." : ""))
            }.joined(separator: " ")
            if rendered != value { return rendered }
        }
        for template in templates {
            guard let match = template.regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) else { continue }
            var result = template.translation
            for index in 1..<match.numberOfRanges {
                guard let range = Range(match.range(at: index), in: value) else { continue }
                let part = String(value[range])
                result = result.replacingOccurrences(of: "{\(index - 1)}", with: catalog[part] ?? part)
            }
            return result
        }
        return value
    }
}
