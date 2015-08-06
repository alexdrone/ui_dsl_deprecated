//
//  AppearanceManager.swift
//  ReflektorKitSwift
//
//  Created by Alex Usbergo on 05/08/15.
//  Copyright © 2015 Alex Usbergo. All rights reserved.
//

import Foundation

@objc class AppearanceManager {
    
    ///The unique shared appearance manager
    static let sharedManager = AppearanceManager()
    
    struct Stylesheet {
        var rules = [Selector: Rule]()
        var variables = Rule()
    }
    
    ///All the rules parsed from the stylesheet
    var stylesheet = Stylesheet()
    
    ///Loads the stylesheet from the given payload data
    @objc func loadStylesheet(stylesheetData: String) {
        
        let parser = Parser()
        
        do {
            let (all, variables) = try parser.parseStylesheet(stylesheetData)
            
            self.stylesheet.rules = all;
            self.stylesheet.variables = variables;
            
        } catch {
            print("Unable to parse the stylesheet")
        }
        
    }
    
    ///Loads a file and parse the stylesheet from there
    ///All the imports are resolved recursively
    @objc func loadStylesheetFromFile(fileName: String, fileExtension: String = "less", bundle: NSBundle = NSBundle.mainBundle()) {
        
        let parser = Parser()
        do {
            let payload = try parser.loadStylesheetFileAndResolveImports(fileName, fileExtension: fileExtension)
            self.loadStylesheet(payload)
            
        } catch {
            self.loadStylesheet("")
        }
    }
    
    ///Computes all the styles that match the apperance proxy passed as argument
    func computeStyleForApperanceProxy(appearanceProxy: AppearanceProxy) ->  (all: Rule, important: Rule) {
        
        var selectors = [Selector]()
        
        //adds the selector if possible to the array of selectors
        let addSelector = { (selector: Selector) -> () in
            
            if let condition = selector.condition {
                if condition.evaluate(appearanceProxy.view, traitCollection: (appearanceProxy.view?.traitCollection)!, size: UIScreen.mainScreen().bounds.size) {
                    selectors.append(selector)
                }
            } else {
                selectors.append(selector)
            }
        }
        
        //matches the selectors with the view
        for selector in stylesheet.rules.keys {
            
            switch selector.type {
            case .Class(let c) where (appearanceProxy.view?.isKindOfClass(c) != nil): addSelector(selector)
            case .Trait(let t) where appearanceProxy.trait == t: addSelector(selector)
            default: continue
            }
        }
        
        //sorts the selectors accordingly to priority
        selectors.sortInPlace()
        
        var all = Rule()
        var important = Rule()
        
        for selector in selectors {
            
            for keyPath in stylesheet.rules[selector]!.keys {
                
                //adds it to the 'all' collection
                let value = stylesheet.rules[selector]![keyPath]!
                all[keyPath] = value
                
                //adds it to the 'important' collection
                if value.flags.important {
                    important[keyPath] = value
                }
            }
        }

        return (all, important)
    }
    
}