import Foundation

private struct FavoritesStore: Codable {
  var saved: [String]
  var home: HomeEntry?

  struct HomeEntry: Codable {
    var address: String
    var id: String
  }
}

private func favoritesURL() -> URL? {
  guard let dataDir = env["alfred_workflow_data"] else { return nil }
  return URL(fileURLWithPath: "\(dataDir)/data.json")
}

private func readStore() -> FavoritesStore {
  guard let url = favoritesURL(),
        let data = try? Data(contentsOf: url),
        let store = try? JSONDecoder().decode(FavoritesStore.self, from: data)
  else { return FavoritesStore(saved: [], home: nil) }
  return store
}

private func writeStore(_ store: FavoritesStore) {
  guard let url = favoritesURL() else { return }
  do {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try encoder.encode(store)
    try data.write(to: url, options: .atomic)
  } catch {
    log("Error writing to file \(url.path): \(error.localizedDescription)")
  }
}

func favoritePlaces() -> [Place] {
  let store = readStore()
  return store.saved.compactMap { id in
    if let part = id.components(separatedBy: "@").first(where: { $0.starts(with: "O=") }) {
      return Place(id: id, name: String(part.dropFirst(2)))
    }
    return nil
  }
}

func getHome(_ group: DispatchGroup, completion: @escaping (Result<Place, MyError>) -> Void) {
  guard let home = env["home"] else {
    completion(.failure(.message("Home not set")))
    return
  }
  var store = readStore()
  if let entry = store.home, entry.address == home {
    completion(.success(Place(id: entry.id, name: "Home")))
    return
  }
  searchPlaces(home, group) { result in
    switch result {
    case let .success(places):
      if places.count == 0 {
        completion(.failure(.message("Home not found")))
        return
      }
      var place = places[0]
      place.name = "Home"
      store.home = FavoritesStore.HomeEntry(address: home, id: place.id)
      writeStore(store)
      completion(.success(place))
    case let .failure(error):
      completion(.failure(error))
    }
  }
}

func savePlace(_ placeId: String) {
  var store = readStore()
  if store.saved.contains(placeId) { return }
  store.saved.append(placeId)
  writeStore(store)
  notify("Place saved")
}

func removePlace(_ placeId: String) {
  var store = readStore()
  if !store.saved.contains(placeId) { return }
  store.saved.removeAll { $0 == placeId }
  writeStore(store)
  notify("Place removed")
}
