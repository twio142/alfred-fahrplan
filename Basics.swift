import Foundation

struct MyError: Error {
  let localizedDescription: String
  init(_ message: String) {
    self.localizedDescription = message
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

let env = ProcessInfo.processInfo.environment