//
//  BindingExtensions.swift
//  Wayfolio
//
//  Created by ZAKA on 11/25/26.
//

import SwiftUI

extension Binding where Value == String? {
    /// Reads `nil` as an empty string and writes an empty string back as `nil`.
    var orEmpty: Binding<String> {
        Binding<String>(
            get: { wrappedValue ?? "" },
            set: { wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}

extension Binding {
    /// Reads the wrapped optional, falling back to `fallback` once it becomes `nil`, and writes values through.
    ///
    /// Safer than `Binding(_:)` for editors of an optional that can be removed while they're on screen.
    func unwrapped<Wrapped>(or fallback: Wrapped) -> Binding<Wrapped> where Value == Wrapped? {
        Binding<Wrapped>(
            get: { wrappedValue ?? fallback },
            set: { wrappedValue = $0 }
        )
    }
}
