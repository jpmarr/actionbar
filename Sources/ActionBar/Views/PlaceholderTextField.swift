import SwiftUI

struct PlaceholderTextField: View {
    @Binding var text: String
    @State private var suggestions: [Placeholder] = []
    @State private var showSuggestions = false
    @State private var selectedIndex: Int = -1
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Default value", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    updateSuggestions(for: newValue)
                    selectedIndex = -1
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            if !isFocused { showSuggestions = false }
                        }
                    }
                }
                .onKeyPress(.upArrow) {
                    guard showSuggestions, !suggestions.isEmpty else { return .ignored }
                    selectedIndex = selectedIndex <= 0 ? suggestions.count - 1 : selectedIndex - 1
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    guard showSuggestions, !suggestions.isEmpty else { return .ignored }
                    selectedIndex = selectedIndex >= suggestions.count - 1 ? 0 : selectedIndex + 1
                    return .handled
                }
                .onKeyPress(.return) {
                    if showSuggestions, selectedIndex >= 0, selectedIndex < suggestions.count {
                        applySuggestion(suggestions[selectedIndex])
                        return .handled
                    } else if showSuggestions, suggestions.count == 1 {
                        applySuggestion(suggestions[0])
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.tab) {
                    if showSuggestions, selectedIndex >= 0, selectedIndex < suggestions.count {
                        applySuggestion(suggestions[selectedIndex])
                        return .handled
                    } else if showSuggestions, suggestions.count == 1 {
                        applySuggestion(suggestions[0])
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.escape) {
                    if showSuggestions {
                        showSuggestions = false
                        selectedIndex = -1
                        return .handled
                    }
                    return .ignored
                }

            if showSuggestions && !suggestions.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, placeholder in
                                let isSelected = index == selectedIndex
                                Button {
                                    applySuggestion(placeholder)
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("${\(placeholder.name)}")
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundStyle(isSelected ? .white : .primary)
                                        Spacer()
                                        Text(placeholder.description)
                                            .font(.subheadline)
                                            .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                                            .lineLimit(1)
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(isSelected ? Color.accentColor : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                                .id(index)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(maxHeight: 100)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.separator, lineWidth: 1)
                    )
                    .padding(.top, 2)
                    .onChange(of: selectedIndex) { _, newIndex in
                        if newIndex >= 0 {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private func applySuggestion(_ placeholder: Placeholder) {
        // Find the unclosed ${ and replace from there
        if let dollarRange = findUnclosedPlaceholder(in: text) {
            text = String(text[text.startIndex..<dollarRange.lowerBound]) + "${\(placeholder.name)}" + String(text[dollarRange.upperBound...])
        } else {
            // No unclosed placeholder — just append
            text += "${\(placeholder.name)}"
        }
        showSuggestions = false
        selectedIndex = -1
    }

    private func updateSuggestions(for value: String) {
        guard let range = findUnclosedPlaceholder(in: value) else {
            suggestions = []
            showSuggestions = false
            return
        }

        let prefix = String(value[range]).dropFirst(2) // drop "${"
        suggestions = PlaceholderResolver.completions(for: String(prefix))
        showSuggestions = !suggestions.isEmpty
    }

    /// Finds the range of an unclosed `${...` at the end of the string (no closing `}`).
    private func findUnclosedPlaceholder(in value: String) -> Range<String.Index>? {
        guard let dollarIndex = value.lastIndex(of: "$") else { return nil }
        let afterDollar = value.index(after: dollarIndex)
        guard afterDollar < value.endIndex, value[afterDollar] == "{" else { return nil }

        let rest = value[value.index(after: afterDollar)...]
        // If there's a closing brace, this placeholder is already complete
        if rest.contains("}") { return nil }

        return dollarIndex..<value.endIndex
    }
}
