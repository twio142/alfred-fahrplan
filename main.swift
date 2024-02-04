import Foundation

let query = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ""
if let mode = env["mode"] {
  let workflow = Workflow(), group = DispatchGroup()
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
    if let cache = cachedData("trips") {
      if let tripId = env["tripId"], !tripId.isEmpty, let trip = cache.trips.first(where: { $0.id == tripId }) {
        showTrip(trip, workflow)
      } else {
        listTrips(cache.trips, cache.reference, workflow)
      }
    } else {
      workflow.warnEmpty("No Cached Trips")
    }
  case "searchTrips":
    let cachedSearch = cachedData("trips")?.search
    let SOID = env["SOID"] ?? cachedSearch?.SOID
    let ZOID = env["ZOID"] ?? cachedSearch?.ZOID
    if let SOID = SOID, let ZOID = ZOID {
      let dateTime = env["dateTime"].flatMap { ISO8601DateFormatter().date(from: $0) } ?? cachedSearch?.dateTime
      let isArrival = env["isArrival"].flatMap { $0 == "true" } ?? cachedSearch?.isArrival
      let paging = env["paging"].flatMap { $0.isEmpty ? nil : $0 }
      let search = Search(SOID: SOID, ZOID: ZOID, dateTime: dateTime, isArrival: isArrival, paging: paging)
      searchTrips(search, group) { (result) in
        switch result {
        case .success(var result):
          if paging != nil, let cache = cachedData("trips"), cache.search == search {
            result.trips = (cache.trips + result.trips).sorted(by: { $0.segments[0].departure!.time < $1.segments[0].departure!.time })
          }
          if result.trips.count == 0 {
            workflow.warnEmpty("No Results")
          } else {
            cacheData("trips", DataToCache(search: search, trips: result.trips, reference: result.reference))
            listTrips(result.trips, result.reference, workflow)
          }
        case .failure(let error):
          workflow.warnEmpty(error.localizedDescription)
        }
      }
      group.wait()
    } else {
      workflow.warnEmpty("Invalid Search")
    }
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
