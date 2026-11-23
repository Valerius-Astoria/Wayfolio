//
//  ExpandableText.swift
//  Wayfolio
//
//  Created by ZAKA on 11/23/26.
//

import SwiftUI

/// Text that's shortened to `wordLimit` words, with a tappable "More" or "Less" link
/// at the end to expand or collapse it.
///
/// The link only appears when the text is long enough to truncate.
struct ExpandableText: View {
    let text: String
    let wordLimit: Int

    @State private var isExpanded = false

    init(_ text: String, wordLimit: Int = 50) {
        self.text = text
        self.wordLimit = wordLimit
    }

    /// The shortened or full text, followed by the "More" or "Less" link when needed.
    private var displayText: AttributedString {
        let result = text.truncated(toWords: wordLimit)
        var display = AttributedString(isExpanded ? text : result.text)
        guard result.isTruncated else { return display }

        var toggle = AttributedString(isExpanded ? " Less" : " More")
        toggle.link = URL(string: "wayfolio://toggle-expandable-text") // Never opened; intercepted by `openURL` below.
        toggle.font = .subheadline.bold()
        display += toggle
        return display
    }

    var body: some View {
        Text(displayText)
            .environment(\.openURL, OpenURLAction { _ in
                withAnimation { isExpanded.toggle() }
                return .handled
            })
    }
}

extension String {
    /// Shortens the string to its first `limit` words, adding "..." if anything was cut.
    ///
    /// Words are separated by whitespace and newlines, and the shortened text is rejoined with single spaces.
    /// - Returns: The shortened text, and whether anything was cut.
    func truncated(toWords limit: Int) -> (text: String, isTruncated: Bool) {
        let words = self.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        guard words.count > limit else {
            return (self, false)
        }

        let truncatedText = words.prefix(limit).joined(separator: " ") + "..."
        return (truncatedText, true)
    }
}

#Preview {
    List {
        ExpandableText(Adventure.createSampleAdventure().intro, wordLimit: 10)
    }
}
