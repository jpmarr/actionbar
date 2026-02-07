import Foundation

enum WorkflowInputParser {
    static func parseInputs(from yamlContent: String) -> [WorkflowDispatchInput] {
        let lines = yamlContent.components(separatedBy: "\n")

        // Find the workflow_dispatch trigger section
        guard let dispatchRange = findWorkflowDispatchSection(in: lines) else {
            return []
        }

        // Find the inputs section within workflow_dispatch
        guard let inputsRange = findInputsSection(in: lines, within: dispatchRange) else {
            return []
        }

        return parseInputEntries(from: lines, in: inputsRange)
    }

    // MARK: - Private

    private static func findWorkflowDispatchSection(in lines: [String]) -> Range<Int>? {
        // Look for `on:` block first (handles both `on:` and `"on":`)
        var onLineIndex: Int?
        var onIndent: Int?

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            // Match `on:` as a top-level key (indent 0 typically)
            if trimmed == "on:" || trimmed == "\"on\":" || trimmed.hasPrefix("on: ") || trimmed.hasPrefix("\"on\": ") {
                onLineIndex = i
                onIndent = indentLevel(of: line)
                break
            }
        }

        guard let onIdx = onLineIndex, let baseIndent = onIndent else {
            return nil
        }

        // Check inline form: `on: workflow_dispatch` or `on: [workflow_dispatch, ...]`
        let onTrimmed = lines[onIdx].trimmingCharacters(in: .whitespaces)
        if onTrimmed.contains("workflow_dispatch") && !onTrimmed.hasSuffix(":") {
            // Inline trigger with no inputs block possible — check if there's a workflow_dispatch: section below
        }

        // Look for workflow_dispatch within on: block
        let blockEnd = findBlockEnd(in: lines, startingAfter: onIdx, baseIndent: baseIndent)

        for i in (onIdx + 1)..<blockEnd {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            if trimmed == "workflow_dispatch:" || trimmed.hasPrefix("workflow_dispatch:") {
                let dispatchIndent = indentLevel(of: lines[i])
                let dispatchEnd = findBlockEnd(in: lines, startingAfter: i, baseIndent: dispatchIndent)
                return (i + 1)..<dispatchEnd
            }
        }

        return nil
    }

    private static func findInputsSection(in lines: [String], within range: Range<Int>) -> Range<Int>? {
        for i in range {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            if trimmed == "inputs:" || trimmed.hasPrefix("inputs:") {
                let inputsIndent = indentLevel(of: lines[i])
                let inputsEnd = findBlockEnd(in: lines, startingAfter: i, baseIndent: inputsIndent)
                return (i + 1)..<inputsEnd
            }
        }
        return nil
    }

    private static func parseInputEntries(from lines: [String], in range: Range<Int>) -> [WorkflowDispatchInput] {
        var inputs: [WorkflowDispatchInput] = []
        guard range.lowerBound < lines.count else { return inputs }

        // Find the indent level of input names
        var inputNameIndent: Int?
        for i in range {
            guard i < lines.count else { break }
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            inputNameIndent = indentLevel(of: lines[i])
            break
        }

        guard let nameIndent = inputNameIndent else { return inputs }

        // Collect input names and their sub-blocks
        var currentName: String?
        var currentBlockStart: Int?

        for i in range {
            guard i < lines.count else { break }
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            let indent = indentLevel(of: lines[i])

            if indent == nameIndent && trimmed.hasSuffix(":") {
                // Finish previous input
                if let name = currentName, let start = currentBlockStart {
                    let input = parseOneInput(name: name, from: lines, start: start, end: i)
                    inputs.append(input)
                }
                currentName = String(trimmed.dropLast()) // remove ":"
                currentBlockStart = i + 1
            }
        }

        // Finish last input
        if let name = currentName, let start = currentBlockStart {
            let input = parseOneInput(name: name, from: lines, start: start, end: range.upperBound)
            inputs.append(input)
        }

        return inputs
    }

    private static func parseOneInput(name: String, from lines: [String], start: Int, end: Int) -> WorkflowDispatchInput {
        var description = ""
        var required = false
        var type = WorkflowDispatchInput.InputType.string
        var defaultValue = ""
        var options: [String] = []

        for i in start..<min(end, lines.count) {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            if let value = extractValue(from: trimmed, key: "description") {
                description = unquote(value)
            } else if let value = extractValue(from: trimmed, key: "required") {
                required = value.lowercased() == "true"
            } else if let value = extractValue(from: trimmed, key: "type") {
                type = parseInputType(value)
            } else if let value = extractValue(from: trimmed, key: "default") {
                defaultValue = unquote(value)
            } else if trimmed == "options:" {
                // Parse options list
                for j in (i + 1)..<min(end, lines.count) {
                    let optTrimmed = lines[j].trimmingCharacters(in: .whitespaces)
                    if optTrimmed.hasPrefix("- ") {
                        let optValue = String(optTrimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                        options.append(unquote(optValue))
                    } else if !optTrimmed.isEmpty && !optTrimmed.hasPrefix("#") {
                        break
                    }
                }
            }
        }

        return WorkflowDispatchInput(
            name: name,
            description: description,
            required: required,
            type: type,
            defaultValue: defaultValue,
            options: options
        )
    }

    private static func extractValue(from line: String, key: String) -> String? {
        let prefix = "\(key):"
        guard line.hasPrefix(prefix) else { return nil }
        let value = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    private static func parseInputType(_ value: String) -> WorkflowDispatchInput.InputType {
        switch unquote(value).lowercased() {
        case "boolean": return .boolean
        case "choice": return .choice
        case "number": return .number
        case "environment": return .environment
        default: return .string
        }
    }

    private static func unquote(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) ||
           (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }

    private static func indentLevel(of line: String) -> Int {
        line.prefix(while: { $0 == " " }).count
    }

    private static func findBlockEnd(in lines: [String], startingAfter index: Int, baseIndent: Int) -> Int {
        for i in (index + 1)..<lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            if indentLevel(of: line) <= baseIndent {
                return i
            }
        }
        return lines.count
    }
}
