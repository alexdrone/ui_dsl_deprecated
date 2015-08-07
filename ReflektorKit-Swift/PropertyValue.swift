//
//  PropertyValue.swift
//  ReflektorKitSwift
//
//  Created by Alex Usbergo on 21/07/15.
//  Copyright © 2015 Alex Usbergo. All rights reserved.
//

import Foundation

//MARK: Values

struct PropertyValue: Parsable {
    
    //@see Parsable
    let rawString: String
    var flags = (important: Bool, percent: Bool, gradient: Bool, imageAsset: Bool)(false, false, false, false)
    
    //The computed object
    private var object: AnyObject?
    
    //If the property is a single condition which could return 'true' or 'false'
    private var simpleCondition: Condition?;
    
    //If the property value should be parsed and computed by a plugin, the plugin is stored here
    private var associatedPlugin: PropertyValuePlugin?;
    
    init(rawString: String) throws {
        self.rawString = rawString
    
        var mutableRawString = rawString
        
        //check if the value is marked with !important
        if mutableRawString.hasSuffix(Token.Pre.Important.actual) {
            mutableRawString = (mutableRawString as NSString).substringToIndex((mutableRawString as NSString).length - (Token.Pre.Important.actual as NSString).length)
            self.flags.important = true
        }
        
        //keyword
        if let keyword = refl_parseKeyword(mutableRawString) {
            self.object = keyword
            return
        }
        
        //number
        let scanner = NSScanner(string: mutableRawString)
        var numberBuffer: Float = 0
        if scanner.scanFloat(&numberBuffer) {
            self.object = numberBuffer
            self.flags.percent = (rawString as NSString).containsString("%")
            return
        }
        
        //trims the spaces
        mutableRawString = mutableRawString.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        
        //boolean
        if refl_stringHasPrefix(mutableRawString, ["true", "false"]) {
            self.object = mutableRawString.hasPrefix("true")
            return
        }
        
        //string (in quotes)
        if refl_stringHasPrefix(mutableRawString, ["\"", "'"]) {
            self.object = refl_stripQuotesFromString(mutableRawString)
            return
        }
        
        //color
        if refl_stringHasPrefix(mutableRawString, ["rgb", "rgba", "hsl", "hsla", "#"]) {
            self.object = UIColor.refl_colorWithCSSColor(mutableRawString)
            
            if self.object == nil {
                throw ParserError.MalformedRhsValue(error: "Malformed color value: \(mutableRawString)")
            }
            
            return
        }

        guard let args = refl_getArgumentForValue(mutableRawString) else {
            throw ParserError.MalformedRhsValue(error: "The right-hand side '\(mutableRawString)' is malformed")
        }
        
        //font
        if refl_stringHasPrefix(mutableRawString, ["font"]) {
            
            guard let fontName = args[0] as? String, size = args[1].floatValue else {
                throw ParserError.MalformedRhsValue(error: "Malformed font value: \(mutableRawString)")
            }
            
            let strippedFontName = refl_stripQuotesFromString(fontName)
            self.object = UIFont(name: strippedFontName, size: CGFloat(size))
            return
        }
        
        //geometry
        if refl_stringHasPrefix(mutableRawString, ["rect"]) {
            
            guard let x = args[0].doubleValue, y = args[1].doubleValue, width = args[2].doubleValue, height = args[3].doubleValue else {
              throw ParserError.MalformedRhsValue(error: "Malformed rect value: \(mutableRawString)")
            }
            self.object = NSValue(CGRect: CGRect(x: x, y: y, width: width, height: height))
            return
        }
        
        if refl_stringHasPrefix(mutableRawString, ["point"]) {
            
            guard let x = args[0].doubleValue, y = args[1].doubleValue else {
                throw ParserError.MalformedRhsValue(error: "Malformed point value: \(mutableRawString)")
            }
            self.object = NSValue(CGPoint: CGPoint(x: x, y: y))
            return
        }
        
        if refl_stringHasPrefix(mutableRawString, ["size"]) {
            guard let width = args[0].doubleValue, height = args[1].doubleValue else {
                throw ParserError.MalformedRhsValue(error: "Malformed size value: \(mutableRawString)")
            }
            self.object = NSValue(CGSize: CGSize(width: width, height: height))
            return
        }
        
        if refl_stringHasPrefix(mutableRawString, ["edge-insets"]) {
            
            guard let top = args[0].floatValue, left = args[1].floatValue, bottom = args[2].floatValue, right = args[4].floatValue else {
                throw ParserError.MalformedRhsValue(error: "Malformed edge insets value: \(mutableRawString)")
            }
            self.object = NSValue(UIEdgeInsets: UIEdgeInsetsMake(CGFloat(top), CGFloat(left), CGFloat(bottom), CGFloat(right)))
            return
        }
        
        //transformations
        if refl_stringHasPrefix(mutableRawString, ["transform-scale"]) {
            
            guard let x = args[0].floatValue, y = args[1].floatValue else {
                throw ParserError.MalformedRhsValue(error: "Malformed transform scale value: \(mutableRawString)")
            }
            self.object = NSValue(CGAffineTransform: CGAffineTransformMakeScale(CGFloat(x), CGFloat(y)))
            return
        }
        
        if refl_stringHasPrefix(mutableRawString, ["transform-rotate"]) {
            
            guard let angle = args[0].floatValue else {
                throw ParserError.MalformedRhsValue(error: "Malformed transform rotate value: \(mutableRawString)")
            }
            self.object = NSValue(CGAffineTransform: CGAffineTransformMakeRotation(CGFloat(angle)))
            return
        }
        
        if refl_stringHasPrefix(mutableRawString, ["transform-translate"]) {
            
            guard let x = args[0].floatValue, y = args[1].floatValue else {
                throw ParserError.MalformedRhsValue(error: "Malformed transform translate value: \(mutableRawString)")
            }
            self.object = NSValue(CGAffineTransform: CGAffineTransformMakeTranslation(CGFloat(x), CGFloat(y)))
            return
        }
        
        //image
        if refl_stringHasPrefix(mutableRawString, ["image"]) {
            self.object = args[0]
            self.flags.imageAsset = true
            return
        }
        
        //pure condition
        if refl_stringHasPrefix(mutableRawString, ["condition"]) {
            self.simpleCondition = try Condition(rawString: args[0] as! String)
            self.object = nil
            return
        }
        
        //linear gradients
        if refl_stringHasPrefix(mutableRawString, ["linear-gradient"]) {
            
            self.flags.gradient = true
            
            var values = [UIColor]()
            for arg in args {
                
                guard let color = try PropertyValue(rawString: arg as! String).object as? UIColor else {
                    throw ParserError.MalformedRhsValue(error: "The right-hand side '\(mutableRawString)' is malformed")
                }
                values.append(color)
            }
            
            self.object = values
            return
        }
        
        //vector
        if refl_stringHasPrefix(mutableRawString, ["vector"]) {
            
            var values = [AnyObject]()
            for arg in args {
                
                guard let item = try PropertyValue(rawString: arg as! String).object else {
                    throw ParserError.MalformedRhsValue(error: "The right-hand side '\(mutableRawString)' is malformed")
                }
                values.append(item)
            }
            
            self.object = values
            return
        }
        
        //check if any external plugin is registed for this rhs value
        for plugin in Configuration.sharedConfiguration.propertyValuePlugins {
            if plugin.shouldParseValue(rawString) {
                self.associatedPlugin = plugin
                self.object = plugin.parseValue(rawString)
                return
            }
        }
    }
    
    ///Called when the styelesheet proxy is queried for a specific property value
    func computeValue(traitCollection: UITraitCollection, size:CGSize, view: UIView? = nil) -> AnyObject? {
        
        if let plugin = self.associatedPlugin {
            return plugin.computeValueForObject(self.object, traitCollection: traitCollection, size: size, view: view)
        }
        
        //is a pure condition
        if self.simpleCondition != nil {
            return self.simpleCondition?.evaluate(nil, traitCollection: traitCollection, size: size)
        }
        
        var viewSize = size
        if let hostView = view {
            viewSize = hostView.bounds.size
        }
        
        let minBound = Float(min(viewSize.width, viewSize.height))

        // % value
        if self.flags.percent {
            
            //number
            if let numericValue = self.object as? Float {
                return (numericValue/100) * minBound
            
            //font
            } else if let font = self.object as? UIFont {
                return UIFont(name: font.fontName, size: CGFloat((Float(font.pointSize/100)) * minBound))
            }
        
        //linear gradient
        } else if self.flags.gradient {

            guard let colors = self.object as? [UIColor] else {
                return UIColor.blackColor()
            }
            
            return UIColor.gradientFromColor(colors[0], toColor: colors[1], withSize: viewSize)
        
        //image
        } else if self.flags.imageAsset {
            
            if let imageName = self.object as? String  {
                return UIImage(named: imageName)
            }
            
            if let color = self.object as? UIColor {
                return UIImage(color: color, size: viewSize)
            }
            
            if let colors = self.object as? [UIColor] {
                return UIColor.gradientFromColor(colors[0], toColor: colors[1], withSize: viewSize)
            }
            
            return UIImage()
        }
        
        return self.object
    }
}

@objc public protocol PropertyValuePlugin {
    
    ///Should returns 'true' if the rawString passed as argument is a valid input string for this plugin
    @objc func shouldParseValue(rawString: String) -> Bool
    
    ///Parse the string into a value or an itermediate object to be processed when 'computeValueForObject' is called
    @objc func parseValue(rawString: String) -> AnyObject?
    
    ///Called when the styelesheet proxy is queried for a specific property value
    ///::object:: is the previously parsed object that could contains the value or a intermediate representation of it
    @objc func computeValueForObject(object: AnyObject?, traitCollection: UITraitCollection, size: CGSize, view: UIView?) -> AnyObject?
}

//MARK: Properties

struct PropertyKeyPath: Hashable, Parsable {
    
    ///@see Parsable
    let rawString: String
    
    ///!important properties: evaluated at layout time
    var important = false;
    
    var hashValue: Int {
        get {
            return hash(self)
        }
    }
    
    init(rawString: String) throws {
        self.rawString = refl_stringToCamelCase(rawString)
    }
    
    init(keyPath: String) {
        self.rawString = keyPath
    }
    
}



