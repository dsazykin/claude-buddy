import Darwin
import Foundation

struct ScannedProcess {
    let pid: pid_t
    /// `p_comm`, truncated by the kernel to 16 characters.
    let command: String
    /// Flattened argv, empty when it could not be read.
    let arguments: String
}

/// Enumerates the current user's processes with `sysctl`.
///
/// This avoids spawning `ps`/`pgrep` every few seconds, and needs no special
/// entitlements: reading process arguments is permitted for processes owned by
/// the same user.
enum ProcessScanner {

    static func userProcesses() -> [ScannedProcess] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_UID, Int32(getuid())]

        var size = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0, size > 0 else { return [] }

        let stride = MemoryLayout<kinfo_proc>.stride
        // Slack, because the process list can grow between the two calls.
        var buffer = [kinfo_proc](repeating: kinfo_proc(), count: size / stride + 32)
        size = buffer.count * stride
        guard sysctl(&mib, 4, &buffer, &size, nil, 0) == 0 else { return [] }

        let count = size / stride
        var result: [ScannedProcess] = []
        result.reserveCapacity(count)

        for index in 0..<min(count, buffer.count) {
            let entry = buffer[index]
            let pid = entry.kp_proc.p_pid
            guard pid > 0 else { continue }
            let command = withUnsafeBytes(of: entry.kp_proc.p_comm) { nullTerminatedString($0) }
            guard !command.isEmpty else { continue }
            result.append(ScannedProcess(pid: pid, command: command, arguments: arguments(for: pid)))
        }
        return result
    }

    /// Total CPU time consumed by a process so far, in nanoseconds.
    static func cpuNanoseconds(for pid: pid_t) -> UInt64? {
        var info = rusage_info_v4()
        let status = withUnsafeMutablePointer(to: &info) { pointer -> Int32 in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebound in
                proc_pid_rusage(pid, RUSAGE_INFO_V4, rebound)
            }
        }
        guard status == 0 else { return nil }
        return info.ri_user_time &+ info.ri_system_time
    }

    // MARK: - Private

    private static func arguments(for pid: pid_t) -> String {
        var argmax: Int32 = 0
        var argmaxSize = MemoryLayout<Int32>.size
        var argmaxMib: [Int32] = [CTL_KERN, KERN_ARGMAX]
        guard sysctl(&argmaxMib, 2, &argmax, &argmaxSize, nil, 0) == 0, argmax > 0 else { return "" }

        var buffer = [UInt8](repeating: 0, count: Int(argmax))
        var size = Int(argmax)
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else {
            return ""
        }

        // Layout: argc (Int32), exec path, NUL padding, then argv/envp entries,
        // each NUL terminated. Joining the whole blob with spaces is enough for
        // substring matching and avoids parsing the padding rules.
        let payload = buffer[MemoryLayout<Int32>.size..<size]
        let text = String(decoding: payload, as: UTF8.self)
        return text
            .split(whereSeparator: { $0 == "\0" })
            .joined(separator: " ")
    }

    private static func nullTerminatedString(_ raw: UnsafeRawBufferPointer) -> String {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(raw.count)
        for byte in raw {
            if byte == 0 { break }
            bytes.append(byte)
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
