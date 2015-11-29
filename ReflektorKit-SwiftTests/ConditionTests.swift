//
//  ReflektorKit_SwiftTests.swift
//  ReflektorKit-SwiftTests
//
//  Created by Alex Usbergo on 19/07/15.
//  Copyright © 2015 Alex Usbergo. All rights reserved.
//

import XCTest


class CondtionTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testConditions() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        do {
            
            let condition1 = try Condition(rawString: "width = 1 and height < 2")
            XCTAssert(condition1.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 1, height: 1)))
            XCTAssert(!condition1.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 2, height: 1)))
            XCTAssert(!condition1.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize.zero))

            let condition2 = try Condition(rawString: "width ≠ 1")
            XCTAssert(condition2.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 2, height: 1)))
            XCTAssert(!condition2.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 1, height: 1)))
            
            let condition2a = try Condition(rawString: "width != 1")
            XCTAssert(condition2a.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 2, height: 1)))
            XCTAssert(!condition2a.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 1, height: 1)))

            let condition3 = try Condition(rawString: "horizontal ≠ compact")
            XCTAssert(condition3.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Regular), size: CGSize.zero))
            XCTAssert(!condition3.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize.zero))
            
            let condition4 = try Condition(rawString: "horizontal = compact")
            XCTAssert(condition4.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize.zero))
            XCTAssert(!condition4.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Regular), size: CGSize.zero))
            
            let condition5 = try Condition(rawString: "vertical ≠ compact")
            XCTAssert(condition5.evaluate(nil, traitCollection: UITraitCollection(verticalSizeClass: .Regular), size: CGSize.zero))
            XCTAssert(!condition5.evaluate(nil, traitCollection: UITraitCollection(verticalSizeClass: .Compact), size: CGSize.zero))
            
            let condition6 = try Condition(rawString: "horizontal = compact and width ≠ 1")
            XCTAssert(condition6.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 2, height: 1)))
            XCTAssert(!condition6.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 1, height: 1)))
            XCTAssert(!condition6.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Regular), size: CGSize(width: 2, height: 1)))
            
            let condition7 = try Condition(rawString: "width > 1")
            XCTAssert(condition7.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 2, height: 0)))
            XCTAssert(!condition7.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 1, height: 0)))
            
            let condition8 = try Condition(rawString: "width ≥ 1")
            XCTAssert(condition8.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 2, height: 0)))
            XCTAssert(condition8.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 1, height: 0)))
            XCTAssert(!condition8.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 0, height: 0)))
            
            let condition8a = try Condition(rawString: "width >= 1")
            XCTAssert(condition8a.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 2, height: 0)))
            XCTAssert(condition8a.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 1, height: 0)))
            XCTAssert(!condition8a.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 0, height: 0)))
            
            let condition9 = try Condition(rawString: "height ≤ 3")
            XCTAssert(condition9.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 5, height: 3)))
            XCTAssert(condition9.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 5, height: 2)))
            XCTAssert(!condition9.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 5, height: 4)))
            
            let condition9a = try Condition(rawString: "height <= 3")
            XCTAssert(condition9a.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 5, height: 3)))
            XCTAssert(condition9a.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 5, height: 2)))
            XCTAssert(!condition9a.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 5, height: 4)))
            
            let condition10 = try Condition(rawString: "default")
            XCTAssert(condition10.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 5, height: 3)))
            
            //when a condition is ill-formed (such as the following) the evaluation of it is always false
            let condition11 = try Condition(rawString: "horizontal > compact")
            XCTAssert(!condition11.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize.zero))
            XCTAssert(!condition11.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Regular), size: CGSize.zero))
            
            let condition12 = try Condition(rawString: "idiom = phone")
            XCTAssert(condition12.evaluate(nil, traitCollection: UITraitCollection(userInterfaceIdiom: UIUserInterfaceIdiom.Phone), size: CGSize(width: 5, height: 3)))
            XCTAssert(!condition12.evaluate(nil, traitCollection: UITraitCollection(userInterfaceIdiom: UIUserInterfaceIdiom.Pad), size: CGSize(width: 5, height: 3)))
            XCTAssert(!condition12.evaluate(nil, traitCollection: UITraitCollection(userInterfaceIdiom: UIUserInterfaceIdiom.Unspecified), size: CGSize(width: 5, height: 3)))
            
            let condition13 = try Condition(rawString: "idiom != pad")
            XCTAssert(!condition13.evaluate(nil, traitCollection: UITraitCollection(userInterfaceIdiom: UIUserInterfaceIdiom.Pad), size: CGSize(width: 5, height: 3)))
            XCTAssert(condition13.evaluate(nil, traitCollection: UITraitCollection(userInterfaceIdiom: UIUserInterfaceIdiom.Phone), size: CGSize(width: 5, height: 3)))
            XCTAssert(condition13.evaluate(nil, traitCollection: UITraitCollection(userInterfaceIdiom: UIUserInterfaceIdiom.Unspecified), size: CGSize(width: 5, height: 3)))
            
            

        } catch {
            
            XCTAssert(false)
        }
        
        do {
            
            //malformed string
            _ = try Condition(rawString: "foo = 1 and height << 2")
            XCTAssert(false)
            
        } catch {
            
            XCTAssert(true)
        }
        
    }
    
    
    func testExternalConditions() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        do {
            
            Configuration.sharedConfiguration.registerExternalCondition("alwaysFalse", conditionClosure: { (view, traitCollection, size) -> Bool in
                return false
            })
            
            Configuration.sharedConfiguration.registerExternalCondition("alwaysTrue", conditionClosure: { (view, traitCollection, size) -> Bool in
                return true
            })
            
            let condition1 = try Condition(rawString: "?alwaysFalse")
            XCTAssert(!condition1.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 1, height: 1)))

            let condition2 = try Condition(rawString: "?alwaysTrue")
            XCTAssert(condition2.evaluate(nil, traitCollection: UITraitCollection(horizontalSizeClass: .Compact), size: CGSize(width: 1, height: 1)))
            
        } catch {
            
            XCTAssert(false)
        }
        
        do {
            
            //malformed string
            _ = try Condition(rawString: "foo = 1 and height << 2")
            XCTAssert(false)
            
        } catch {
            
            XCTAssert(true)
        }
        
    }
}




