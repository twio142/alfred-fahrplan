@testable import FahrplanLib
import Foundation
import Testing

// MARK: - formatDuration

struct FormatDurationTests {
  @Test("zero seconds returns nil")
  func zeroSeconds() {
    #expect(formatDuration(0) == nil)
  }

  @Test("less than one minute returns nil")
  func lessThanOneMinute() {
    #expect(formatDuration(1) == nil)
    #expect(formatDuration(59) == nil)
  }

  @Test("only minutes")
  func onlyMinutes() {
    #expect(formatDuration(5 * 60) == "5 min")
    #expect(formatDuration(30 * 60) == "30 min")
    #expect(formatDuration(59 * 60) == "59 min")
  }

  @Test("hours and minutes")
  func hoursAndMinutes() {
    #expect(formatDuration(3600) == "1 h 0 min")
    #expect(formatDuration(3600 + 30 * 60) == "1 h 30 min")
    #expect(formatDuration(2 * 3600 + 15 * 60) == "2 h 15 min")
  }
}

// MARK: - tripSubtitle

struct TripSubtitleTests {
  @Test("wrong number of parts returns empty string")
  func wrongPartCount() {
    #expect(tripSubtitle([]) == "")
    #expect(tripSubtitle(["a"]) == "")
    #expect(tripSubtitle(["a", "b"]) == "")
    #expect(tripSubtitle(["a", "b", "c", "d"]) == "")
  }

  @Test("short parts produce padded subtitle with arrow")
  func shortParts() {
    let result = tripSubtitle(["A", "ICE 100", "B"])
    #expect(result.contains("A"))
    #expect(result.contains("ICE 100"))
    #expect(result.contains("B"))
    #expect(result.contains("->"))
  }

  @Test("long parts fall back to compact separator")
  func longParts() {
    let long = String(repeating: "X", count: 50)
    let result = tripSubtitle([long, long, long])
    #expect(result.contains("---"))
    #expect(result.contains("-->"))
  }

  @Test("three normal parts: starts and ends with station names")
  func normalThreeParts() {
    let result = tripSubtitle(["Hamburg Hbf", "ICE 777", "Frankfurt Hbf"])
    #expect(result.hasPrefix("Hamburg Hbf"))
    #expect(result.hasSuffix("Frankfurt Hbf"))
  }
}

// MARK: - prep

struct PrepTests {
  @Test("trims surrounding whitespace")
  func trimsWhitespace() {
    #expect(prep("  hello  ") == "hello")
    #expect(prep("\nhello\n") == "hello")
  }

  @Test("replaces umlaut decomposed sequences")
  func umlauts() {
    #expect(prep("u\u{0308}ber") == "über")
    #expect(prep("Ko\u{0308}ln") == "Köln")
    #expect(prep("a\u{0308}") == "ä")
    #expect(prep("U\u{0308}bung") == "Übung")
    #expect(prep("O\u{0308}l") == "Öl")
    #expect(prep("A\u{0308}rger") == "Ärger")
  }

  @Test("replaces other accent sequences")
  func otherAccents() {
    #expect(prep("e\u{0301}") == "é")
    #expect(prep("e\u{0300}") == "è")
    #expect(prep("c\u{0327}") == "ç")
    #expect(prep("n\u{0303}") == "ñ")
    #expect(prep("N\u{0303}") == "Ñ")
  }

  @Test("plain ASCII passes through unchanged")
  func plainAscii() {
    #expect(prep("Berlin") == "Berlin")
    #expect(prep("") == "")
  }
}

// MARK: - Stop

struct StopTests {
  @Test("name derived from O= component in id")
  func nameFromId() {
    let stop = Stop(id: "A=1@O=Hamburg Hbf@X=10006909@Y=53553533@")
    #expect(stop.name == "Hamburg Hbf")
  }

  @Test("explicit name overrides id-derived name")
  func explicitName() {
    let stop = Stop(id: "A=1@O=Hamburg Hbf@", name: "Home")
    #expect(stop.name == "Home")
  }

  @Test("type ST inferred for A=1 id prefix")
  func typeSTFromPrefix() {
    let stop = Stop(id: "A=1@O=Test@")
    #expect(stop.type == "ST")
  }

  @Test("type ADR inferred for other id prefixes")
  func typeADR() {
    let stop = Stop(id: "A=2@O=Some Address@")
    #expect(stop.type == "ADR")
  }

  @Test("explicit type overrides inference")
  func explicitType() {
    let stop = Stop(id: "A=1@O=Test@", type: "ADR")
    #expect(stop.type == "ADR")
  }

  @Test("id without O= component falls back to full id as name")
  func idFallback() {
    let stop = Stop(id: "some-opaque-id")
    #expect(stop.name == "some-opaque-id")
  }

  @Test("equality is based on id only, not name")
  func equalityById() {
    let a = Stop(id: "id1", name: "Stop A")
    let b = Stop(id: "id1", name: "Stop B")
    let c = Stop(id: "id2", name: "Stop A")
    #expect(a == b)
    #expect(a != c)
  }
}

// MARK: - Search

struct SearchTests {
  @Test("default isArrival is false, paging is nil, dateTime is near now")
  func defaults() {
    let before = Date()
    let search = Search(SOID: "S1", ZOID: "Z1")
    let after = Date()
    #expect(search.isArrival == false)
    #expect(search.paging == nil)
    #expect(search.dateTime >= before)
    #expect(search.dateTime <= after.addingTimeInterval(130))
  }

  @Test("equality ignores paging field")
  func equalityIgnoresPaging() {
    let date = Date()
    let a = Search(SOID: "S1", ZOID: "Z1", dateTime: date, paging: "page1")
    let b = Search(SOID: "S1", ZOID: "Z1", dateTime: date, paging: "page2")
    #expect(a == b)
  }

  @Test("inequality on different SOID, ZOID, or dateTime")
  func inequality() {
    let date = Date()
    let base = Search(SOID: "S1", ZOID: "Z1", dateTime: date)
    #expect(base != Search(SOID: "S2", ZOID: "Z1", dateTime: date))
    #expect(base != Search(SOID: "S1", ZOID: "Z2", dateTime: date))
    #expect(base != Search(SOID: "S1", ZOID: "Z1", dateTime: date.addingTimeInterval(3600)))
  }

  @Test("copy overrides specified fields and preserves others")
  func copy() {
    let date = Date()
    let original = Search(SOID: "S1", ZOID: "Z1", dateTime: date, isArrival: false)
    let newDate = date.addingTimeInterval(3600)
    let copied = original.copy(ZOID: "Z2", dateTime: newDate, paging: "p1")
    #expect(copied.SOID == "S1")
    #expect(copied.ZOID == "Z2")
    #expect(copied.dateTime == newDate)
    #expect(copied.isArrival == false)
    #expect(copied.paging == "p1")
  }
}

// MARK: - MyError

struct MyErrorTests {
  @Test("message stored in localizedDescription")
  func storedMessage() {
    let err = MyError("something went wrong")
    #expect(err.localizedDescription == "something went wrong")
  }

  @Test("static factory produces same result as init")
  func factoryMethod() {
    let err = MyError.message("factory error")
    #expect(err.localizedDescription == "factory error")
  }
}

// MARK: - Workflow

struct WorkflowTests {
  @Test("add appends item to items array")
  func addItem() {
    let wf = Workflow()
    #expect(wf.items.isEmpty)
    wf.add(Item(title: "Test"))
    #expect(wf.items.count == 1)
    #expect(wf.items[0].title == "Test")
  }

  @Test("warnEmpty replaces all items with single invalid warning item")
  func warnEmpty() {
    let wf = Workflow()
    wf.add(Item(title: "Existing"))
    wf.warnEmpty("No Results", "Try again")
    #expect(wf.items.count == 1)
    #expect(wf.items[0].title == "No Results")
    #expect(wf.items[0].subtitle == "Try again")
    #expect(wf.items[0].valid == false)
  }
}

// MARK: - Item

struct ItemTests {
  @Test("setMod stores mod under the correct key")
  func setMod() {
    var item = Item(title: "T")
    item.setMod(.cmd, Item.Mod(subtitle: "sub"))
    #expect(item.mods["cmd"]?.subtitle == "sub")
  }

  @Test("setVar stores variable")
  func setVar() {
    var item = Item(title: "T")
    item.setVar("mode", "searchTrips")
    #expect(item.variables["mode"] == "searchTrips")
  }

  @Test("setAction stores string action")
  func setActionString() {
    var item = Item(title: "T")
    item.setAction(.text, .string("hello"))
    guard case let .string(val) = item.action["text"] else {
      Issue.record("Expected string action")
      return
    }
    #expect(val == "hello")
  }

  @Test("setAction stores array action")
  func setActionArray() {
    var item = Item(title: "T")
    item.setAction(.auto, .array(["a", "b"]))
    guard case let .array(val) = item.action["auto"] else {
      Issue.record("Expected array action")
      return
    }
    #expect(val == ["a", "b"])
  }
}

// MARK: - Trip.getTripString

struct TripStringTests {
  private func makeSegment(departure: String, arrival: String) -> Segment {
    Segment(
      departure: Segment.Stop(name: departure, time: Date()),
      arrival: Segment.Stop(name: arrival, time: Date()),
      by: Segment.By(name: "ICE"),
      duration: 0
    )
  }

  @Test("returns first departure and last arrival for multi-segment trip")
  func multiSegment() {
    let seg1 = makeSegment(departure: "Hamburg Hbf", arrival: "Frankfurt Hbf")
    let seg2 = makeSegment(departure: "Frankfurt Hbf", arrival: "München Hbf")
    let trip = Trip(id: "t1", segments: [seg1, seg2], changes: 1, duration: 7200, estDuration: nil, warnings: nil)
    #expect(trip.getTripString() == "Hamburg Hbf → München Hbf")
  }

  @Test("returns departure and arrival for single segment trip")
  func singleSegment() {
    let seg = makeSegment(departure: "Berlin Hbf", arrival: "Hamburg Hbf")
    let trip = Trip(id: "t2", segments: [seg], changes: 0, duration: 5400, estDuration: nil, warnings: nil)
    #expect(trip.getTripString() == "Berlin Hbf → Hamburg Hbf")
  }

  @Test("returns empty string when there are no segments")
  func emptySegments() {
    let trip = Trip(id: "t3", segments: [], changes: 0, duration: 0, estDuration: nil, warnings: nil)
    #expect(trip.getTripString() == "")
  }
}
