//
//  Constraints.swift
//  ReflektorKitSwift
//
//  Created by Alex Usbergo on 09/08/15.
//  Copyright © 2015 Alex Usbergo. All rights reserved.
//

import UIKit

//MARK: Operator extension

extension Condition.ExpressionToken.Operator {
    
    internal func toLayoutRelation() -> NSLayoutRelation {
    
        switch self {
            
        case .LessThan, .LessThanOrEqual:
            return NSLayoutRelation.LessThanOrEqual
            
        case .Equal:
            return NSLayoutRelation.Equal
            
        case .GreaterThan, .GreaterThanOrEqual:
            return NSLayoutRelation.GreaterThanOrEqual
            
        default:
            return NSLayoutRelation.Equal
        }
    }
}

//MARK: Value container

//plugin objects are constrained to classes
@objc public class ConstraintsContainer: NSObject {
    
    //@see Parsable
    let rawString: String
    let vfl: Bool
    
    //defaults
    var constant: Float = 0
    var multiplier: Float = 1
    var priority: UILayoutPriority = UILayoutPriorityDefaultLow
    var options = NSLayoutFormatOptions(rawValue: 0)
    
    //privates
    private let viewKeys: [NSString]
    private let lhs: (key: String, attribute: ConstraintValuePlugin.ConstraintToken.Attribute)?
    private let rhs: (key: String, attribute: ConstraintValuePlugin.ConstraintToken.Attribute)?
    private let opr: Condition.ExpressionToken.Operator?
    
    init(rawString: String, vfl: Bool = false) throws {
        
        //wether is a visual format language constraint or not
        self.vfl = vfl
        
        //append all the keys found in the VFL or in the custom constraint syntax
        var viewKeys = [String]()
        
        while let match = rawString.rangeOfString("_(\\w*)", options: .RegularExpressionSearch) {
            let key = rawString[match]
            viewKeys.append(key)
        }
        self.viewKeys = viewKeys
        
        if self.vfl {
            
            self.rawString = rawString
            
            //init private properties
            self.lhs = nil
            self.rhs = nil
            self.opr = nil
            
        } else {
            
            //constraint in the format of
            //"__self.height == _containerView.height" or "__self.width < __constant.notAnAttribute"
            
            //parse the custom syntax
            self.rawString = Parser.normalizeExpressionString(rawString, forceLowerCase: false)
            let terms = self.rawString.componentsSeparatedByCharactersInSet(Condition.ExpressionToken.Operator.characterSet())
            
            //the left and the right side of the expression
            let lhsCompound = terms[0].componentsSeparatedByString(ConstraintValuePlugin.ConstraintToken.Keywords.AttributeSeparator.rawValue)
            let rhsCompount = terms[1].componentsSeparatedByString(ConstraintValuePlugin.ConstraintToken.Keywords.AttributeSeparator.rawValue)
            
            self.lhs = (key: lhsCompound[0], attribute: ConstraintValuePlugin.ConstraintToken.Attribute(rawValue: lhsCompound[1])!)
            self.rhs = (key: rhsCompount[0], attribute: ConstraintValuePlugin.ConstraintToken.Attribute(rawValue: rhsCompount[1])!)
            self.opr = Condition.ExpressionToken.Operator.operatorContainedInString(self.rawString)
        }
    }
    
    ///Constraint for the view passed as argument
    public func constraintsForView(view: UIView?) -> [NSLayoutConstraint] {
        
        guard let v = view else {
            return [NSLayoutConstraint]()
        }
        
        //populate the viewDicionary
        var viewDictionary = [String: AnyObject]()
        viewDictionary[ConstraintValuePlugin.ConstraintToken.Keywords.SelfReferenced.rawValue] = v
        
        for k in viewKeys {
            
            //trims the initial _
            let keyPath = (k as NSString).substringFromIndex(1)
            
            //populates the view dictionary
            if v.refl_hasKey(keyPath) {
                viewDictionary[k as String] = v.valueForKeyPath(keyPath)
            }
        }
        
        if self.vfl {
            
            var metrics = [String: NSNumber]()
            
            //builds up the metrics dictionary on the fly
            for propertyKey in v.refl_appearanceProxy.computedProperties.all.keys {
                if let value = v.refl_appearanceProxy.property(propertyKey.rawString) as? Float {
                    metrics[propertyKey.rawString] = value
                }
            }
            
            //creates a visual constraint
            return NSLayoutConstraint.constraintsWithVisualFormat(self.rawString, options: self.options, metrics: metrics, views: viewDictionary)
            
        } else {
            
            guard let lhs = self.lhs, rhs = self.rhs, opr = self.opr else {
                return [NSLayoutConstraint]()
            }
            
            let lhsObj = viewDictionary[lhs.key]!
            let lhsAtt = lhs.attribute.toLayoutAttribute()
            let rhsObj = rhs.key == ConstraintValuePlugin.ConstraintToken.Keywords.Constant.rawValue ? nil : viewDictionary[rhs.key]
            let rhsAtt = rhs.key == ConstraintValuePlugin.ConstraintToken.Keywords.Constant.rawValue ? NSLayoutAttribute.NotAnAttribute : rhs.attribute.toLayoutAttribute()
            
            return [NSLayoutConstraint(item: lhsObj, attribute: lhsAtt, relatedBy: opr.toLayoutRelation(), toItem: rhsObj, attribute: rhsAtt, multiplier: CGFloat(self.multiplier), constant: CGFloat(self.constant))]
        }
    }
}

//MARK: Plugin

@objc public class ConstraintValuePlugin: PropertyValuePlugin {
    
    private struct ConstraintToken {
        
        enum Keywords: String {
            case Constant = "__constant"
            case SelfReferenced = "__self"
            case AttributeSeparator = "."
        }
        
        enum Attribute: String {
            
            case Left = "left"
            case Right = "right"
            case Top = "top"
            case Bottom = "bottom"
            case Leading = "leading"
            case Trailing = "trailing"
            case Width = "width"
            case Height = "height"
            case CenterX = "centerX"
            case CenterY = "centerY"
            case Baseline = "baseline"
            case FirstBaseline = "firstBaseline"
            case LeftMargin = "leftBaseline"
            case RightMargin = "rightMargin"
            case TopMargin = "topMargin"
            case BottomMargin = "bottomMargin"
            case LeadingMargin = "leadingMargin"
            case TrailingMargin = "trailingMargin"
            case CenterXWithinMargins = "centerXWithinMargins"
            case CenterYWithinMargins = "centerYWithinMargins"
            case NotAnAttribute = "notAnAttribute"
            
            ///Converts the enum to a NSLayoutAttribute
            func toLayoutAttribute() -> NSLayoutAttribute {
                
                switch self {
                    
                case .Left:
                    return NSLayoutAttribute.Left
                case .Right:
                    return NSLayoutAttribute.Right
                case .Top:
                    return NSLayoutAttribute.Top
                case .Bottom:
                    return NSLayoutAttribute.Bottom
                case .Leading:
                    return NSLayoutAttribute.Leading
                case .Trailing:
                    return NSLayoutAttribute.Trailing
                case .CenterX:
                    return NSLayoutAttribute.CenterX
                case .CenterY:
                    return NSLayoutAttribute.CenterY
                case .Baseline:
                    return NSLayoutAttribute.Baseline
                case .FirstBaseline:
                    return NSLayoutAttribute.FirstBaseline
                case .LeftMargin:
                    return NSLayoutAttribute.LeftMargin
                case .TrailingMargin:
                    return NSLayoutAttribute.TrailingMargin
                case .CenterXWithinMargins:
                    return NSLayoutAttribute.CenterXWithinMargins
                case .CenterYWithinMargins:
                    return NSLayoutAttribute.CenterYWithinMargins
                case .NotAnAttribute:
                    return NSLayoutAttribute.NotAnAttribute
                default:
                    return NSLayoutAttribute.NotAnAttribute
                }
            }
        }
    }
    
    
    ///Should returns 'true' if the rawString passed as argument is a valid input string for this plugin
    @objc public func shouldParseValue(rawString: String) -> Bool {
        return refl_stringHasPrefix(rawString, ["constraint", "vfl-constraint"])
    }
    
    ///Parse the string into a value or an itermediate object to be processed when 'computeValueForObject' is called
    @objc public func parseValue(rawString: String) -> AnyObject? {
        
        //get the arguments out from the rawString
        guard let args = refl_getArgumentForValue(rawString) else {
            return nil
        }
        
        if refl_stringHasPrefix(rawString, ["constraint"]) {
            
            do {
                
                //format is constraint("__self.top == _aView.bottom") or constraint("__self.top == _aView.bottom", 0, 1)
                
                guard let constraintString = args[0] as? String else {
                    return nil
                }
                
                let container = try ConstraintsContainer(rawString: constraintString)
                
                //constant
                if let c = args[1].floatValue {
                    container.constant = c
                }
                
                //multiplier
                if let m = args[2].floatValue {
                    container.multiplier = m
                }
                
                return container

            } catch {

                //plugins can't throw exceptions
                return nil
            }

        } else if refl_stringHasPrefix(rawString, ["vfl-constraint"]) {
            
            do {
                
                guard let constraintString = args[0] as? String else {
                    return nil
                }
                
                let container = try ConstraintsContainer(rawString: constraintString, vfl: true)
                
                return container
                
            } catch {
                
                //plugins can't throw exceptions
                return nil
            }
            
        }
        
        return nil
    }
    
    ///Called when the styelesheet proxy is queried for a specific property value
    ///::object:: is the previously parsed object that could contains the value or a intermediate representation of it
    @objc public func computeValueForObject(object: AnyObject?, traitCollection: UITraitCollection, size: CGSize, view: UIView?) -> AnyObject? {

        guard let container = object as? ConstraintsContainer else {
            return nil
        }
        
        return container.constraintsForView(view)
    }
    
}
