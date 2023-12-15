//
//  main.swift
//  bender
//
//  Created by bill donner on 12/14/23.
//


import Foundation
import ArgumentParser
import q20kshare



struct Bender: ParsableCommand {
  
  @Argument(help: "The data files to be merged.")
  var jsonFiles: [String]
  
  @Option(name: .shortAndLong, help: "The name of the output file.")
  var outputFile: String = "merged_output.json"
  
  func run() throws {
    var mergedData: [Challenge] = []
    var dedupedData: [Challenge] = []
    
    for file in jsonFiles {
      if let data = try? Data(contentsOf: URL(fileURLWithPath: file)) {
        let decoder = JSONDecoder()
        //decoder.dateDecodingStrategy = .iso8601
        do{
          //decode and change into challenge format for now
          let myData = try decoder.decode([Challenge].self, from: data)
          //let rewritten = myData.map {$0.makeChallenge()}
          mergedData.append(contentsOf: myData)
        }
        catch {
          print("decoding error \(error)")
        }
      }
    }
    // dedupe phase I = sort by ID then by reverse time
    mergedData.sort(by:) {
      if $0.id < $1.id { return true }
      else if $0.id > $1.id { return false }
      else { // equal id
        return $0.date > $1.date
      }
    }
    var lastid = ""
    // dont copy if same as last id
    for d in mergedData {
      if d.id != lastid {
        dedupedData.append(d)
        lastid = d.id
      }
    }
    // now sort by topic and time
    dedupedData.sort(by:) {
      if $0.topic < $1.topic { return true }
      else if $0.topic > $1.topic { return false }
      else { // equal id
        return $0.date < $1.date
      }
    }
    if dedupedData.count != mergedData.count {
      print("\(mergedData.count - dedupedData.count) duplicates removed")
    }
    // now produce a topic manifest
    struct Entry {
      var topic:String
      var count:Int
    }
    var lasttopic = ""
    var topicitems = 0
    var entries:[Entry] = []
    for d in dedupedData {
      if d.topic != lasttopic {
        if topicitems != 0 {
          entries.append(Entry(topic: lasttopic,count: topicitems))
        }
        lasttopic = d.topic
        topicitems = 1
      } else {
        topicitems += 1
      }
    }
    if topicitems != 0 {
      entries.append(Entry(topic: lasttopic,count: topicitems))
    }
    print("+======TOPICS======+")
    for e in entries {
      print (" \(e.topic)   \(e.count)  ")
    }
    print("+==================+")
    
    let topics =  entries.map {
      Topic(name: $0.topic, subject: $0.topic, per: 1, desired: 1, pic: "pencil", notes: "Notes for \($0.topic)")}
   
    let td = TopicData(snarky:"foofoo",version:"0.0",
                       author:"wld", date: "\(Date())",
                       purpose:"none",topics:topics)
    
    var gamedatum: [GameData] = []
    for t in topics {
      var challenges:[Challenge] = []
      // crude
      for item in dedupedData {
        if item.topic == t.name  {
          challenges.append(item)//.makeChallenge())
        }
      }
      let gda = GameData(topic: t.name, challenges: challenges)
      gamedatum.append(gda)
    }
    
    
    let playdata = PlayData(topicData:td,
                            gameDatum: gamedatum,
                            playDataId: UUID().uuidString,
                            blendDate: Date() )
    
    // write the deduped data
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = .prettyPrinted
    do {
    let outputData = try encoder.encode(playdata)
      let outurl = URL(fileURLWithPath: outputFile)
      try? outputData.write(to: outurl)
      print("Data files merged successfully - \(dedupedData.count) saved to \(outputFile)")
    }
      catch {
       print("Encoding error: \(error)")
      }
  }
}



Bender.main()
