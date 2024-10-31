import Foundation

guard let cacheDir = env["alfred_workflow_cache"] else {
  log("alfred_workflow_cache not set")
  exit(1)
}
let fileManager = FileManager.default
if !fileManager.fileExists(atPath: cacheDir) {
  do {
    try fileManager.createDirectory(atPath: cacheDir, withIntermediateDirectories: true, attributes: nil)
  } catch {
    log("Error creating cache directory \(cacheDir): \(error.localizedDescription)")
    exit(1)
  }
}

let query = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ""
if let mode = env["mode"] {
  let workflow = Workflow(), group = DispatchGroup()
  debug(mode)
  switch mode {
  case "setPlace":
    setPlace(query, workflow, group) { (result) in
      switch result {
      case .success():
        if workflow.items.count == 0 {
          workflow.warnEmpty("No Results")
        }
      case .failure(let error):
        workflow.warnEmpty(error.localizedDescription)
      }
    }
    group.wait()
  case "setTime":
    setTime(query, workflow)
  case "cachedTrips":
    if let cache = readCache("trips") {
      if let tripId = env["tripId"], !tripId.isEmpty, let trip = cache.trips.first(where: { $0.id == tripId }) {
        showTrip(trip, workflow)
      } else {
        listTrips(cache.trips, cache.reference, workflow)
      }
    } else {
      workflow.warnEmpty("No Cached Trips")
    }
  case "searchTrips":
    var search: Search
    let paging = env["paging"].flatMap { $0.isEmpty ? nil : $0 }
    if let paging = paging, let cachedSearch = readCache("trips")?.search {
      search = cachedSearch.copy(paging: paging)
    } else if let SOID = env["SOID"], let ZOID = env["ZOID"] {
      search = Search(SOID: SOID, ZOID: ZOID, dateTime: env["dateTime"].flatMap { ISO8601DateFormatter().date(from: $0) }, isArrival: env["isArrival"].flatMap { $0 == "true" })
    } else if let dateTime = env["dateTime"].flatMap ({ ISO8601DateFormatter().date(from: $0) }), let cachedSearch = readCache("trips")?.search {
      search = cachedSearch.copy(dateTime: dateTime)
    } else {
      workflow.warnEmpty("Invalid Search")
      break
    }
    searchTrips(search, group) { (result) in
      switch result {
      case .success(var result):
        if paging != nil, let cache = readCache("trips"), cache.search == search {
          result.trips = (cache.trips + result.trips).sorted(by: { $0.segments[0].departure!.time < $1.segments[0].departure!.time })
        }
        if result.trips.count == 0 {
          workflow.warnEmpty("No Results")
        } else {
          writeCache("trips", DataToCache(search: search, trips: result.trips, reference: result.reference))
          listTrips(result.trips, result.reference, workflow)
        }
      case .failure(let error):
        workflow.warnEmpty(error.localizedDescription)
      }
    }
    group.wait()
    default:
      workflow.warnEmpty("Invalid Mode: \(mode)")
  }
  workflow.output()
} else if let action = env["action"] {
  switch action {
  case "savePlace":
    savePlace(query)
  case "removePlace":
    removePlace(query)
  default:
    log("Invalid Action: \(action)")
  }
}
