//
//  ReflektorKit_SwiftTests.swift
//  ReflektorKit-SwiftTests
//
//  Created by Alex Usbergo on 19/07/15.
//  Copyright © 2015 Alex Usbergo. All rights reserved.
//

import XCTest


class SelectorTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSelectorsInitialisation() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        do {
            

            let s1 = try Selector(rawString: "UIView")
            XCTAssert(s1.type == SelectorType.Class(viewClass: NSClassFromString("UIView")!))
            XCTAssert(s1.type != SelectorType.Class(viewClass: NSClassFromString("UIButton")!))
            XCTAssert(s1.type ~= SelectorType.Class(viewClass: NSClassFromString("UIButton")!))
            XCTAssert(!(s1.type ~= SelectorType.Trait(trait: "aTrait")))
            XCTAssert(s1.type != SelectorType.Trait(trait: "aTrait"))
            XCTAssert(s1.additionalTrait == nil)
            XCTAssert(s1.condition == nil)

            let s2 = try Selector(rawString: "aTrait")
            XCTAssert(s2.type != SelectorType.Class(viewClass: NSClassFromString("UIView")!))
            XCTAssert(s2.type != SelectorType.Class(viewClass: NSClassFromString("UIButton")!))
            XCTAssert(!(s2.type ~= SelectorType.Class(viewClass: NSClassFromString("UIButton")!)))
            XCTAssert(!(s2.type ~= SelectorType.Class(viewClass: NSClassFromString("UIButton")!)))
            XCTAssert(s2.type == SelectorType.Trait(trait: "aTrait"))
            XCTAssert(s2.type ~= SelectorType.Trait(trait: ""))
            XCTAssert(s2.additionalTrait == nil)
            XCTAssert(s2.condition == nil)

            let s3 = try Selector(rawString: "UIView:aTrait")
            XCTAssert(s3.type == SelectorType.Class(viewClass: NSClassFromString("UIView")!))
            XCTAssert(s3.type != SelectorType.Class(viewClass: NSClassFromString("UIButton")!))
            XCTAssert(s3.type ~= SelectorType.Class(viewClass: NSClassFromString("UIButton")!))
            XCTAssert(!(s3.type ~= SelectorType.Trait(trait: "aTrait")))
            XCTAssert(s3.type != SelectorType.Trait(trait: "aTrait"))
            XCTAssert(s3.additionalTrait == "aTrait")
            XCTAssert(s3.condition == nil)
            
            let s4 = try Selector(rawString: "UIView:__where")
            XCTAssert(s4.type == SelectorType.Class(viewClass: NSClassFromString("UIView")!))
            XCTAssert(s4.type != SelectorType.Class(viewClass: NSClassFromString("UIButton")!))
            XCTAssert(s4.type ~= SelectorType.Class(viewClass: NSClassFromString("UIButton")!))
            XCTAssert(!(s4.type ~= SelectorType.Trait(trait: "aTrait")))
            XCTAssert(s4.type != SelectorType.Trait(trait: "aTrait"))
            XCTAssert(s4.additionalTrait == nil)
            XCTAssert(s4.condition == nil)

        } catch {
            
            XCTAssert(false)
        }
        
    }
    
    func testSelectorsPriority() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        do {
            
            var s0 = try Selector(rawString: "UIView:aTrait")
            s0.condition = try Condition(rawString: "vertical = regular")
            
            var s1 = try Selector(rawString: "UIView")
            s1.condition = try Condition(rawString: "vertical = regular")
            
            let s2 = try Selector(rawString: "UIView:aTrait")
            
            let s3 = try Selector(rawString: "UIView")
            
            var s4 = try Selector(rawString: "aTrait")
            s4.condition = try Condition(rawString: "vertical = regular")
            
            let s5 = try Selector(rawString: "aTrait")
            
            XCTAssert(s4 > s0)

            XCTAssert(s0 > s1)
            XCTAssert(s0 > s2)
            XCTAssert(s0 > s3)
            XCTAssert(s0 > s5)
            
            XCTAssert(s1 < s0)
            XCTAssert(s1 > s2)
            XCTAssert(s1 > s3)
            XCTAssert(s1 > s5)
            
        } catch {
            
            XCTAssert(false)
        }
        

        
    }

}




