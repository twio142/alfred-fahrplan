import Foundation

class Workflow {
  static let alertIcon = Item.Icon(path: "../../resources/AlertCautionIcon.icns")
  var items: [Item] = []
  var variables: [String: String] = [:]
  struct DataToEncode: Codable {
    let items: [Item]
    var variables: [String: String] = [:]
  }
  func output() {
    let dataToEncode = DataToEncode(items: items, variables: variables)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let json = try! encoder.encode(dataToEncode)
    print(String(data: json, encoding: .utf8)!)
  }
  func add(_ item: Item) {
    items.append(item)
  }
  func warnEmpty(_ title: String, _ subtitle: String = "") {
    items = [Item(title: title, subtitle: subtitle, valid: false, icon: Workflow.alertIcon)]
  }
  func setVar(_ key: String, _ value: String) {
    variables[key] = value
  }
}

struct Item: Codable {
  struct Icon: Codable {
    let path: String
  }
  struct Text: Codable {
    var copy: String?
    var largetype: String?
  }
  enum ModKey: String, Codable {
    case cmd = "cmd"
    case alt = "alt"
    case ctrl = "ctrl"
    case shift = "shift"
    case fn = "fn"
  }
  struct Mod: Codable {
    var valid: Bool = true
    var arg: String = ""
    var subtitle: String?
    var icon: Icon?
    var variables: [String: String] = [:]
  }
  enum ActionType: String, Codable {
    case auto = "auto"
    case file = "file"
    case text = "text"
    case url = "url"
  }
  enum Action: Codable {
    case string(String)
    case array([String])
    func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      switch self {
      case .string(let value):
        try container.encode(value)
      case .array(let value):
        try container.encode(value)
      }
    }
  }
  var title: String
  var subtitle: String = ""
  var arg: String = ""
  var valid: Bool = true
  var icon: Icon?
  var text: Text?
  var variables: [String: String] = [:]
  var mods: [String: Mod] = [:]
  var action: [String: Action] = [:]

  mutating func setMod(_ key: ModKey, _ mod: Mod) {
    mods[key.rawValue] = mod
  }
  mutating func setAction(_ key: ActionType, _ value: Action) {
    action[key.rawValue] = value
  }
}
