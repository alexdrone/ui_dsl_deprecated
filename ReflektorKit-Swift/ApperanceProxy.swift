//
//  Extensions.swift
//  ReflektorKitSwift
//
//  Created by Alex Usbergo on 05/08/15.
//  Copyright © 2015 Alex Usbergo. All rights reserved.
//

import UIKit

@objc public class AppearanceProxy: NSObject {
    
    @objc public class AppearanceProxyVariablesProxy: NSObject {
        
        ///Use this to access to the value of a global variable
        @objc subscript(key: String) -> AnyObject? {
            get {
                
                if let propertyValue = AppearanceManager.sharedManager.stylesheet.variables[PropertyKeyPath(keyPath: key)] {
                    return
                        propertyValue.computeValue(UIScreen.mainScreen().traitCollection, size: UIScreen.mainScreen().bounds.size)
                }
                return nil
            }
        }
        
        ///Get the value for a specific property listed in the rules
        @objc public func property(key: String) -> AnyObject? {
            return self[key]
        }
    }
    
    weak var view: UIView?
    
    ///All the currently computed properties for this associated view
    internal var computedProperties = (all: Rule(), important: Rule())
    internal var resetDictionary = [String: AnyObject?]()
    
    ///By default is the value set in the shared configuration
    @objc public var shouldAutomaticallySetViewProperties = Configuration.sharedConfiguration.shouldAutomaticallySetViewProperties
    
    ///The optional trait associated to this view
    @objc public var trait: String? {
        didSet {
            self.refreshComputedProperties()
        }
    }
    
    ///Returns all the constraints computed for the associated view
    @objc public var constraints: [NSLayoutConstraint] {
        get {
            
            var constraints = [NSLayoutConstraint]()
            for (_, value) in self.computedProperties.all where value.object is ConstraintsContainer {
                let c = (value.object as! ConstraintsContainer).constraintsForView(self.view)
                constraints += c
            }
            
            return constraints
        }
    }

    ///You can get a property by simply subscript the apperarance proxy of a view
    ///e.g. view.refl_appearanceProxy["backgroundColor"]
    @objc subscript(key: String) -> AnyObject? {
        get {
            if let value = self.computedProperties.all[PropertyKeyPath(keyPath: key)] {
                return value.computeValue((self.view?.traitCollection)!, size: UIScreen.mainScreen().bounds.size, view:self.view)
                
            } else {
                return nil
            }
        }
    }
    
    ///Get the value for a specific property listed in the rules
    @objc public func property(key: String) -> AnyObject? {
        return self[key]
    }

    ///Use this to access to the global variables (the ones defined with @ in the stylesheet)
    ///E.g. given the stylesheet @global { @blue = #0000ff; } You can reference the variable from a view
    ///by calling view.refl_appearanceProxy.variable["blue"]
    let variable = AppearanceProxyVariablesProxy()
    
    init(view: UIView) {
        super.init()
        self.view = view
        self.computedProperties = AppearanceManager.sharedManager.computeStyleForApperanceProxy(self)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: NSSelectorFromString("didChangeStylesheetNotification:"), name: AppearanceManager.Notification.DidChangeStylesheet.rawValue, object: nil)
    }
    
    ///When the stylesheet changes the properties needs to be re-computed
    @objc public func didChangeStylesheetNotification(notification: NSNotification) {
        self.refreshComputedProperties()
    }

    ///Recompute what properties
    @objc public func refreshComputedProperties(shouldApplyOnlyImportantProperties: Bool = false) {
        
        //recompute the matching selectors
        self.computedProperties = AppearanceManager.sharedManager.computeStyleForApperanceProxy(self)
        
        if self.shouldAutomaticallySetViewProperties {
            self.applyComputedProperties(shouldApplyOnlyImportantProperties)
        }
        
    }
    
    ///Applies the properties from the 'computedProperties' dictionary down to the view
    ///If 'shouldApplyOnlyImportantProperties' is set to true, only the rules marked with 
    ///!important are going to be processed and applied to the view.
    @objc public func applyComputedProperties(shouldApplyOnlyImportantProperties: Bool = false) {
        
        guard let v = self.view else {
            return
        }
        
        let dictionary = shouldApplyOnlyImportantProperties ? self.computedProperties.important : self.computedProperties.all
        
        //reset the view with the previous values
        for keyPath in self.resetDictionary.keys {
            self.view?.setValue(self.resetDictionary[keyPath]!, forKey: keyPath)
        }
        
        for key in dictionary.keys {
            
            let k = key.rawString
            
            if v.refl_hasKey(k) {
                
                let value = self[k]
                
                //populate the reset dictionary
                self.resetDictionary[k] = v.valueForKeyPath(k)
                
                //applies the value
                guard let oldValue = v.valueForKeyPath(k) as? NSObject else {
                    v.setValue(value, forKeyPath: k)
                    continue
                }
                
                if !oldValue.isEqual(value) {
                    v.setValue(value, forKeyPath: k)
                }

            }

        }
    }

}

var __appearanceProxyHandle: UInt8 = 0
var __useAppearanceProxyHandle: UInt8 = 0

public extension UIView {

    ///The associated apperance proxy for this view
    @objc var refl_appearanceProxy: AppearanceProxy {
        get {
            var obj = objc_getAssociatedObject(self, &__appearanceProxyHandle) as? AppearanceProxy
            
            if obj == nil {
                obj = AppearanceProxy(view: self)
                obj!.view = self
                objc_setAssociatedObject(self, &__appearanceProxyHandle, obj, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            return obj!
        }
    }
    
    ///Set this to true if you wish to use the apperance proxy
    @objc var refl_useAppearanceProxy: Bool {
        get {
            return objc_getAssociatedObject(self, &__useAppearanceProxyHandle).boolValue
        }
        
        set {
            objc_setAssociatedObject(self, &__useAppearanceProxyHandle, NSNumber(bool: newValue), objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            if newValue {
                //triggers the creation of the lazy object
                self.refl_appearanceProxy
            }
        }
    }
    
    ///Convenience intialiser to create a view with an associated appearance proxy
    ///::useAppearanceProxy;; 'true' if you wish to use the stylesheet engino, 'false' otherwise
    ///::hookToViewLifecycle:: If set to 'true' the proxy will automatically refresh and apply the properties 
    ///by hooking itself to 'layoutSubviews' and 'traitCollectionDidChange:' of the hosting view.
    ///If set to 'false' it is required to call 'refl_appearanceProxy.refreshComputedProperties()' every time 
    ///a change in the enviroment happens.
    ///::trait:: The (optional) trait for this view. Can be changed at runtime.
    convenience init(frame: CGRect, useAppearanceProxy: Bool, trait: String? = nil) {
        self.init(frame: frame)
        
        self.refl_useAppearanceProxy = useAppearanceProxy;
        
        //setting the trait causes the appearance proxy to apply the computed properties
        self.refl_appearanceProxy.trait = trait
    }
    
    ///Recursively applies the style from the stylesheet to this view and all its subviews (and so on)
    @objc func refl_applyStyleRecursive(shouldApplyOnlyImportantProperties: Bool = false) {
        self.refl_appearanceProxy.refreshComputedProperties(shouldApplyOnlyImportantProperties)
        for subview in self.subviews {
            subview.refl_appearanceProxy.refreshComputedProperties()
        }
    }
}

public extension UIViewController {
    
    ///Recursively applies the style from the stylesheet to this view and all its subviews (and so on)
    @objc func refl_applyStyleToViewRecursive(shouldApplyOnlyImportantProperties: Bool = false) {
        self.view.refl_applyStyleRecursive(shouldApplyOnlyImportantProperties)
    }

}
