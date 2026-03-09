@testable import FahrplanLib
import Foundation
import Testing

extension Tag {
  @Tag static var integration: Self
}

// MARK: - Helpers

private func fetchStops(_ query: String) async throws -> [Stop] {
  let result: Result<[Stop], MyError> = await withCheckedContinuation { cont in
    let group = DispatchGroup()
    var captured: Result<[Stop], MyError>?
    searchStops(query, group) { r in captured = r }
    group.notify(queue: .global()) { cont.resume(returning: captured!) }
  }
  return try result.get()
}

private func fetchTrips(_ search: Search) async throws -> (trips: [Trip], reference: [String: String]) {
  let result: Result<(trips: [Trip], reference: [String: String]), MyError> =
    await withCheckedContinuation { cont in
      let group = DispatchGroup()
      var captured: Result<(trips: [Trip], reference: [String: String]), MyError>?
      searchTrips(search, group) { r in captured = r }
      group.notify(queue: .global()) { cont.resume(returning: captured!) }
    }
  return try result.get()
}

// MARK: - searchStops

@Suite(.tags(.integration))
struct SearchStopsIntegrationTests {
  @Test("returns non-empty results for a known station query")
  func returnsResults() async throws {
    let stops = try await fetchStops("Hamburg Hbf")
    #expect(!stops.isEmpty)
  }

  @Test("each stop has non-empty id, name, and type")
  func stopFieldsNonEmpty() async throws {
    let stops = try await fetchStops("Frankfurt")
    #expect(!stops.isEmpty)
    for stop in stops {
      #expect(!stop.id.isEmpty, "id should not be empty (stop: \(stop.name))")
      #expect(!stop.name.isEmpty, "name should not be empty (id: \(stop.id))")
      #expect(!stop.type.isEmpty, "type should not be empty (stop: \(stop.name))")
    }
  }

  @Test("stop type is a known value")
  func stopTypeIsKnown() async throws {
    let stops = try await fetchStops("Berlin")
    let knownTypes = ["ST", "ADR", "POI", "MCP", "PCH"]
    for stop in stops {
      #expect(knownTypes.contains(stop.type), "Unknown type '\(stop.type)' for stop '\(stop.name)'")
    }
  }

  @Test("results contain a stop matching the query city")
  func resultsMatchQuery() async throws {
    let stops = try await fetchStops("München Hbf")
    #expect(stops.contains { $0.name.localizedCaseInsensitiveContains("München") })
  }

  @Test("station stop id contains the expected format fields")
  func stationIdFormat() async throws {
    // Station (type=ST) IDs should encode name, coordinates, etc.
    let stops = try await fetchStops("Hamburg Hbf")
    let stations = stops.filter { $0.type == "ST" }
    #expect(!stations.isEmpty, "Expected at least one station result")
    for station in stations {
      // Format: A=1@O=Name@X=lon@Y=lat@...
      #expect(station.id.contains("@"), "Station id should be @ delimited: \(station.id)")
      #expect(station.id.contains("O="), "Station id should contain O= name component: \(station.id)")
    }
  }
}

// MARK: - searchTrips

@Suite(.tags(.integration))
struct SearchTripsIntegrationTests {
  // MARK: Trip-level schema

  @Test("returns non-empty trips with a paging reference")
  func returnsTripsAndReference() async throws {
    let from = try try #require(await fetchStops("Hamburg Hbf").first)
    let to = try try #require(await fetchStops("Frankfurt(Main)Hbf").first)
    let (trips, reference) = try await fetchTrips(Search(SOID: from.id, ZOID: to.id))
    #expect(!trips.isEmpty, "Expected trips between Hamburg and Frankfurt")
    #expect(!reference.isEmpty, "Expected a paging reference")
  }

  @Test("every trip has a non-empty id")
  func tripIdNonEmpty() async throws {
    let from = try try #require(await fetchStops("Hamburg Hbf").first)
    let to = try try #require(await fetchStops("Frankfurt(Main)Hbf").first)
    let (trips, _) = try await fetchTrips(Search(SOID: from.id, ZOID: to.id))
    for trip in trips {
      #expect(!trip.id.isEmpty, "tripId should not be empty")
    }
  }

  @Test("every trip has non-negative duration and change count")
  func tripDurationAndChanges() async throws {
    let from = try try #require(await fetchStops("Hamburg Hbf").first)
    let to = try try #require(await fetchStops("Frankfurt(Main)Hbf").first)
    let (trips, _) = try await fetchTrips(Search(SOID: from.id, ZOID: to.id))
    for trip in trips {
      #expect(trip.duration >= 0, "duration should be >= 0 (trip: \(trip.id))")
      #expect(trip.changes >= 0, "changes should be >= 0 (trip: \(trip.id))")
    }
  }

  // MARK: Segment-level schema

  @Test("every segment has a non-nil by with a non-empty name")
  func segmentByName() async throws {
    let from = try try #require(await fetchStops("Hamburg Hbf").first)
    let to = try try #require(await fetchStops("Frankfurt(Main)Hbf").first)
    let (trips, _) = try await fetchTrips(Search(SOID: from.id, ZOID: to.id))
    for trip in trips {
      for seg in trip.segments {
        #expect(seg.by != nil, "segment.by should not be nil (trip: \(trip.id))")
        #expect(!(seg.by?.name.isEmpty ?? true), "segment.by.name should not be empty (trip: \(trip.id))")
      }
    }
  }

  @Test("every segment has departure and arrival with non-empty station names")
  func segmentStationNames() async throws {
    let from = try try #require(await fetchStops("Hamburg Hbf").first)
    let to = try try #require(await fetchStops("Frankfurt(Main)Hbf").first)
    let (trips, _) = try await fetchTrips(Search(SOID: from.id, ZOID: to.id))
    for trip in trips {
      for seg in trip.segments {
        #expect(seg.departure != nil, "departure should not be nil (trip: \(trip.id))")
        #expect(seg.arrival != nil, "arrival should not be nil (trip: \(trip.id))")
        #expect(!(seg.departure?.name.isEmpty ?? true), "departure.name should not be empty")
        #expect(!(seg.arrival?.name.isEmpty ?? true), "arrival.name should not be empty")
      }
    }
  }

  @Test("departure and arrival times are in a plausible range")
  func segmentTimes() async throws {
    let from = try try #require(await fetchStops("Hamburg Hbf").first)
    let to = try try #require(await fetchStops("Frankfurt(Main)Hbf").first)
    let (trips, _) = try await fetchTrips(Search(SOID: from.id, ZOID: to.id))
    let now = Date()
    let window = DateInterval(start: now.addingTimeInterval(-3600), duration: 48 * 3600)
    for trip in trips {
      for seg in trip.segments {
        if let dep = seg.departure {
          #expect(window.contains(dep.time), "departure time out of range: \(dep.time)")
        }
        if let arr = seg.arrival {
          #expect(window.contains(arr.time), "arrival time out of range: \(arr.time)")
        }
      }
    }
  }

  @Test("arrival search (isArrival: true) returns trips")
  func arrivalSearch() async throws {
    let from = try try #require(await fetchStops("Hamburg Hbf").first)
    let to = try try #require(await fetchStops("Frankfurt(Main)Hbf").first)
    let (trips, _) = try await fetchTrips(Search(SOID: from.id, ZOID: to.id, isArrival: true))
    #expect(!trips.isEmpty, "Expected trips for arrival-based search")
  }

  @Test("paging reference contains 'later' key")
  func pagingLaterKey() async throws {
    let from = try try #require(await fetchStops("Hamburg Hbf").first)
    let to = try try #require(await fetchStops("Frankfurt(Main)Hbf").first)
    let (_, reference) = try await fetchTrips(Search(SOID: from.id, ZOID: to.id))
    #expect(reference["later"] != nil, "Expected 'later' paging key")
  }

  @Test("paging with 'later' reference returns additional trips")
  func pagingWorks() async throws {
    let from = try try #require(await fetchStops("Hamburg Hbf").first)
    let to = try try #require(await fetchStops("Frankfurt(Main)Hbf").first)
    let search = Search(SOID: from.id, ZOID: to.id)
    let (firstTrips, reference) = try await fetchTrips(search)
    guard let laterToken = reference["later"] else {
      Issue.record("No 'later' paging token in first response")
      return
    }
    let (laterTrips, _) = try await fetchTrips(search.copy(paging: laterToken))
    #expect(!laterTrips.isEmpty, "Expected trips on second page")
    // Later page should start after the first page's last departure
    if let firstLast = firstTrips.last?.segments.first?.departure?.time,
       let laterFirst = laterTrips.first?.segments.first?.departure?.time
    {
      #expect(laterFirst >= firstLast, "Later-page trips should depart after first-page trips")
    }
  }
}
