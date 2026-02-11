import SwiftUI

struct PathTextField: View {
    @Binding var path: String
    @State private var suggestions: [String] = []
    @State private var showSuggestions = false
    @State private var selectedIndex: Int = -1
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("/path/to/repo", text: $path)
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .focused($isFocused)
                .onChange(of: path) { _, newValue in
                    guard isFocused else { return }
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
                            ForEach(Array(suggestions.enumerated()), id: \.element) { index, suggestion in
                                let name = (suggestion as NSString).lastPathComponent
                                let isSelected = index == selectedIndex
                                Button {
                                    applySuggestion(suggestion)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "folder")
                                            .font(.subheadline)
                                            .foregroundStyle(isSelected ? .white : .secondary)
                                        Text(name)
                                            .font(.body)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                            .foregroundStyle(isSelected ? .white : .primary)
                                        Spacer()
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
                    .frame(maxHeight: 120)
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

    private func applySuggestion(_ suggestion: String) {
        path = suggestion
        updateSuggestions(for: suggestion)
        selectedIndex = -1
    }

    private func updateSuggestions(for text: String) {
        guard !text.isEmpty else {
            suggestions = []
            showSuggestions = false
            return
        }

        let expanded = (text as NSString).expandingTildeInPath
        let fm = FileManager.default
        var isDir: ObjCBool = false

        if text.hasSuffix("/") && fm.fileExists(atPath: expanded, isDirectory: &isDir) && isDir.boolValue {
            suggestions = listDirectories(in: expanded)
            showSuggestions = !suggestions.isEmpty
            return
        }

        let parent = (expanded as NSString).deletingLastPathComponent
        let partial = (expanded as NSString).lastPathComponent.lowercased()

        guard fm.fileExists(atPath: parent, isDirectory: &isDir), isDir.boolValue else {
            suggestions = []
            showSuggestions = false
            return
        }

        let matches = listDirectories(in: parent).filter {
            ($0 as NSString).lastPathComponent.lowercased().hasPrefix(partial)
        }

        suggestions = matches
        showSuggestions = !matches.isEmpty
    }

    private func listDirectories(in directory: String) -> [String] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: directory) else { return [] }

        return contents
            .filter { !$0.hasPrefix(".") }
            .compactMap { name -> String? in
                let full = (directory as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue else {
                    return nil
                }
                return full
            }
            .sorted()
    }
}
