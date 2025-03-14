import Foundation

struct MyError: Error {
  let localizedDescription: String
  init(_ message: String) {
    localizedDescription = message
  }

  static func message(_ message: String) -> MyError {
    return MyError(message)
  }
}

func log(_ info: Any...) {
  for i in info {
    if let data = (String(describing: i) + " ").data(using: .utf8) {
      FileHandle.standardError.write(data)
    }
  }
  FileHandle.standardError.write("\n".data(using: .utf8)!)
}

func debug(_ info: Any...) {
  if env["debug"] != nil || env["alfred_debug"] != nil {
    log(info)
  }
}

let env = ProcessInfo.processInfo.environment
