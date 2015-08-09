//
//  ParsedItems.swift
//  ReflektorKitSwift
//
//  Created by Alex Usbergo on 20/07/15.
//  Copyright © 2015 Alex Usbergo. All rights reserved.
//

import Foundation

//MARK: Equatable compliancy

func ==<T:Parsable>(lhs: T, rhs: T) -> Bool {
    return lhs.rawString == rhs.rawString
}

func ==(lhs: SelectorType, rhs: SelectorType) -> Bool {
    
    switch (lhs, rhs) {
    case (.Class(let a), .Class(let b)) where a == b: return true
    case (.Trait(let a), .Trait(let b)) where a == b: return true
    case (.Scope(let a), .Scope(let b)) where a == b: return true
    default: return false
    }
}

func ~=(lhs: SelectorType, rhs: SelectorType) -> Bool {
    
    switch (lhs, rhs) {
    case (.Class(_), .Class(_)): return true
    case (.Trait(_), .Trait(_)): return true
    case (.Scope(_), .Scope(_)): return true
    default: return false
    }
}

func hash<T:Parsable>(item: T) -> Int {
    return item.rawString.hashValue;
}

protocol Parsable: Equatable {
    
    //the original string that originated this parsed item
    var rawString: String { get }
    
    init(rawString: String) throws
}

//MARK: Selector

func <(lhs: Selector, rhs: Selector) -> Bool {
    return lhs.priority < rhs.priority
}

func <=(lhs: Selector, rhs: Selector) -> Bool {
    return lhs.priority <= rhs.priority
}

func >(lhs: Selector, rhs: Selector) -> Bool {
    return lhs.priority > rhs.priority
}

func >=(lhs: Selector, rhs: Selector) -> Bool {
    return lhs.priority >= lhs.priority
}

enum SelectorType: Equatable {
    case Class(viewClass: AnyClass)
    case Trait(trait: String)
    case Scope(scope: String)
}

struct Selector: Hashable, Parsable, Comparable {
    
    ///@see Parsable
    let rawString: String
    let type: SelectorType
    var additionalTrait: String?
    var condition: Condition?
    
    //Hashable compliancy
    var hashValue: Int {
        get {
            return hash(self)
        }
    }
    
    var priority: Int {
        get {
            switch self.type {
                case .Trait(_) where self.condition != nil: return 100
                case .Class(_) where self.additionalTrait != nil && self.condition != nil: return 99
                case .Class(_) where self.condition != nil: return 95
                case .Class(_) where self.additionalTrait != nil: return 75
                case .Trait(_): return 70
                case .Class(_): return 50
                default: return 1
            }
        }
    }
    
    //Initialise the selector object from a well-formed stylesheet selector (e.g. Class:trait)
    init(rawString: String) throws {
        
        self.rawString = rawString
        let components = self.rawString.componentsSeparatedByString(Token.Separator.Selector)
        
        guard let head = components.first else {
            throw ParserError.MalformedSelector(error: "Unable to get the first component of the selector")
        }
        
        if let viewClass = NSClassFromString(head) {
            self.type = .Class(viewClass: viewClass)
            
        } else if refl_stringHasPrefix(head, [Token.Pre.Variable.actual]) {
            self.type = .Scope(scope: head.stringByReplacingOccurrencesOfString(Token.Pre.Variable.actual, withString: ""))
            
        } else {
            self.type = .Trait(trait: head)
            self.additionalTrait = head
        }
        
        self.additionalTrait = nil
        if components.count == 1 {
            return
        }
        
        switch (self.type) {
            
        case .Class(_):
            if !refl_stringHasPrefix(components[1], ["\(Token.Directive.Where)"]) && !refl_stringHasPrefix(components[1], [Token.Directive.WhereSimple]) {
                self.additionalTrait = components[1]
            }
            
        default:
            throw ParserError.MalformedSelector(error: "Only Class type selectors are allowed to be compound selectors")
        }
    }
    
}


