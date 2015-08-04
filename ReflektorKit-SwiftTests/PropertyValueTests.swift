//
//  PropertyValueTests.swift
//  ReflektorKitSwift
//
//  Created by Alex Usbergo on 04/08/15.
//  Copyright © 2015 Alex Usbergo. All rights reserved.
//

import XCTest
import UIKit

class PropertyValueTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testNumber()  {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        do {
            let view = UIView()
            let property = try PropertyValue(rawString: "0.5")
            let value = property.computeValue(view.traitCollection, size: view.bounds.size) as! Float
            XCTAssert(value == 0.5)
            view.setValue(value, forKey: "alpha")
            XCTAssert(view.alpha == 0.5)

        } catch {
            XCTAssert(false)
        }
    }
    
    func testNumberPx()  {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        do {
            let view = UIView()
            let property = try PropertyValue(rawString: "10px")
            let value = property.computeValue(view.traitCollection, size: view.bounds.size) as! Float
            XCTAssert(value == 10)
            
        } catch {
            XCTAssert(false)
        }
    }
    
    func testNumberPt()  {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        do {
            let view = UIView()
            let property = try PropertyValue(rawString: "10pt")
            let value = property.computeValue(view.traitCollection, size: view.bounds.size) as! Float
            XCTAssert(value == 10)
            
        } catch {
            XCTAssert(false)
        }
    }
    
    func testNumberPercent()  {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        do {
            let view = UIView(frame: CGRectMake(0, 0, 200, 200))
            let property = try PropertyValue(rawString: "10%")
            let value = property.computeValue(view.traitCollection, size: view.bounds.size) as! Float
            XCTAssert(value == 20)
            
        } catch {
            XCTAssert(false)
        }
    }
    
    
    func testString()  {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        do {
            let view = UIView()
            let property = try PropertyValue(rawString: "'Foo bar'")
            let value = property.computeValue(view.traitCollection, size: view.bounds.size) as! String
            XCTAssert(value == "Foo bar")
            
        } catch {
            XCTAssert(false)
        }
    }

    func testRgbColor()  {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        do {
            let view = UIView()
            let property = try PropertyValue(rawString: "rgb(255,255,255)")
            let value = property.computeValue(view.traitCollection, size: view.bounds.size) as! UIColor
            XCTAssert(value == UIColor(colorLiteralRed: 1, green: 1, blue: 1, alpha: 1))
            view.setValue(value, forKey: "backgroundColor")
            XCTAssert(view.backgroundColor == UIColor(colorLiteralRed: 1, green: 1, blue: 1, alpha: 1))
            
        } catch {
            XCTAssert(false)
        }
    }
    
    func testRgbaColor()  {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        do {
            let view = UIView()
            let property = try PropertyValue(rawString: "rgba(255,255,255,1)")
            let value = property.computeValue(view.traitCollection, size: view.bounds.size) as! UIColor
            XCTAssert(value == UIColor(colorLiteralRed: 1, green: 1, blue: 1, alpha: 1))
            view.setValue(value, forKey: "backgroundColor")
            XCTAssert(view.backgroundColor == UIColor(colorLiteralRed: 1, green: 1, blue: 1, alpha: 1))
            
        } catch {
            XCTAssert(false)
        }
    }

    func testHexColor()  {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        do {
            let view = UIView()
            let property = try PropertyValue(rawString: "#ffffff")
            let value = property.computeValue(view.traitCollection, size: view.bounds.size) as! UIColor
            XCTAssert(value == UIColor(colorLiteralRed: 1, green: 1, blue: 1, alpha: 1))
            view.setValue(value, forKey: "backgroundColor")
            XCTAssert(view.backgroundColor == UIColor(colorLiteralRed: 1, green: 1, blue: 1, alpha: 1))
            
        } catch {
            XCTAssert(false)
        }
    }
    
    func testHexInvertedColor()  {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        do {
            let view = UIView()
            let property = try PropertyValue(rawString: "#000000")
            let value = property.computeValue(view.traitCollection, size: view.bounds.size) as! UIColor
            XCTAssert(value == UIColor(colorLiteralRed: 0, green: 0, blue: 0, alpha: 1))
            view.setValue(value, forKey: "backgroundColor")
            XCTAssert(view.backgroundColor == UIColor(colorLiteralRed: 0, green: 0, blue: 0, alpha: 1))
            
        } catch {
            XCTAssert(false)
        }
    }
    
    func testRect()  {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        do {
            let view = UIView()
            let property = try PropertyValue(rawString: "rect(1px,2px,3px,4px)")
            let value = property.computeValue(view.traitCollection, size: view.bounds.size) as! NSValue
            XCTAssert(value.CGRectValue() == CGRect(x: 1, y: 2, width: 3, height: 4))
            view.setValue(value, forKey: "frame")
            XCTAssert(view.frame == CGRect(x: 1, y: 2, width: 3, height: 4))
            
        } catch {
            XCTAssert(false)
        }
    }
    
    func testSize()  {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        do {
            let view = UIView()
            let property = try PropertyValue(rawString: "size(1px,2px)")
            let value = property.computeValue(view.traitCollection, size: view.bounds.size) as! NSValue
            XCTAssert(value.CGSizeValue() == CGSize(width: 1, height: 2))
        } catch {
            XCTAssert(false)
        }
    }
    
    func testPoint()  {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        do {
            let view = UIView()
            let property = try PropertyValue(rawString: "point(1px,2px)")
            let value = property.computeValue(view.traitCollection, size: view.bounds.size) as! NSValue
            XCTAssert(value.CGPointValue() == CGPoint(x: 1, y: 2))
            view.setValue(value, forKey: "center")
            XCTAssert(view.center == CGPoint(x: 1, y: 2))
        } catch {
            XCTAssert(false)
        }
    }
    
    func testGradient()  {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        do {
            let view = UIView(frame: CGRectMake(0, 0, 200, 200))
            let property = try PropertyValue(rawString: "linear-gradient(#000000, #ffffff)")
            let value = property.computeValue(view.traitCollection, size: view.bounds.size)
            XCTAssert(value != nil)
        } catch {
            XCTAssert(false)
        }
    }
    
    func testFont()  {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        do {
            let view = UILabel()
            let property = try PropertyValue(rawString: "font('Helvetica', 12pt)")
            let value = property.computeValue(view.traitCollection, size: view.bounds.size) as! UIFont
            XCTAssert(value == UIFont(name: "Helvetica", size: 12))
            view.setValue(value, forKey: "font")
            XCTAssert(view.font == UIFont(name: "Helvetica", size: 12))
        } catch {
            XCTAssert(false)
        }
    }


}
