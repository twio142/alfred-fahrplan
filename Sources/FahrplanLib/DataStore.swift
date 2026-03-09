import Foundation

private struct DataStore: Codable {
  var saved: [String]
  var home: HomeEntry?

  struct HomeEntry: Codable {
    var address: String
    var id: String
  }
}

private func dataURL() -> URL? {
  guard let dataDir = env["alfred_workflow_data"] else { return nil }
  return URL(fileURLWithPath: "\(dataDir)/data.json")
}

private func readStore() -> DataStore {
  guard let url = dataURL(),
        let data = try? Data(contentsOf: url),
        let store = try? JSONDecoder().decode(DataStore.self, from: data)
  else { return DataStore(saved: [], home: nil) }
  return store
}

private func writeStore(_ store: DataStore) {
  guard let url = dataURL() else { return }
  do {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try encoder.encode(store)
    try data.write(to: url, options: .atomic)
  } catch {
    log("Error writing to file \(url.path): \(error.localizedDescription)")
  }
}

package func savedStops() -> [Stop] {
  let store = readStore()
  return store.saved.compactMap { id in
    if let part = id.components(separatedBy: "@").first(where: { $0.starts(with: "O=") }) {
      return Stop(id: id, name: String(part.dropFirst(2)))
    }
    return nil
  }
}

package func getHome(_ group: DispatchGroup, completion: @escaping (Result<Stop, MyError>) -> Void) {
  guard let home = env["home"] else {
    completion(.failure(.message("Home not set")))
    return
  }
  var store = readStore()
  if let entry = store.home, entry.address == home {
    completion(.success(Stop(id: entry.id, name: "Home")))
    return
  }
  searchStops(home, group) { result in
    switch result {
    case let .success(stops):
      if stops.count == 0 {
        completion(.failure(.message("Home not found")))
        return
      }
      var stop = stops[0]
      stop.name = "Home"
      store.home = DataStore.HomeEntry(address: home, id: stop.id)
      writeStore(store)
      completion(.success(stop))
    case let .failure(error):
      completion(.failure(error))
    }
  }
}

package func saveStop(_ stopId: String) {
  var store = readStore()
  if store.saved.contains(stopId) { return }
  store.saved.append(stopId)
  writeStore(store)
  notify("Stop saved")
}

package func removeStop(_ stopId: String) {
  var store = readStore()
  if !store.saved.contains(stopId) { return }
  store.saved.removeAll { $0 == stopId }
  writeStore(store)
  notify("Stop removed")
}
