import Foundation

package class Workflow {
  package static let alertIcon = Item.Icon(
    path: (env["alfred_preferences"] ?? "../..") + "/resources/AlertCautionIcon.icns"
  )
  package var items: [Item] = []
  package var variables: [String: String] = [:]
  package struct DataToEncode: Codable {
    package let items: [Item]
    package var variables: [String: String] = [:]
  }

  package init() {}

  package func output() {
    let dataToEncode = DataToEncode(items: items, variables: variables)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let json = try! encoder.encode(dataToEncode)
    print(String(data: json, encoding: .utf8)!)
  }

  package func add(_ item: Item) {
    items.append(item)
  }

  package func warnEmpty(_ title: String, _ subtitle: String = "") {
    items = [Item(title: title, subtitle: subtitle, valid: false, icon: Workflow.alertIcon)]
  }
}

package struct Item: Codable {
  package struct Icon: Codable {
    package let path: String
    package init(path: String) {
      self.path = path
    }
  }

  package struct Text: Codable {
    package var copy: String?
    package var largetype: String?
    package init(copy: String? = nil, largetype: String? = nil) {
      self.copy = copy
      self.largetype = largetype
    }
  }

  package enum ModKey: String, Codable {
    case cmd
    case alt
    case ctrl
    case shift
    case fn
  }

  package struct Mod: Codable {
    package var valid: Bool = true
    package var arg: String = ""
    package var subtitle: String?
    package var icon: Icon?
    package var variables: [String: String] = [:]
    package init(valid: Bool = true, arg: String = "", subtitle: String? = nil, icon: Icon? = nil, variables: [String: String] = [:]) {
      self.valid = valid
      self.arg = arg
      self.subtitle = subtitle
      self.icon = icon
      self.variables = variables
    }
  }

  package enum ActionType: String, Codable {
    case auto
    case file
    case text
    case url
  }

  package enum Action: Codable {
    case string(String)
    case array([String])
    package func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      switch self {
      case let .string(value):
        try container.encode(value)
      case let .array(value):
        try container.encode(value)
      }
    }
  }

  package var title: String
  package var subtitle: String = ""
  package var arg: String = ""
  package var valid: Bool = true
  package var icon: Icon?
  package var text: Text?
  package var variables: [String: String] = [:]
  package var mods: [String: Mod] = [:]
  package var action: [String: Action] = [:]

  package init(
    title: String, subtitle: String = "", arg: String = "", valid: Bool = true,
    icon: Icon? = nil, text: Text? = nil, variables: [String: String] = [:]
  ) {
    self.title = title
    self.subtitle = subtitle
    self.arg = arg
    self.valid = valid
    self.icon = icon
    self.text = text
    self.variables = variables
  }

  package mutating func setMod(_ key: ModKey, _ mod: Mod) {
    mods[key.rawValue] = mod
  }

  package mutating func setAction(_ key: ActionType, _ value: Action) {
    action[key.rawValue] = value
  }

  package mutating func setVar(_ key: String, _ value: String) {
    variables[key] = value
  }
}
