import Foundation

struct Search: Codable, Equatable {
  let SOID: String
  let ZOID: String
  let isArrival: Bool
  let dateTime: Date
  var paging: String? = nil
  init(
    SOID: String, ZOID: String, dateTime: Date? = nil, isArrival: Bool? = false,
    paging: String? = nil
  ) {
    self.SOID = SOID
    self.ZOID = ZOID
    self.dateTime = dateTime ?? Date().addingTimeInterval(60 * 2)
    self.isArrival = isArrival ?? false
    self.paging = paging
  }

  static func == (lhs: Search, rhs: Search) -> Bool {
    return lhs.SOID == rhs.SOID && lhs.ZOID == rhs.ZOID && lhs.isArrival == rhs.isArrival
      && lhs.dateTime == rhs.dateTime
  }

  func copy(
    SOID: String? = nil, ZOID: String? = nil, dateTime: Date? = nil, isArrival: Bool? = nil,
    paging: String? = nil
  ) -> Search {
    return Search(
      SOID: SOID ?? self.SOID, ZOID: ZOID ?? self.ZOID, dateTime: dateTime ?? self.dateTime,
      isArrival: isArrival ?? self.isArrival, paging: paging ?? self.paging
    )
  }
}

struct Place: Codable, Equatable {
  let id: String
  var name: String
  let type: String
  var extId: String?
  init(id: String, name: String? = nil, type: String? = nil, extId: String? = nil) {
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

  static func == (lhs: Place, rhs: Place) -> Bool {
    return lhs.id == rhs.id
  }
}

struct Trip: Codable {
  let id: String
  var segments: [Segment]
  let changes: Int
  let duration: Int
  let estDuration: Int?
  let warnings: [String]?
  func getTripString() -> String {
    guard let firstSegment = segments.first,
          let lastSegment = segments.last,
          let departure = firstSegment.departure,
          let arrival = lastSegment.arrival
    else {
      return ""
    }
    return "\(departure.place) → \(arrival.place)"
  }
}

struct Segment: Codable {
  struct Stop: Codable {
    var place: String
    var time: Date
    var estTime: Date?
    var platform: String?
  }

  struct By: Codable {
    var distance: Int?
    let name: String
    var shortName: String?
    var direction: String?
  }

  var departure: Stop?
  var arrival: Stop?
  var by: By?
  let duration: Int
}

struct DataToCache: Codable {
  let search: Search
  var trips: [Trip]
  var reference: [String: String]
}

func searchPlaces(_ query: String, _ group: DispatchGroup, completion: @escaping (Result<[Place], MyError>) -> Void) {
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
      let places = try decoder.decode([Place].self, from: data)
      completion(.success(places))
    } catch {
      completion(.failure(.message("4: JSON parsing error")))
    }
  }
  task.resume()
}

func searchTrips(
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
            if let place = s["abfahrtsOrt"] as? String,
               let timeString = s["abfahrtsZeitpunkt"] as? String,
               let time = formatter.date(from: timeString),
               let halte = s["halte"] as? [[String: Any]]
            {
              segment.departure = Segment.Stop(
                place: place, time: time, platform: halte.first?["gleis"] as? String
              )
              if let estTimeString = s["ezAbfahrtsZeitpunkt"] as? String {
                segment.departure!.estTime = formatter.date(from: estTimeString)
              }
            } else {
              log("Departure init failed")
              return nil
            }
            if let place = s["ankunftsOrt"] as? String,
               let timeString = s["ankunftsZeitpunkt"] as? String,
               let time = formatter.date(from: timeString),
               let halte = s["halte"] as? [[String: Any]]
            {
              segment.arrival = Segment.Stop(
                place: place, time: time, platform: halte.last?["gleis"] as? String
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
          let trip = Trip(
            id: id, segments: segments, changes: changes, duration: duration,
            estDuration: estDuration, warnings: warnings
          )
          return trip
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
