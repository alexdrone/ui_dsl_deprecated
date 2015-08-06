//
//  ParserTests.swift
//  ReflektorKitSwift
//
//  Created by Alex Usbergo on 05/08/15.
//  Copyright © 2015 Alex Usbergo. All rights reserved.
//

import XCTest


class ParserTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testVariableReplacement() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        do {
            let parser = Parser()
            let result = try parser.loadStylesheetFileAndResolveImports("main", fileExtension: "less", bundle: NSBundle(forClass: ParserTests.self))
            print(result)
            
        } catch {
            XCTAssert(false)
        }
        
        
    }



}
