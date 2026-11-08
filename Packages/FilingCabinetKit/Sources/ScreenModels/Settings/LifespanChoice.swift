import Core

/// One entry of "Keep scans for": "3 months", marked when it is the collection's current lifespan.
package struct LifespanChoice: Equatable {
    package let lifespan: Lifespan
    package let title: String
    package let isCurrent: Bool
}
