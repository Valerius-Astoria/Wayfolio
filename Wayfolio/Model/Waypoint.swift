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
    var condition: Condition = Condition.noCondition
    
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
    
    /// Whether the place is open right now.
    ///
    /// - Returns: `nil` if the opening hours are unknown. See `Hours.isOpen(at:)`.
    var isOpening: Bool? { hours?.isOpen() }

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
    
    /// Requires the user to be within `radius` meters of the given coordinate to check this waypoint.
    func addCoordinateCondition(latitude: Double, longitude: Double, radius: Double) {
        self.condition = .coordinate(latitude: latitude, longitude: longitude, radius: radius)
    }

    /// Checks `condition` and marks the waypoint as checked if it's met.
    ///
    /// - Returns: `nil` if the condition is met, otherwise a message explaining why it isn't.
    func check() async -> String? {
        if let errorMessage = await condition.check() {
            return errorMessage
        } else {
            isChecked = true
            return nil
        }
    }
}



