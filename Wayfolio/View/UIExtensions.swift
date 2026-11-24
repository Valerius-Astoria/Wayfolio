//
//  UIExtensions.swift
//  Wayfolio
//
//  Created by ZAKA on 11/24/26.
//

import SwiftUI

extension Image {
    func thumbnailStyle(width: CGFloat = 54, height: CGFloat = 72, cornerRadius: CGFloat = 8) -> some View {
        self
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipShape(.rect(cornerRadius: cornerRadius))
            .accessibilityHidden(true)
    }
}
