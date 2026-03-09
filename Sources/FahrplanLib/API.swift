import Foundation

package struct Search: Codable, Equatable {
  package let SOID: String
  package let ZOID: String
  package let isArrival: Bool
  package let dateTime: Date
  package var paging: String? = nil
  package init(
    SOID: String, ZOID: String, dateTime: Date? = nil, isArrival: Bool? = false,
    paging: String? = nil
  ) {
    self.SOID = SOID
    self.ZOID = ZOID
    self.dateTime = dateTime ?? Date().addingTimeInterval(60 * 2)
    self.isArrival = isArrival ?? false
    self.paging = paging
  }

  package static func == (lhs: Search, rhs: Search) -> Bool {
    return lhs.SOID == rhs.SOID && lhs.ZOID == rhs.ZOID && lhs.isArrival == rhs.isArrival
      && lhs.dateTime == rhs.dateTime
  }

  package func copy(
    SOID: String? = nil, ZOID: String? = nil, dateTime: Date? = nil, isArrival: Bool? = nil,
    paging: String? = nil
  ) -> Search {
    return Search(
      SOID: SOID ?? self.SOID, ZOID: ZOID ?? self.ZOID, dateTime: dateTime ?? self.dateTime,
      isArrival: isArrival ?? self.isArrival, paging: paging ?? self.paging
    )
  }
}

package struct Stop: Codable, Equatable {
  package let id: String
  package var name: String
  package let type: String
  package var extId: String?
  package init(id: String, name: String? = nil, type: String? = nil, extId: String? = nil) {
    self.id = id
    self.extId = extId
    if let name = name {
      self.name = name
    } else if let part = id.components(separatedBy: "@").first(where: { $0.starts(with: "O=") }) {
      self.name = String(part.dropFirst(2))
    } else {
      self.name = id
    }
    if let type = type {
      self.type = type
    } else if id.hasPrefix("A=1") {
      self.type = "ST"
    } else {
      self.type = "ADR"
    }
  }

  package static func == (lhs: Stop, rhs: Stop) -> Bool {
    return lhs.id == rhs.id
  }
}

package struct Trip: Codable {
  package let id: String
  package var segments: [Segment]
  package let changes: Int
  package let duration: Int
  package let estDuration: Int?
  package let warnings: [String]?
  package init(id: String, segments: [Segment], changes: Int, duration: Int, estDuration: Int?, warnings: [String]?) {
    self.id = id
    self.segments = segments
    self.changes = changes
    self.duration = duration
    self.estDuration = estDuration
    self.warnings = warnings
  }

  package func getTripString() -> String {
    guard let firstSegment = segments.first,
          let lastSegment = segments.last,
          let departure = firstSegment.departure,
          let arrival = lastSegment.arrival
    else {
      return ""
    }
    return "\(departure.name) → \(arrival.name)"
  }
}

package struct Segment: Codable {
  package struct Stop: Codable {
    package var name: String
    package var time: Date
    package var estTime: Date?
    package var platform: String?
    package init(name: String, time: Date, estTime: Date? = nil, platform: String? = nil) {
      self.name = name
      self.time = time
      self.estTime = estTime
      self.platform = platform
    }
  }

  package struct By: Codable {
    package var distance: Int?
    package let name: String
    package var shortName: String?
    package var direction: String?
    package init(distance: Int? = nil, name: String, shortName: String? = nil, direction: String? = nil) {
      self.distance = distance
      self.name = name
      self.shortName = shortName
      self.direction = direction
    }
  }

  package var departure: Stop?
  package var arrival: Stop?
  package var by: By?
  package let duration: Int
  package init(departure: Stop? = nil, arrival: Stop? = nil, by: By? = nil, duration: Int) {
    self.departure = departure
    self.arrival = arrival
    self.by = by
    self.duration = duration
  }
}

package struct DataToCache: Codable {
  package let search: Search
  package var trips: [Trip]
  package var reference: [String: String]
  package init(search: Search, trips: [Trip], reference: [String: String]) {
    self.search = search
    self.trips = trips
    self.reference = reference
  }
}

package func searchStops(_ query: String, _ group: DispatchGroup, completion: @escaping (Result<[Stop], MyError>) -> Void) {
  guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
  else {
    completion(.failure(.message("1: Invalid Query")))
    return
  }
  let url = URL(string: "https://www.bahn.de/web/api/reiseloesung/orte?suchbegriff=\(encodedQuery)&typ=ALL&limit=10")!
  group.enter()
  let task = URLSession.shared.dataTask(with: url) { data, _, error in
    defer {
      group.leave()
    }
    if let error = error {
      completion(.failure(.message("2: " + error.localizedDescription)))
      return
    }
    guard let data = data else {
      completion(.failure(.message("3: Invalid data")))
      return
    }
    let decoder = JSONDecoder()
    do {
      let stops = try decoder.decode([Stop].self, from: data)
      completion(.success(stops))
    } catch {
      completion(.failure(.message("4: JSON parsing error")))
    }
  }
  task.resume()
}

package func searchTrips(
  _ search: Search, _ group: DispatchGroup,
  completion: @escaping (Result<(trips: [Trip], reference: [String: String]), MyError>) -> Void
) {
  let SOID = search.SOID
  let ZOID = search.ZOID
  let dateTime = search.dateTime
  let isArrival = search.isArrival
  let paging = search.paging
  let url = URL(string: "https://www.bahn.de/web/api/angebote/fahrplan")!
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
  formatter.timeZone = TimeZone.current
  var request = URLRequest(url: url)
  request.httpMethod = "POST"
  request.addValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
  request.addValue("de", forHTTPHeaderField: "Accept-Language")
  var parameters: [String: Any] = [
    "abfahrtsHalt": SOID,
    "anfrageZeitpunkt": formatter.string(from: dateTime),
    "ankunftsHalt": ZOID,
    "ankunftSuche": isArrival ? "ANKUNFT" : "ABFAHRT",
    "klasse": "KLASSE_2",
    "produktgattungen": [
      "ICE", "EC_IC", "IR", "REGIONAL", "SBAHN", "BUS", "SCHIFF", "UBAHN", "TRAM", "ANRUFPFLICHTIG",
    ],
    "reisende": [
      [
        "typ": "ERWACHSENER",
        "ermaessigungen": [["art": "KEINE_ERMAESSIGUNG", "klasse": "KLASSENLOS"]],
        "alter": [],
        "anzahl": 1,
      ],
    ],
    "schnelleVerbindungen": true,
  ]
  if let paging = paging {
    parameters["pagingReference"] = paging
  }
  request.httpBody = try? JSONSerialization.data(withJSONObject: parameters, options: [])
  group.enter()
  let task = URLSession.shared.dataTask(with: request) { data, response, error in
    defer {
      group.leave()
    }
    if let error = error {
      completion(.failure(.message("5: " + error.localizedDescription)))
      return
    }
    guard let data = data else {
      completion(.failure(.message("6: Invalid data")))
      return
    }
    if let response = response as? HTTPURLResponse, response.statusCode >= 300 {
      completion(.failure(.message("7: Invalid response: \(response.statusCode)")))
      return
    }
    do {
      if let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
        guard let verbindungen = dict["verbindungen"] as? [[String: Any]],
              let reference = dict["verbindungReference"] as? [String: String]
        else {
          completion(.failure(.message("JSON parsing error")))
          return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone.current
        let trips = verbindungen.map { t -> Trip? in
          guard let verbindungsAbschnitte = t["verbindungsAbschnitte"] as? [[String: Any]] else {
            log("Segments init failed")
            return nil
          }
          let segments = verbindungsAbschnitte.map { s -> Segment? in
            var segment = Segment(duration: s["abschnittsDauer"] as? Int ?? 0)
            if let verkehrsmittel = s["verkehrsmittel"] as? [String: Any],
               let name = verkehrsmittel["name"] as? String
            {
              segment.by = Segment.By(name: name)
              if let distance = s["distanz"] as? Int {
                segment.by!.distance = distance
              }
              if let shortName = verkehrsmittel["kurzText"] as? String {
                segment.by!.shortName = shortName
              }
              if let direction = verkehrsmittel["richtung"] as? String {
                segment.by!.direction = direction
              }
            } else {
              log("By init failed")
              return nil
            }
            if let name = s["abfahrtsOrt"] as? String,
               let timeString = s["abfahrtsZeitpunkt"] as? String,
               let time = formatter.date(from: timeString),
               let halte = s["halte"] as? [[String: Any]]
            {
              segment.departure = Segment.Stop(
                name: name, time: time, platform: halte.first?["gleis"] as? String
              )
              if let estTimeString = s["ezAbfahrtsZeitpunkt"] as? String {
                segment.departure!.estTime = formatter.date(from: estTimeString)
              }
            } else {
              log("Departure init failed")
              return nil
            }
            if let name = s["ankunftsOrt"] as? String,
               let timeString = s["ankunftsZeitpunkt"] as? String,
               let time = formatter.date(from: timeString),
               let halte = s["halte"] as? [[String: Any]]
            {
              segment.arrival = Segment.Stop(
                name: name, time: time, platform: halte.last?["gleis"] as? String
              )
              if let estTimeString = s["ezAnkunftsZeitpunkt"] as? String {
                segment.arrival!.estTime = formatter.date(from: estTimeString)
              }
            } else {
              log("Arrival init failed")
              return nil
            }
            return segment
          }.compactMap { $0 }
          guard let id = t["tripId"] as? String,
                let duration = t["verbindungsDauerInSeconds"] as? Int,
                let estDuration = t["ezVerbindungsDauerInSeconds"] as? Int?,
                let changes = t["umstiegsAnzahl"] as? Int,
                let warnings = t["meldungen"] as? [String]?
          else {
            log("Trip init failed")
            return nil
          }
          return Trip(
            id: id, segments: segments, changes: changes, duration: duration,
            estDuration: estDuration, warnings: warnings
          )
        }.compactMap { $0 }
        completion(.success((trips, reference)))
      } else {
        completion(.failure(.message("8: JSON parsing error")))
      }
    } catch {
      completion(.failure(.message("9: \(error.localizedDescription)")))
    }
  }
  task.resume()
}
