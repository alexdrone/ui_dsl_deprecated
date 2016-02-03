//
//  main.swift
//  Watch
//
//  Created by Alex Usbergo on 16/01/16.
//  Copyright © 2016 Alex Usbergo. All rights reserved.
//

import Foundation

//display the
func __usage() {
    print("✳ usage: ./watch LOCATION")
}

//search for the refl.less files
func __search() -> [String] {
    let args = [String](Process.arguments)
    
    let task = NSTask()
    task.launchPath = "/usr/bin/find"
    task.arguments = ["\(args[1])", "\"*.less\""]
    let pipe = NSPipe()
    task.standardOutput = pipe
    task.launch()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output: String = String(data: data, encoding: NSUTF8StringEncoding)!
    let files = output.componentsSeparatedByString("\n").filter() { return $0.hasSuffix(".less") }
    
    return files
}

//get the timestamps for the files
func __timestamps(files: [String]) -> [String] {
    var timestamps = [String]()
    for file in files {
        
        let task = NSTask()
        task.launchPath = "/usr/bin/stat"
        task.arguments = [file]
        let pipe = NSPipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output: String = String(data: data, encoding: NSUTF8StringEncoding)!
        let timestamp = output.componentsSeparatedByString(" ")[10]
        timestamps.append(timestamp)
    }
    
    return timestamps
}

//make a '__store' directory
func __bundle() {
    let task = NSTask()
    task.launchPath = "/bin/mkdir"
    task.arguments = ["bundle"]
    let pipe = NSPipe()
    task.standardOutput = pipe;
    task.launch()
}

//Copies all the target files to the store directory
func __copy(files: [String]) {
    for file in files {
        let task = NSTask()
        task.launchPath = "/bin/cp"
        task.arguments = ["\(file)", "bundle/"]
        let pipe = NSPipe()
        task.standardOutput = pipe;
        task.launch()
    }
}

//The main refresh routine
func __refresh() -> [String]{
    let files = __search()
    print("✳ Refresh: \(files.count) files.")
    __bundle()
    __copy(files)
    return files
}

struct Watch {
    
    let args: [String]
    let server: HttpServer
    var files: [String]
    var timestamps: [String]
    
    init(args: [String]) {
        self.args = args
        if args.count == 0 {
            __usage()
            exit(EXIT_SUCCESS)
        }
        
        //get the files and the timestamps
        self.files = __refresh()
        self.timestamps = __timestamps(self.files)
        
        //starts the bundle server
        self.server = HttpServer()
        self.server["/bundle/:path"] = HttpHandlers.directory("bundle/")
        try! self.server.start(8081)
    }
    
    //Refreshes the files if the timestamp changed
    mutating func refreshIfNecessary() {
        let ts = __timestamps(self.files)
        var notChanged = true
        for var i = 0; i < ts.count; i++ {
            notChanged = notChanged && (ts[i] == self.timestamps[i])
        }
        //=if notChanged { return }
        
        self.timestamps = ts
        print("✳ Observed files changed")
        self.files = __refresh()
        refreshRequest()
        
    }
    
    //Notify the client of the changes
    func refreshRequest() {
        let address = "http://localhost"
        let port = "8080"
        let url = NSURL(string: "\(address):\(port)/refresh?location=http://localhost:8081/bundle")
        let task = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
            print(response)
        }
        task.resume()
    }
}

//MARK: Main

var watch = Watch(args: [String](Process.arguments))

//idle
while true {
    sleep(5)
    watch.refreshIfNecessary()
}


