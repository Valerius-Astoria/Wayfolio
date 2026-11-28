//
//  Binding+OrEmpty.swift
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
