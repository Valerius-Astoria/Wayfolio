//
//  PlaceDetail.swift
//  Wayfolio
//
//  Created by ZAKA on 11/26/26.
//

import MapKit
import SwiftUI

/// Apple Maps' place card for a point of interest: photos, hours, ratings, and call, website, and directions buttons.
struct PlaceDetail: View {
    let item: MKMapItem

    var body: some View {
        PlaceCard(item: item)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(item.name ?? "Place")
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// Wraps `MKMapItemDetailViewController`, which has no SwiftUI equivalent that can be pushed in a navigation stack.
private struct PlaceCard: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let item: MKMapItem

    func makeUIViewController(context: Context) -> MKMapItemDetailViewController {
        // The app's own map is already behind the sheet, so the card doesn't need one.
        let controller = MKMapItemDetailViewController(mapItem: item, displaysMap: false)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: MKMapItemDetailViewController, context: Context) {
        if controller.mapItem != item {
            controller.mapItem = item
        }
        context.coordinator.dismiss = dismiss
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    final class Coordinator: NSObject, MKMapItemDetailViewControllerDelegate {
        var dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        /// The card's close button pops the page.
        func mapItemDetailViewControllerDidFinish(_ detailViewController: MKMapItemDetailViewController) {
            dismiss()
        }
    }
}
