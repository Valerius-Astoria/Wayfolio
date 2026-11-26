//
//  PlaceSearch.swift
//  Wayfolio
//
//  Created by ZAKA on 11/26/26.
//

import MapKit

/// Searches Apple Maps for places.
enum PlaceSearch {
    /// Finds places that match `query`, limited to `categories` if any are given.
    ///
    /// A blank query with categories lists the places of those categories in `region`.
    /// - Returns: The places found, or an empty array if there's nothing to search for or the search fails.
    static func search(query: String,
                       categories: Set<MKPointOfInterestCategory> = [],
                       region: MKCoordinateRegion?) async -> [MKMapItem] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filter = categories.isEmpty ? nil : MKPointOfInterestFilter(including: Array(categories))

        let search: MKLocalSearch
        if query.isEmpty {
            guard let filter, let region else { return [] }
            let request = MKLocalPointsOfInterestRequest(coordinateRegion: region)
            request.pointOfInterestFilter = filter
            search = MKLocalSearch(request: request)
        } else {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.pointOfInterestFilter = filter
            if let region {
                request.region = region
            }
            search = MKLocalSearch(request: request)
        }
        return (try? await search.start().mapItems) ?? []
    }
}

extension MKCoordinateRegion {
    /// The smallest region that fits `coordinates` with some padding, or `nil` if there are none.
    ///
    /// - Parameter minimumSpan: The smallest span in degrees, so a single point isn't zoomed in all the way.
    init?(fitting coordinates: [CLLocationCoordinate2D], minimumSpan: CLLocationDegrees = 0.01) {
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        guard let minLatitude = latitudes.min(), let maxLatitude = latitudes.max(),
              let minLongitude = longitudes.min(), let maxLongitude = longitudes.max() else { return nil }

        self.init(center: CLLocationCoordinate2D(latitude: (minLatitude + maxLatitude) / 2,
                                                 longitude: (minLongitude + maxLongitude) / 2),
                  span: MKCoordinateSpan(latitudeDelta: max((maxLatitude - minLatitude) * 1.5, minimumSpan),
                                         longitudeDelta: max((maxLongitude - minLongitude) * 1.5, minimumSpan)))
    }
}

nonisolated extension MKPolyline {
    /// The polyline's points as coordinates.
    var coordinates: [CLLocationCoordinate2D] {
        var coordinates = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coordinates, range: NSRange(location: 0, length: pointCount))
        return coordinates
    }
}
