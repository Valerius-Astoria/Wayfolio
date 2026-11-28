# Wayfolio

An adventure planning and journaling app built with SwiftUI, MapKit, and SwiftData.

Users search Apple Maps places, arrange them into multi-day routes, and attach clues to each stop so they are prepared before they set out.

## App

- **Map** — waypoints, route polylines, and Apple Maps POIs. Selecting a stop or place opens it in the sheet.
- **Search sheet** — lists adventures, then drills into routes, waypoints, and place details.
- **Route editor** — while editing a route, search nearby places and add or remove them from the itinerary.
- **SwiftData** — adventures are stored on disk (`Application Support/Wayfolio.store`). The first launch seeds a sample adventure if the store is empty.

Previews use an in-memory container from `SampleData`.

## Custom map items

Custom waypoints (raw coordinates) and recorded leg paths already persist in the model layer. UI for dropping a pin and recording a path is forthcoming.
