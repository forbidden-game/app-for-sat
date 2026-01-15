import Foundation

enum SwiftMathLatexValidator {
    private static let allowedCommands: Set<String> = [
        "frac", "sqrt", "pi", "alpha", "beta", "gamma", "theta",
        "sin", "cos", "tan", "log", "ln", "cdot", "times",
        "leq", "geq", "neq", "pm"
    ]

    static func isSafe(_ latex: String) -> Bool {
        let trimmed = latex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed.contains("\\\\") { return false }
        if trimmed.contains("\\begin") || trimmed.contains("\\end") { return false }
        if trimmed.contains("\\left") || trimmed.contains("\\right") { return false }
        if !balancedBraces(in: trimmed) { return false }
        return commandsAreAllowed(in: trimmed)
    }

    private static func commandsAreAllowed(in latex: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: #"\\([A-Za-z]+)"#, options: []) else {
            return false
        }
        let range = NSRange(latex.startIndex..<latex.endIndex, in: latex)
        for match in regex.matches(in: latex, options: [], range: range) {
            guard match.numberOfRanges > 1,
                  let commandRange = Range(match.range(at: 1), in: latex) else { continue }
            let command = String(latex[commandRange])
            if !allowedCommands.contains(command) {
                return false
            }
        }
        return true
    }

    private static func balancedBraces(in latex: String) -> Bool {
        var depth = 0
        for ch in latex {
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth < 0 { return false }
            }
        }
        return depth == 0
    }
}
