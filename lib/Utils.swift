import Foundation

func formatDuration(_ seconds: Int) -> String? {
  let hours = seconds / 3600
  let minutes = (seconds % 3600) / 60
  if hours == 0 && minutes == 0 {
    return nil
  }
  return String(format: "%@%d min", hours > 0 ? "\(hours) h " : "", minutes)
}

func tripSubtitle(_ parts: [String]) -> String {
  if parts.count != 3 {
    log("Invalid Subtitle")
    return ""
  }
  let lineLength = 100
  if parts[0].count + parts[1].count + parts[2].count > lineLength - 10 {
    return parts[0] + "  ---  " + parts[1] + "  -->  " + parts[2]
  }
  let x1 = lineLength / 2 - parts[0].count - parts[1].count / 2 - 4
  let x2 = lineLength / 2 - parts[2].count - parts[1].count / 2 - 5
  var subtitle = parts[0] + "  "
  for _ in 0..<x1 {
    subtitle += "-"
  }
  subtitle += "  " + parts[1] + "  "
  for _ in 0..<x2 {
    subtitle += "-"
  }
  subtitle += ">  " + parts[2]
  return subtitle
}

func segmentTitle(_ stop: Segment.Stop) -> String {
  let formatter = DateFormatter()
  formatter.dateFormat = "HH:mm"
  var title = formatter.string(from: stop.time)
  let delay = stop.estTime.flatMap { formatDuration(Int($0.timeIntervalSince(stop.time))) }
  title += delay.flatMap { " (+\($0))" } ?? " "
  title += "\t"
  title += stop.place
  title += stop.platform.flatMap { " (Gl. \($0))" } ?? ""
  return title
}

func segmentSubtitle(_ segment: Segment) -> String {
  var subtitle = ""
  if let duration = formatDuration(segment.duration) {
    subtitle += duration + "\t"
  }
  subtitle += segment.by!.name
  subtitle += segment.by!.direction.flatMap { " (nach \($0))" } ?? ""
  return subtitle
}

func timeTable(_ trip: Trip) -> String {
  /*
  Hamburg Hbf  ->  Saafbrücken Hbf
  ====
  12:28	Hamburg Hbf (Gl. 8)
                  ICE 777
  16:56	Frankfurt(Main)Hbf (Gl. 13)
  ----
  17:26	Frankfurt(Main)Hbf (Gl. 18)
                  RE 3
  20:13	Saafbrücken Hbf
  */
  let formatter = DateFormatter()
  formatter.dateFormat = "HH:mm"

  var table = "\(trip.segments.first!.departure!.place)  →  \(trip.segments.last!.arrival!.place)\n"
  table += "====\n"
  trip.segments.forEach { (segment) in
    if let departure = segment.departure {
      table += "\(formatter.string(from: departure.time))\t\(departure.place)"
      if let platform = departure.platform {
        table += " (Gl. \(platform))\n"
      } else {
        table += "\n"
      }
    }
    if let by = segment.by {
      table += "\t\t\t\t\(by.name)\n"
    }
    if let arrival = segment.arrival {
      table += "\(formatter.string(from: arrival.time))\t\(arrival.place)"
      if let platform = arrival.platform {
        table += " (Gl. \(platform))\n"
      } else {
        table += "\n"
      }
    }
    table += "----\n"
  }
  return table
}

func cacheData(_ key: String, _ data: DataToCache) {
  if let cacheDir = env["alfred_workflow_cache"] {
    let url = URL(fileURLWithPath: cacheDir).appendingPathComponent(key)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try! encoder.encode(data)
    do {
      try data.write(to: url)
    } catch {
      log("Error writing to file \(url.path): \(error.localizedDescription)\n".data(using: .utf8)!)
    }
  } else {
    log("cacheDir not set\n".data(using: .utf8)!)
  }
}

func cachedData(_ key: String) -> DataToCache? {
  let fileManager = FileManager.default
  if let cacheDir = env["alfred_workflow_cache"] {
    let url = URL(fileURLWithPath: cacheDir).appendingPathComponent(key)
    if fileManager.fileExists(atPath: url.path) {
      do {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? decoder.decode(DataToCache.self, from: data) else {
          log("Error decoding data from file \(url.path)\n".data(using: .utf8)!)
          return nil
        }
        return data
      } catch {
        log("Error reading from file \(url.path)\n".data(using: .utf8)!)
        return nil
      }
    } else {
      log("File not found at path \(url.path)\n".data(using: .utf8)!)
      return nil
    }
  } else {
    log("cacheDir not set\n".data(using: .utf8)!)
    return nil
  }
}

func notify(_ message: String, title: String = "Fahrplan", subtitle: String = "") {
  let task = Process()
  task.launchPath = "/opt/homebrew/bin/terminal-notifier"
  task.arguments = ["-title", title, "-subtitle", subtitle, "-message", message, "-sender", "com.runningwithcrayons.Alfred", "-contentImage", "./icon.png"]
  task.launch()
}
