//
//  Condition.swift
//  ReflektorKitSwift
//
//  Created by Alex Usbergo on 20/07/15.
//  Copyright © 2015 Alex Usbergo. All rights reserved.
//

import Foundation

public typealias ExternalConditionClosure = (view: UIView?, traitCollection: UITraitCollection, size: CGSize) -> Bool

struct ExpressionToken {
    
    enum Default: String {
        case Default = "default"
        case External = "?"
    }
    
    enum Lhs: String {
        case Horizontal = "horizontal"
        case Vertical = "vertical"
        case Width = "width"
        case Height = "height"
        case Idiom = "idiom"
        case Unspecified = "unspecified"
    }
    
    enum Operator: String {
        case Equal = "="
        case NotEqual = "≠"
        case LessThan = "<"
        case LessThanOrEqual = "≤"
        case GreaterThan = ">"
        case GreaterThanOrEqual = "≥"
        case Unspecified = "unspecified"
        
        
        static func all() -> [Operator] {
            return [Equal, NotEqual, LessThan, LessThanOrEqual, GreaterThan, GreaterThanOrEqual]
        }
        
        static func allRaw() -> [String] {
            return [Equal.rawValue, NotEqual.rawValue, LessThan.rawValue, LessThanOrEqual.rawValue, GreaterThan.rawValue, GreaterThanOrEqual.rawValue]
        }
        
        static func characterSet() -> NSCharacterSet {
            return NSCharacterSet(charactersInString: "".join(self.allRaw()))
        }
        
        static func operatorContainedInString(string: String) -> Operator {
            for opr in self.all() {
                if string.rangeOfString(opr.rawValue) != nil {
                    return opr
                }
            }
            return Unspecified
        }
        
        func equal<T:Equatable>(lhs: T, rhs: T) -> Bool {
            switch self {
                case .Equal: return lhs == rhs
                case .NotEqual: return lhs != rhs
                default: return false
            }
        }
        
        func compare<T:Comparable>(lhs: T, rhs: T) -> Bool {
            switch self {
            case .Equal: return lhs == rhs
            case .NotEqual: return lhs != rhs
            case .LessThan: return lhs < rhs
            case .LessThanOrEqual: return lhs <= rhs
            case .GreaterThan: return lhs > rhs
            case .GreaterThanOrEqual: return lhs >= rhs
            default: return false
            }
        }

    }
    
    enum Rhs: String {
        case Regular = "regular"
        case Compact = "compact"
        case Pad = "pad"
        case Phone = "phone"
        case Constant = "_"
        case Unspecified = "unspecified"
        
        func toUserInterfaceSizeClass() -> UIUserInterfaceSizeClass {
            switch self {
                case .Regular: return UIUserInterfaceSizeClass.Regular
                case .Compact: return UIUserInterfaceSizeClass.Compact
                default: return UIUserInterfaceSizeClass.Unspecified
            }
        }
        
        func toUserInterfaceIdiom() -> UIUserInterfaceIdiom {
            switch self {
                case .Pad: return UIUserInterfaceIdiom.Pad
                case .Phone: return UIUserInterfaceIdiom.Phone
                default: return UIUserInterfaceIdiom.Unspecified
            }
        }
    }
    
}

struct Expression: Hashable, Parsable {
    
    ///@see Parsable
    let rawString: String
    
    ///Wether this expression is always true or not
    private let tautology: Bool
    
    ///The actual parsed expression
    private let expression: (ExpressionToken.Lhs, ExpressionToken.Operator, ExpressionToken.Rhs, Float)
    
    ///Wether the expression is a custom external condition
    private var externalCondition: ExternalConditionClosure?
    
    //Hashable compliancy
    var hashValue: Int {
        get {
            return hash(self) 
        }
    }
    
    init(rawString: String) throws {
    
        self.rawString = sanitizeConditionString(rawString)
        
        //check for default expression
        if self.rawString.rangeOfString(ExpressionToken.Default.Default.rawValue) != nil {
            
            self.expression = (.Unspecified, .Unspecified, .Unspecified, 0)
            self.tautology = true

        //external expression (custom keys)
        } else if self.rawString.hasPrefix(ExpressionToken.Default.External.rawValue) {
            
            self.expression = (.Unspecified, .Unspecified, .Unspecified, 0)
            let externalKey = (rawString as NSString).substringFromIndex((ExpressionToken.Default.External.rawValue as NSString).length)

            if let closure = Configuration.sharedConfiguration.externalConditions[externalKey] {
                self.externalCondition = closure
                self.tautology = false

            } else {
                self.tautology = true
            }
            
        //expression
        } else {
            
            self.tautology = false
            var terms = self.rawString.componentsSeparatedByCharactersInSet(ExpressionToken.Operator.characterSet())
            let opr = ExpressionToken.Operator.operatorContainedInString(self.rawString)
            
            if terms.count != 2 || opr == ExpressionToken.Operator.Unspecified {
                throw ParserError.MalformedCondition(error: "No valid operator found in the string")
            }
            
            terms = terms.map({
                return $0.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
            })
            
            //initialise the
            let constant: Float
            let hasConstant: Bool
            
            if let c = Float(terms[1]) {
                constant = c
                hasConstant = true
                
            } else {
                constant = Float.NaN
                hasConstant = false
            }
            
            guard   let lhs = ExpressionToken.Lhs(rawValue: terms[0]),
                    let rhs = hasConstant ? ExpressionToken.Rhs.Constant : ExpressionToken.Rhs(rawValue: terms[1]) else {
                    
                throw ParserError.MalformedCondition(error: "The terms of the condition are not valid")
            }

            self.expression = (lhs, opr, rhs, constant)
        }
    }
    
    ///Check if a condition is valid given the trait collection and the size passed as argument
    func evaluate(view: UIView?, traitCollection: UITraitCollection, size: CGSize) -> Bool {

        //case default
        if self.tautology {
            return true
        }
        
        //case custom external condition
        if let externalCondition = self.externalCondition {
            return externalCondition(view: view, traitCollection: traitCollection, size: size)
        }

        switch self.expression.0 {
            
            case .Horizontal:
                return self.expression.1.equal(traitCollection.horizontalSizeClass, rhs: self.expression.2.toUserInterfaceSizeClass())
            
            case .Vertical:
                return self.expression.1.equal(traitCollection.verticalSizeClass, rhs: self.expression.2.toUserInterfaceSizeClass())

            case .Width:
                return self.expression.1.compare(Float(size.width), rhs: self.expression.3)
                
            case .Height:
                return self.expression.1.compare(Float(size.height), rhs: self.expression.3)

            case .Idiom:
                return self.expression.1.equal(traitCollection.userInterfaceIdiom, rhs: self.expression.2.toUserInterfaceIdiom())
            
            default:
                return false
        }
    }
}

struct Condition: Hashable, Parsable {
    
    ///@see Parsable
    let rawString: String
    var expressions: [Expression] = [Expression]()
    
    //Hashable compliancy
    var hashValue: Int {
        get {
            return hash(self)
        }
    }
    
    init(rawString: String) throws {
        
        self.rawString = sanitizeConditionString(rawString)
        
        let components = self.rawString.componentsSeparatedByString(Token.Separator.Condition)
        for exprString in components {
            try expressions.append(Expression(rawString: exprString))
        }
    }
    
    ///Check if a condition is valid given the trait collection and the size passed as argument
    func evaluate(view: UIView?, traitCollection: UITraitCollection, size: CGSize) -> Bool {
        
        var satisfied = true
        for expression in self.expressions {
            satisfied = satisfied && expression.evaluate(view, traitCollection: traitCollection, size: size)
        }
        
        return satisfied
    }
}

private func sanitizeConditionString(string: String) -> String {
    
    var ps = refl_stripQuotesFromString(string.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())).lowercaseString
    ps = ps.stringByReplacingOccurrencesOfString("\"", withString: "")
    ps = ps.stringByReplacingOccurrencesOfString("'", withString: "")
    ps = ps.stringByReplacingOccurrencesOfString("!=", withString: ExpressionToken.Operator.NotEqual.rawValue)
    ps = ps.stringByReplacingOccurrencesOfString("<=", withString: ExpressionToken.Operator.LessThanOrEqual.rawValue)
    ps = ps.stringByReplacingOccurrencesOfString(">=", withString: ExpressionToken.Operator.GreaterThanOrEqual.rawValue)
    ps = ps.stringByReplacingOccurrencesOfString("==", withString: ExpressionToken.Operator.Equal.rawValue)
    ps = ps.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())

    return ps
}






