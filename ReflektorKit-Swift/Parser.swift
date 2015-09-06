//
//  Parser.swift
//  ReflektorKitSwift
//
//  Created by Alex Usbergo on 19/07/15.
//  Copyright © 2015 Alex Usbergo. All rights reserved.
//

import Foundation

typealias Rule = [PropertyKeyPath: PropertyValue]

//MARK: Tokens

struct Token {
    
    struct Pre {
        static let Variable = (pre: "@", actual: "-reflektor-variable-")
        static let Important = (pre:"!important", actual:"-reflektor-important")
    }

    struct Directive {
        static let Condition = "condition"
        static let Where = "__where"
        static let WhereSimple = "where"
        static let Include = "include"
        static let AppliesToSubclasses = "applies-to-subclasses"
    }
    
    struct Separator {
        static let Standard = ","
        static let Condition = "and"
        static let Selector = ":"
    }
}

//MARK: Parser

enum ParserError: ErrorType {
    case MalformedStylesheet(error: String)
    case MalformedSelector(error: String)
    case MalformedCondition(error: String)
    case MalformedRhsValue(error: String)
}

///The object that performs the parsing of the ReflektorKit stylesheet.
///ReflektorKit is based on a dialect of LESS. See LESSParser.m.
struct Parser {

    func parseStylesheet(stylesheet: String) throws -> ([Selector: Rule], Rule) {
                
        var payload = stylesheet
        
        //pre-process the stylesheet
        payload = payload.stringByReplacingOccurrencesOfString(Token.Pre.Variable.pre, withString: Token.Pre.Variable.actual)
        payload = payload.stringByReplacingOccurrencesOfString(Token.Pre.Important.pre, withString: Token.Pre.Important.actual)

        while let match = payload.rangeOfString("\(Token.Separator.Selector)\(Token.Directive.Where)\\s", options: .RegularExpressionSearch) {
            payload.replaceRange(match, with: "\(Token.Separator.Selector)\(Token.Directive.Where)_\(refl_uuid()) ")
        }
        
        
        //parse
        let parser = LESSParser()
        let parsedPayload = parser.parseText(payload) as? [String : [String: AnyObject]]
        
        guard let _ = parsedPayload else {
            throw ParserError.MalformedStylesheet(error: "Unable to parse the LESS stylesheet")
        }
        
        var dictionary = parsedPayload!
        
        //flatten the inclusions
        for key in dictionary.keys {
            try self.recursivelyResolveInclusions(key, dictionary:&dictionary)
        }
        
        //resolve the variables
        try self.resolveVariables(&dictionary)
        
        var result = [Selector: [PropertyKeyPath: PropertyValue]]()
        for selectorString in dictionary.keys {
            
            var nestedDictionary = dictionary[selectorString]!
            
            //creates the selector with the condition if necessary
            var selector = try Selector(rawString: selectorString)
            if let conditionString = nestedDictionary[Token.Directive.Condition] {
                do {
                    selector.condition = try Condition(rawString: conditionString as! String)
                    nestedDictionary.removeValueForKey(Token.Directive.Condition)
                } catch {
                    assert(false, "malformed condition")
                }
            }
            
            var rules = [PropertyKeyPath: PropertyValue]()
            
            //creates the keypath and the value
            for propertyString in nestedDictionary.keys {
                let keyPath = try PropertyKeyPath(rawString: propertyString)
                let value = try PropertyValue(rawString: nestedDictionary[propertyString] as! String)
                rules[keyPath] = value
            }
            
            result[selector] = rules
        }
        
        //group the variables together
        var variables = [PropertyKeyPath: PropertyValue]()
        
        for selector in result.keys {
            if selector.rawString.hasPrefix(Token.Pre.Variable.actual) {
                let rules = result[selector]!
                for key in rules.keys {
                    variables[key] = rules[key]
                }
                
            }
        }
        
        return (result, variables)
    }
    
    //MARK: Imports
    
    func loadStylesheetFileAndResolveImports(fileName: String, fileExtension: String, bundle: NSBundle = NSBundle.mainBundle()) throws -> String {
        
        if let path = bundle.pathForResource(fileName, ofType: fileExtension) {
            
            //loads the file
            var file = try String(contentsOfFile: path, encoding: NSUTF8StringEncoding)
            
            while let match = file.rangeOfString("@import(\\s*)url\\(\"(\\w*.\\w*)\"\\);", options: .RegularExpressionSearch) {
                
                //get the filename of the imported file
                var importString = file.componentsSeparatedByString("\"")[1]
                importString = importString.componentsSeparatedByString("\"")[0]
                
                let importedFileName = importString.componentsSeparatedByString(".")[0]
                let importedExtension = importString.componentsSeparatedByString(".")[1]
                
                file.removeRange(match)
                
                //recursively reads the imported file
                let importedPayload = try self.loadStylesheetFileAndResolveImports(importedFileName, fileExtension: importedExtension, bundle: bundle)
                
                file = "\(importedPayload)\n\(file)"
            }
            
            return file
        }
        
        return ""
    }

    
    //MARK: Private
    
    private func recursivelyResolveInclusions(selector: String, inout dictionary:[String : [String: AnyObject]]) throws {
        
        let key = refl_stripQuotesFromString(selector)
        
        guard var rules = dictionary[key] else {
            return
        }

        //it doesn't contain a include directive
        guard let includeString = dictionary[key]?[Token.Directive.Include] else {
            return
        }
        
        guard let includeComponents = includeString.componentsSeparatedByString(Token.Separator.Standard) as [String]? else {
            throw ParserError.MalformedStylesheet(error: "The include directive for \(key) is malformed")
        }
        
        //recursive calls
        for includedKey in includeComponents {
            try self.recursivelyResolveInclusions(includedKey, dictionary:&dictionary)
        }
        
        rules.removeValueForKey(Token.Directive.Include)
        
        //merge the rules
        for includedKey in includeComponents {
            for rule in  dictionary[includedKey]!.keys {
                
                if rules[rule] == nil {
                   rules[rule] = dictionary[includedKey]![rule]!
                }
            }
        }
        
        dictionary[selector] = rules
    }
    
    private func resolveVariables(inout dictionary:[String : [String: AnyObject]]) throws {
        
        //this array will contain all the variables
        var variables = [String: AnyObject]()
        
        //retrieve the variables
        for selector in dictionary.keys {
            
            if refl_stringHasPrefix(selector, [Token.Pre.Variable.actual]) {
                
                for variable in dictionary[selector]!.keys {
                    variables[variable] = dictionary[selector]![variable]
                }
            }
        }
        
        let sortedKeys = refl_prefixedOrderedKeys(Array(variables.keys)) as! [String]
        
        //resolve the variables
        for selector in dictionary.keys {
            for rule in dictionary[selector]!.keys {
                
                guard var string = dictionary[selector]![rule] else {
                    throw ParserError.MalformedStylesheet(error: "The body for the rule \(rule) seems to be invalid")
                }
                
                for variable in sortedKeys {
                    string = string.stringByReplacingOccurrencesOfString(variable, withString: variables[variable] as! String)
                }
                
                dictionary[selector]![rule] = string
            }
        }
        
        //finally remove all the variable prefixes
        for selector in dictionary.keys {
            
            if refl_stringHasPrefix(selector, [Token.Pre.Variable.actual]) {
                for variable in sortedKeys {
                    
                    let cleanedVariableName = variable.stringByReplacingOccurrencesOfString(Token.Pre.Variable.actual, withString: "")
                    dictionary[selector]![cleanedVariableName] = dictionary[selector]![variable]
                    dictionary[selector]!.removeValueForKey(variable)
                }
            }
        }
        
    }
    
    //MARK: Utilities
    
    internal static func normalizeExpressionString(string: String, forceLowerCase: Bool = true) -> String {
        
        var ps = refl_stripQuotesFromString(string.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()))
        
        if forceLowerCase {
            ps = ps.lowercaseString
        }
        
        ps = ps.stringByReplacingOccurrencesOfString("\"", withString: "")
        ps = ps.stringByReplacingOccurrencesOfString("'", withString: "")
        ps = ps.stringByReplacingOccurrencesOfString("!=", withString: Condition.ExpressionToken.Operator.NotEqual.rawValue)
        ps = ps.stringByReplacingOccurrencesOfString("<=", withString: Condition.ExpressionToken.Operator.LessThanOrEqual.rawValue)
        ps = ps.stringByReplacingOccurrencesOfString(">=", withString: Condition.ExpressionToken.Operator.GreaterThanOrEqual.rawValue)
        ps = ps.stringByReplacingOccurrencesOfString("==", withString: Condition.ExpressionToken.Operator.Equal.rawValue)
        ps = ps.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        
        return ps
    }
    
}


