import Core

/// Where a saved page lands: its collection's badge on Home, or its own tile in the grid the scan started from.
package enum FlightDestination: Hashable {
    case badge(BuiltInCollection)
    case tile(ScanID)
}
