import Foundation

private var nativeHostDirectory: URL {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return appSupport.appendingPathComponent("V2rayBox/working/native_host", isDirectory: true)
}

private var sessionCredentialsPath: URL {
    nativeHostDirectory.appendingPathComponent("session.json", isDirectory: false)
}

private var extensionPingPath: URL {
    nativeHostDirectory.appendingPathComponent("extension_ping", isDirectory: false)
}

private let maxMessageSize = 1_048_576

private func readExact(_ handle: FileHandle, count: Int) -> Data? {
    var remaining = count
    var buffer = Data()
    while remaining > 0 {
        let chunk = handle.readData(ofLength: remaining)
        if chunk.isEmpty {
            return nil
        }
        buffer.append(chunk)
        remaining -= chunk.count
    }
    return buffer
}

private func readMessage() -> String? {
    let stdin = FileHandle.standardInput
    guard let lengthData = readExact(stdin, count: 4), lengthData.count == 4 else {
        return nil
    }
    let length = lengthData.withUnsafeBytes { ptr -> UInt32 in
        ptr.load(as: UInt32.self)
    }
    if length == 0 || length > maxMessageSize {
        return nil
    }
    guard let payload = readExact(stdin, count: Int(length)) else {
        return nil
    }
    return String(data: payload, encoding: .utf8)
}

private func writeMessage(_ payload: String) {
    let data = Data(payload.utf8)
    var length = UInt32(data.count)
    let lengthData = withUnsafeBytes(of: length) { Data($0) }
    FileHandle.standardOutput.write(lengthData)
    FileHandle.standardOutput.write(data)
    try? FileHandle.standardOutput.synchronize()
}

private func writePingTimestamp() {
    let now = Int64(Date().timeIntervalSince1970)
    let directory = nativeHostDirectory
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try? "\(now)".write(to: extensionPingPath, atomically: true, encoding: .utf8)
    try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: extensionPingPath.path)
}

private func readSessionPayload() -> String {
    guard let content = try? String(contentsOf: sessionCredentialsPath, encoding: .utf8),
          !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return #"{"type":"clear"}"#
    }
    return content
}

private func handleMessage(_ message: String) {
    guard message.contains("\"type\"") else {
        return
    }
    writePingTimestamp()
    writeMessage(readSessionPayload())
}

while let message = readMessage() {
    handleMessage(message)
}
