import Foundation

/// Mide la memoria física (phys_footprint) del proceso actual.
enum MemoryTracker {
    static func currentBytes() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return UInt64(info.phys_footprint)
    }
}

/// Muestra la memoria de forma periódica mientras se ejecuta una operación,
/// guarda un pico y las muestras para poder comparar fases de la ejecución.
final class MemorySampler: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [UInt64] = []
    private var _peak: UInt64 = 0

    var peak: UInt64 {
        lock.withLock { _peak }
    }

    func sample() {
        let current = MemoryTracker.currentBytes()
        lock.withLock {
            samples.append(current)
            _peak = max(_peak, current)
        }
    }

    func snapshot() -> (samples: [UInt64], peak: UInt64) {
        lock.withLock { (samples, _peak) }
    }

    func run(interval: TimeInterval, during operation: () async throws -> Void) async rethrows {
        let sampler = Task.detached { [self] in
            while !Task.isCancelled {
                self.sample()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
        try await operation()
        sampler.cancel()
        sample()
    }

    func reset() {
        lock.withLock {
            samples = []
            _peak = 0
        }
    }
}

private let megabytes = 1024.0 * 1024.0

extension UInt64 {
    var miB: String {
        String(format: "%.1f MiB", Double(self) / megabytes)
    }
}