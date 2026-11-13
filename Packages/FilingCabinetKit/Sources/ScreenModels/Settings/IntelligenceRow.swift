/// Settings' Apple Intelligence row (10-01, 10-06) and the line under its group.
package struct IntelligenceRow: Equatable {
    /// Whether the model can answer on this iPhone now; when it can't, the switch is off and dimmed.
    package let isAvailable: Bool
    package let isOn: Bool
    package let subtitle: String
    /// What older scans' reading has reached, the privacy line, or why it isn't available.
    package let footer: String
    /// How far the reading of older scans has got, 0 to 1; nil while it isn't reading.
    package let progress: Double?
}
