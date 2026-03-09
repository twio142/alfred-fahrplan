import Foundation

package struct MyError: Error {
  package let localizedDescription: String
  package init(_ message: String) {
    localizedDescription = message
  }

  package static func message(_ message: String) -> MyError {
    return MyError(message)
  }
}

package func log(_ info: Any...) {
  for i in info {
    if let data = (String(describing: i) + " ").data(using: .utf8) {
      FileHandle.standardError.write(data)
    }
  }
  FileHandle.standardError.write("\n".data(using: .utf8)!)
}

package func debug(_ info: Any...) {
  if env["debug"] != nil || env["alfred_debug"] != nil {
    log(info)
  }
}

package let env = ProcessInfo.processInfo.environment
