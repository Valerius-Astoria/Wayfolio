//
//  Waypoint.swift
//  Wayfolio
//
//  Created by ZAKA on 11/19/26.
//

import MapKit
import SwiftData

/// A place to visit during an adventure.
///
/// A waypoint is either a point of interest from Apple Maps (`isPOI`) or a custom place
/// created from raw coordinates.
@Model class Waypoint {
    var name: String
    var icon: String
    var intro: String?
    var schedule: Schedule
    var isChecked: Bool
    /// Must be met to check the waypoint. `nil` means the user can check it at any time.
    var location: LocationCondition?
    
    var latitude: Double
    var longitude: Double
    var poiIdentifier: String?
    var phoneNumber: String?
    var fullAddress: String?
    var shortAddress: String?
    var url: URL?
    var hours: Hours?
    var order: Int

    @Relationship(deleteRule: .cascade, inverse: \Clue.waypoint)
    var clues: [Clue] = []
    var route: Route

    /// Initializer for a POI Item.
    ///
    /// Display the custom name and icon it they are set by the user.
    init(item: MKMapItem,
         name: String?,
         icon: String = "mappin",
         intro: String?,
         schedule: Schedule,
         isChecked: Bool = false,
         order: Int,
         route: Route) {
        self.name = name ?? item.name ?? "Unnamed"
        self.icon = icon
        self.intro = intro
        self.schedule = schedule
        self.isChecked = isChecked
        self.latitude = item.location.coordinate.latitude
        self.longitude = item.location.coordinate.longitude
        self.poiIdentifier = item.identifier?.rawValue
        self.phoneNumber = item.phoneNumber
        self.fullAddress = item.address?.fullAddress
        self.shortAddress = item.address?.shortAddress
        self.url = item.url
        self.order = order
        self.route = route
    }

    /// Initializer for a custom waypoint.
    init(name: String,
         icon: String = "mappin",
         intro: String = "",
         schedule: Schedule,
         isChecked: Bool = false,
         latitude: Double,
         longitude: Double,
         phoneNumber: String? = nil,
         fullAddress: String? = nil,
         shortAddress: String? = nil,
         url: URL? = nil,
         order: Int,
         route: Route) {
        self.name = name
        self.icon = icon
        self.intro = intro
        self.schedule = schedule
        self.isChecked = isChecked
        self.latitude = latitude
        self.longitude = longitude
        self.phoneNumber = phoneNumber
        self.fullAddress = fullAddress
        self.shortAddress = shortAddress
        self.url = url
        self.order = order
        self.route = route
    }

    var isPOI: Bool { return poiIdentifier != nil }

    /// The stored latitude and longitude as a map coordinate.
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// Whether the place is open right now.
    ///
    /// - Returns: `nil` if the opening hours are unknown. See `Hours.isOpen(at:)`.
    var isOpening: Bool? { hours?.isOpen() }
    
    /// The clues, sorted by `order`.
    var orderedClues: [Clue] {
        clues.sorted { $0.order < $1.order }
    }

    /// Adds an empty clue at the end of the list.
    func addClue() {
        let clue = Clue(
            clueName: "New Clue",
            detail: "",
            waypoint: self,
            order: (clues.map(\.order).max() ?? -1) + 1
        )
        if clues.contains(where: { $0 === clue }) {
            clues = Array(clues)
        } else {
            clues.append(clue)
        }
    }

    func deleteClues(at offsets: IndexSet) {
        let doomed = offsets.map { orderedClues[$0] }
        clues.removeAll { doomed.contains($0) }
        for clue in doomed {
            modelContext?.delete(clue)
        }
    }

    // MARK: - GET MKMapItem
    
    /// The MKMapItem corresponds to the current waypoint.
    ///
    /// - Returns: A map item for the place, used for directions. `nil` if a POI can't be fetched.
    func getMKMapItem() async -> MKMapItem? { await self.isPOI ? getPOIMKMapItem() : getCustomMKMapItem() }

    /// Fetches the up-to-date map item from Apple Maps using `poiIdentifier`.
    ///
    /// - Returns: The map item, or `nil` if the identifier is missing or the request fails.
    private func getPOIMKMapItem() async -> MKMapItem? {
        guard let raw = poiIdentifier, let identifier = MKMapItem.Identifier(rawValue: raw) else { return nil }
        let request = MKMapItemRequest(mapItemIdentifier: identifier)
        return try? await request.mapItem
    }

    /// - Returns: A map item built from the stored coordinates and details.
    private func getCustomMKMapItem() -> MKMapItem {
        let location = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let address = self.fullAddress.flatMap { full in
            MKAddress(fullAddress: full, shortAddress: self.shortAddress)
        }

        let item = MKMapItem(location: location, address: address)
        item.phoneNumber = self.phoneNumber
        item.url = self.url

        return item
    }

    // MARK: - Check the Waypoint
    
    /// Requires the user to be within `radius` meters of the waypoint to check it.
    func requireArrival(within radius: Double = 50) {
        location = LocationCondition(latitude: latitude, longitude: longitude, radius: radius)
    }

    /// Checks `location` and marks the waypoint as checked if it's met.
    ///
    /// - Throws: `ConditionFailure` or `LocationError` if the user isn't at the waypoint.
    func check() async throws {
        try await location?.check()
        isChecked = true
    }
}



