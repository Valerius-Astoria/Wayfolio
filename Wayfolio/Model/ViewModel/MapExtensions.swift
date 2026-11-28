//
//  MapExtensions.swift
//  Wayfolio
//
//  Created by ZAKA on 11/27/26.
//

import MapKit

extension MKCoordinateRegion {
    static let beijing = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
}
