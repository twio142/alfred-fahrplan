import Foundation

func setTime(_ query: String, _ workflow: Workflow) {
  var dateTime = Date()
  guard let regex1 = try? NSRegularExpression(pattern: "([0123]?\\d)\\.([012]?\\d)", options: []),
        let regex2 = try? NSRegularExpression(pattern: "([012]?\\d):(\\d{2})?", options: []),
        let regex3 = try? NSRegularExpression(pattern: "\\+(\\d+)([mhd])?", options: [])
  else {
    return
  }
  let matches1 = regex1.matches(
    in: query, options: [], range: NSRange(query.startIndex..., in: query)
  )
  if matches1.count > 0 {
    let match = matches1[0]
    if let range = Range(match.range(at: 2), in: query), let number = Int(query[range]),
       number > 0, number < 13
    {
      dateTime = Calendar.current.date(bySetting: .month, value: number, of: dateTime)!
    }
    if let range = Range(match.range(at: 1), in: query), let number = Int(query[range]),
       number > 0, number < 32
    {
      dateTime = Calendar.current.date(bySetting: .day, value: number, of: dateTime)!
    }
    if dateTime < Date() {
      dateTime = Calendar.current.date(byAdding: .year, value: 1, to: dateTime)!
    }
  }
  let matches2 = regex2.matches(
    in: query, options: [], range: NSRange(query.startIndex..., in: query)
  )
  if matches2.count > 0 {
    let match = matches2[0]
    var hour = 0
    var minute = 0
    if let range = Range(match.range(at: 1), in: query), let number = Int(query[range]), number < 24 {
      hour = number
    }
    if match.range(at: 2).location != NSNotFound, let range = Range(match.range(at: 2), in: query),
       let number = Int(query[range]), number < 60
    {
      minute = number
    }
    dateTime = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: dateTime)!
    if dateTime < Date() {
      dateTime = Calendar.current.date(byAdding: .day, value: 1, to: dateTime)!
    }
  }
  let matches3 = regex3.matches(
    in: query, options: [], range: NSRange(query.startIndex..., in: query)
  )
  for match in matches3 {
    var number = 0
    var unit = "m"
    if let range = Range(match.range(at: 1), in: query) {
      number = Int(query[range])!
    }
    if match.range(at: 2).location != NSNotFound, let range = Range(match.range(at: 2), in: query) {
      unit = String(query[range])
    }
    if number > 0 {
      dateTime = Calendar.current.date(
        byAdding: unit == "m" ? .minute : unit == "h" ? .hour : .day, value: number, to: dateTime
      )!
    }
  }
  let formatter = DateFormatter()
  formatter.dateFormat =
    Calendar.current.isDateInToday(dateTime) ? "HH:mm" : "EEE, dd.MM.yyyy HH:mm"
  formatter.locale = Locale(identifier: "de_DE")
  let title = dateTime.timeIntervalSince(Date()) < 3 ? "Jetzt" : formatter.string(from: dateTime)
  let isoDateTime = ISO8601DateFormatter().string(from: dateTime)
  var item = Item(
    title: title, subtitle: "Abfahrt", icon: Item.Icon(path: "./icons/clock.png"),
    variables: ["mode": "searchTrips", "dateTime": isoDateTime]
  )
  item.setMod(
    .cmd,
    Item.Mod(
      subtitle: "Ankunft",
      variables: ["mode": "searchTrips", "dateTime": isoDateTime, "isArrival": "true"]
    )
  )
  workflow.add(item)
}

func setPlace(
  _ query: String, _ workflow: Workflow, _ group: DispatchGroup,
  completion: @escaping (Result<Void, MyError>) -> Void
) {
  let favorites = favoritePlaces()
  var places = favorites
  var home = nil as Place?
  getHome(group) { result in
    if case let .success(place) = result {
      home = place
      places.append(place)
    }
  }
  group.wait()
  if !query.isEmpty {
    places = places.filter { $0.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)) }
  }
  if query.count > 5 {
    searchPlaces(query, group) { result in
      if case let .success(newPlaces) = result {
        places += newPlaces.filter { place in !places.contains(place) }
      }
    }
    group.wait()
  }
  var startPlace: Place?
  if let SOID = env["SOID"] {
    startPlace = Place(id: SOID)
    if let home = home, home.id == SOID {
      startPlace = home
    }
    places = places.filter { $0 != startPlace }
  }
  for place in places {
    var item = Item(title: place.name)
    if let home = home, place == home {
      item.icon = Item.Icon(path: "./icons/home.png")
    } else if favorites.contains(place) {
      item.icon = Item.Icon(path: "./icons/favorite.png")
    } else if place.type == "ST" {
      item.icon = Item.Icon(path: "./icons/station.png")
    } else {
      item.icon = Item.Icon(path: "./icons/address.png")
    }
    if let startPlace = startPlace {
      item.arg = "\(startPlace.name) → \(place.name)"
      item.setVar("trip", "\(startPlace.name) → \(place.name)")
      item.setVar("ZOID", place.id)
      item.setVar("mode", "searchTrips")
      var modVars = item.variables
      modVars["mode"] = "setTime"
      item.setMod(
        .cmd,
        Item.Mod(
          arg: "", subtitle: "Zeit angeben …", icon: Item.Icon(path: "./icons/clock.png"),
          variables: modVars
        )
      )
    } else {
      if favorites.contains(place) {
        item.setMod(
          .shift,
          Item.Mod(
            arg: place.id, subtitle: "Von Favoriten entfernen",
            icon: Item.Icon(path: "./icons/trash.png"), variables: ["action": "removePlace"]
          )
        )
      } else {
        item.setMod(
          .shift,
          Item.Mod(
            arg: place.id, subtitle: "Zu Favoriten speichern",
            icon: Item.Icon(path: "./icons/favorite.png"), variables: ["action": "savePlace"]
          )
        )
      }
      item.setVar("SOID", place.id)
    }
    workflow.add(item)
  }
  return completion(.success(()))
}

func listTrips(_ trips: [Trip], _ reference: [String: String]?, _ workflow: Workflow) {
  let formatter = DateFormatter()
  formatter.dateFormat = "HH:mm"
  for trip in trips {
    var title = ""
    var subtitle: [String] = []
    let departureTime = trip.segments.first!.departure!.time
    title += formatter.string(from: departureTime)
    let estDepartureTime = trip.segments.first!.departure!.estTime
    if Date().timeIntervalSince(estDepartureTime ?? departureTime) > 600 {
      continue
    }
    if let estDepartureTime = estDepartureTime,
       let delay = formatDuration(Int(estDepartureTime.timeIntervalSince(departureTime)))
    {
      title += " (+\(delay))"
    }
    title += " — "
    let arrivalTime = trip.segments.last!.arrival!.time
    title += formatter.string(from: arrivalTime)
    if let estArrivalTime = trip.segments.last!.arrival!.estTime,
       let delay = formatDuration(Int(estArrivalTime.timeIntervalSince(arrivalTime)))
    {
      title += " (+\(delay))"
    }
    if let duration = formatDuration(trip.duration) {
      title += "  |  \(duration)"
    }
    let changes = trip.changes
    if changes > 0 {
      title += "  |  \(changes) Umstieg\(changes > 1 ? "e" : "")"
    }
    if let segment = trip.segments.first(where: { $0.by!.name != "Fußweg" }) {
      subtitle.append(segment.departure!.place)
    } else {
      subtitle.append(trip.segments.first!.departure!.place)
    }
    let products = trip.segments.filter { $0.by!.name != "Fußweg" }.map { segment in
      if let shortName = segment.by!.shortName, ["Bus", "S", "U"].contains(shortName) {
        return segment.by!.name
      }
      return segment.by!.shortName ?? segment.by!.name
    }.joined(separator: ", ")
    subtitle.append(products)
    if let segment = trip.segments.last(where: { $0.by!.name != "Fußweg" }) {
      subtitle.append(segment.arrival!.place)
    } else {
      subtitle.append(trip.segments.last!.arrival!.place)
    }
    let expired = (estDepartureTime ?? departureTime) < Date().addingTimeInterval(60)
    let item = Item(
      title: title,
      subtitle: tripSubtitle(subtitle),
      icon: Item.Icon(path: "./icons/trip\(expired ? "_exp" : "").png"),
      text: Item.Text(copy: timeTable(trip)),
      variables: ["tripId": trip.id, "paging": "", "mode": "cachedTrips"]
    )
    workflow.add(item)
  }
  if workflow.items.count == 0 {
    workflow.warnEmpty("No Results")
  } else if let reference = reference {
    var item = Item(
      title: "Mehr Verbindungen", subtitle: "Später", icon: Item.Icon(path: "./icons/next.png"),
      variables: ["paging": reference["later"]!, "mode": "searchTrips"]
    )
    item.setMod(
      .cmd,
      Item.Mod(
        subtitle: "Früher", icon: Item.Icon(path: "./icons/previous.png"),
        variables: ["paging": reference["earlier"]!, "mode": "searchTrips"]
      )
    )
    let newDateTime = ISO8601DateFormatter().string(from: Date().addingTimeInterval(60 * 2))
    item.setMod(
      .alt,
      Item.Mod(
        subtitle: "Neue Suche", icon: Item.Icon(path: "./icons/rerun.png"),
        variables: ["mode": "searchTrips", "dateTime": newDateTime, "paging": ""]
      )
    )
    workflow.add(item)
  }
}

func showTrip(_ trip: Trip, _ workflow: Workflow) {
  /*
   12:28 (+7)  Hamburg Hbf (Gl. 8)
   4h 21 min   ICE 777 (nach Frankfurt(Main)Hbf)
   16:56       Frankfurt(Main)Hbf (Gl. 13)
   30 min      Umstieg
   17:26       Frankfurt(Main)Hbf (Gl. 18)
   2h 47min    RE 3 (nach Saafbrücken Hbf)
   20:13       Saafbrücken Hbf
   5 min       154m Fußweg (ca. 4min)
   20:18       Hauptbahnhof, Saarbrücken
   9 min       STB 1 (nach Brebach)
   20:27       Kieselhumes, Saarbrücken
               142m Fußweg (ca. 3min)
   20:30       Saarbrücken - Sankt Johann, Straße des 13. Januar 12
   */
  for (index, segment) in trip.segments.enumerated() {
    if segment.by!.name != "Fußweg" || index == trip.segments.count - 1 {
      if segment.by!.name != "Fußweg" {
        workflow.add(
          Item(
            title: segmentTitle(segment.departure!), subtitle: segmentSubtitle(segment),
            arg: env["trip"] ?? "", text: Item.Text(copy: timeTable(trip)),
            variables: ["tripId": ""]
          ))
      }
      var item = Item(
        title: segmentTitle(segment.arrival!), arg: env["trip"] ?? "",
        text: Item.Text(copy: timeTable(trip))
      )
      if index < trip.segments.count - 1 {
        let nextSegment = trip.segments[index + 1]
        item.subtitle =
          formatDuration(Int(nextSegment.departure!.time.timeIntervalSince(segment.arrival!.time)))
            ?? "      "
        item.subtitle += "\t"
        if nextSegment.by!.name == "Fußweg" {
          item.subtitle += "\(nextSegment.by!.distance!)m Fußweg"
          if let duration = formatDuration(nextSegment.duration) {
            item.subtitle += " (ca. \(duration))"
          }
        } else {
          item.subtitle += "Umstieg"
        }
      }
      item.setVar("tripId", "")
      workflow.add(item)
    }
  }
}
