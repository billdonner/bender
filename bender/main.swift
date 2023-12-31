//
//  main.swift
//  bender
//
//  Created by bill donner on 12/14/23.
//


import Foundation
import ArgumentParser
import q20kshare

func fetchTopicData(_ tdurl:String ) throws -> TopicData {
  // Load substitutions JSON file,throw out all of the metadata for now
  let xdata = try Data(contentsOf: URL(fileURLWithPath: tdurl))
  let decoded = try JSONDecoder().decode(TopicData.self, from:xdata)
  return decoded
}

struct Bender: ParsableCommand {
  
  static let configuration = CommandConfiguration(
    abstract: "Bender Builds The Files Needed By QANDA Mobile App",
    version: "0.1.4",
    subcommands: [],
    defaultSubcommand: nil,
    helpNames: [.long, .short]
  )
  
  @Argument(help: "The data files to be merged.")
  var jsonFiles: [String]
  
  @Option(name: .shortAndLong, help: "The name of the output file.")
  var outputFile: String = "merged_output.json"
  
  @Option(name: .shortAndLong, help: "The name of the topics data file .")
  var tdPath: String = "TopicData.json"
  
  func run() throws {
    var mergedData: [Challenge] = []
    var dedupedData: [Challenge] = []
    let topicData = try fetchTopicData(tdPath)
    let tdblocks = topicData.topics
    
    for file in jsonFiles {
      if let data = try? Data(contentsOf: URL(fileURLWithPath: file)) {
        print(">Processing \(file)\n")
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
          return
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
      var pic = "pencil"
      var notes = ""
      for td in tdblocks {
        if $0.topic == td.name { pic = td.pic ; notes = td.notes; break}
      }
      return Topic(name: $0.topic, subject: $0.topic, pic:pic,   notes: "Notes for \(notes)")
    }
   
    let rewrittenTd = TopicData(description:topicData.description,version:topicData.version,
                       author:topicData.author, date: "\(Date())",
                       purpose:topicData.purpose,topics:topics)
    
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
    
    
    let playdata = PlayData(topicData:rewrittenTd,
                            gameDatum: gamedatum,
                            playDataId: UUID().uuidString,
                            blendDate: Date() )
    
    // write the deduped data
    let encoder = JSONEncoder()
   // encoder.dateEncodingStrategy = .iso8601
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
