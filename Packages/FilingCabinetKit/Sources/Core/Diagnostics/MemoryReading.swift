import Darwin
import os

/// The app's memory at one moment, in bytes, as the system counts it (#50).
package struct MemoryReading: Equatable, Sendable {
    /// What the app holds now: the footprint the system judges it by.
    package let now: UInt64
    /// The highest `now` has been since the process started. The system keeps it, so nothing between two readings is
    /// missed.
    package let peak: UInt64
    /// How much more the app may take before the system stops it. Nil on the Mac, which has no such limit.
    package let left: UInt64?

    /// Nil when the system doesn't answer.
    package static func current() -> Self? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { integers in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), integers, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return Self(
            now: info.phys_footprint, peak: UInt64(max(info.ledger_phys_footprint_peak, 0)), left: availableMemory())
    }

    private static func availableMemory() -> UInt64? {
        #if os(iOS)
            UInt64(os_proc_available_memory())
        #else
            nil
        #endif
    }
}
