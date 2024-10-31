import Foundation

func favoritePlaces() -> [Place] {
  let url = URL(fileURLWithPath: "./places.txt")
  do {
    let data = try String(contentsOf: url, encoding: .utf8)
    let lines = data.components(separatedBy: .newlines)
    let places = lines.map { (line) -> Place? in
      if let part = line.components(separatedBy: "@").first(where: { $0.starts(with: "O=") }) {
        return Place(id: line, name: String(part.dropFirst(2)))
      }
      return nil
    }.compactMap { $0 }
    return places
  } catch {
    return []
  }
}

func getHome(_ group: DispatchGroup, completion: @escaping(Result<Place, MyError>) -> Void) {
  if let home = env["home"] {
    let url = URL(fileURLWithPath: "./home.txt")
    do {
      let lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: CharacterSet.newlines)
      if lines[0] == home, lines.count > 1, lines[1].firstIndex(of: "@") != nil {
        completion(.success(Place(id: lines[1], name: "Home")))
        return
      } else {
        throw MyError("Home not found")
      }
    } catch {
      searchPlaces(home, group) { (result) in
        switch result {
        case .success(let places):
          if places.count == 0 {
            completion(.failure(.message("Home not found")))
            return
          }
          var place = places[0]
          place.name = "Home"
          do {
            try "\(home)\n\(place.id)".write(to: url, atomically: true, encoding: .utf8)
          } catch {
            log("Error writing to file \(url.path): \(error.localizedDescription)")
          }
          completion(.success(place))
        case .failure(let error):
          completion(.failure(error))
        }
      }
    }
  } else {
    completion(.failure(.message("Home not set")))
  }
}

func savePlace(_ placeId: String) {
  let fileManager = FileManager.default
  let url = URL(fileURLWithPath: "./places.txt")
  do {
    if !fileManager.fileExists(atPath: url.path) {
      try "".write(to: url, atomically: true, encoding: .utf8)
    }
    var lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: CharacterSet.newlines)
    if lines.contains(placeId) {
      return
    }
    lines.append(placeId)
    try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    notify("Place saved")
  } catch {
    log("Error writing to file \(url.path): \(error.localizedDescription)")
  }
}

func removePlace(_ placeId: String) {
  let fileManager = FileManager.default
  let url = URL(fileURLWithPath: "./places.txt")
  do {
    if !fileManager.fileExists(atPath: url.path) {
      return
    }
    var lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: CharacterSet.newlines)
    if !lines.contains(placeId) {
      return
    }
    lines.removeAll { $0 == placeId }
    try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    notify("Place removed")
  } catch {
    log("Error writing to file \(url.path): \(error.localizedDescription)")
  }
}
