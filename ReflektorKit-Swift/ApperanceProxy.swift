//
//  Extensions.swift
//  ReflektorKitSwift
//
//  Created by Alex Usbergo on 05/08/15.
//  Copyright © 2015 Alex Usbergo. All rights reserved.
//

import UIKit

@objc class AppearanceProxy {
    
     @objc class AppearanceProxyVariablesProxy {
        
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
    }
    
    weak var view: UIView?
    
    ///All the currently computed properties for this associated view
    private var computedProperties = (all: Rule(), important: Rule())
    private var resetDictionary = [String: AnyObject?]()
    
    ///By default is the value set in the shared configuration
    @objc var shouldAutomaticallySetViewProperties = Configuration.sharedConfiguration.shouldAutomaticallySetViewProperties
    
    ///The optional trait associated to this view
    @objc var trait: String? {
        didSet {
            self.refreshComputedProperties()
        }
    }

    ///You can get a property by simply subscript the apperarance proxy of a view
    ///e.g. view.refl_appearanceProxy["backgroundColor"]
    @objc subscript(key: String) -> AnyObject? {
        get {
            if let value = self.computedProperties.all[PropertyKeyPath(keyPath: key)] {
                return value.computeValue((self.view?.traitCollection)!, size: UIScreen.mainScreen().bounds.size)
                
            } else {
                return nil
            }
        }
    }

    ///Use this to access to the global variables (the ones defined with @ in the stylesheet)
    ///E.g. given the stylesheet @global { @blue = #0000ff; } You can reference the variable from a view
    ///by calling view.refl_appearanceProxy.variable["blue"]
    let variable = AppearanceProxyVariablesProxy()
    
    init(view: UIView) {
        self.view = view
        self.refreshComputedProperties()
    
        NSNotificationCenter.defaultCenter().addObserver(self, selector: NSSelectorFromString("didChangeStylesheetNotification:"), name: AppearanceManager.Notification.DidChangeStylesheet.rawValue, object: nil)
    }
    
    ///When the stylesheet changes the properties needs to be re-computed
    @objc func didChangeStylesheetNotification(notification: NSNotification) {
        self.refreshComputedProperties()
    }

    ///Recompute what properties
    @objc func refreshComputedProperties(shouldApplyOnlyImportantProperties: Bool = false) {
        
        //recompute the matching selectors
        self.computedProperties = AppearanceManager.sharedManager.computeStyleForApperanceProxy(self)
        
        if self.shouldAutomaticallySetViewProperties {
            self.applyComputedProperties(shouldApplyOnlyImportantProperties)
        }
        
    }
    
    ///Applies the properties from the 'computedProperties' dictionary down to the view
    ///If 'shouldApplyOnlyImportantProperties' is set to true, only the rules marked with 
    ///!important are going to be processed and applied to the view.
    @objc func applyComputedProperties(shouldApplyOnlyImportantProperties: Bool = false) {
        
        let dictionary = shouldApplyOnlyImportantProperties ? self.computedProperties.important : self.computedProperties.all
        
        //reset the view with the previous values
        for keyPath in self.resetDictionary.keys {
            self.view?.setValue(self.resetDictionary[keyPath]!, forKey: keyPath)
        }
        
        for key in dictionary.keys {
            
            let keyPath = key.rawString
            let value = self[keyPath]
            
            //populate the reset dictionary
            self.resetDictionary[keyPath] = self.view?.valueForKey(keyPath)

            //applies the value
            self.view?.setValue(value, forKey: keyPath)
        }
    }
    
    ///Swizzle the main view life cycle methods to hook the appearance manager methods
    @objc func hookToViewLifecycle() {
        
        self.shouldAutomaticallySetViewProperties = true
        
        do {
            
            let layoutSubviewsBlock: @convention(block) (REFLAspectInfo) -> () = { (info: REFLAspectInfo) -> () in
                self.refreshComputedProperties(true)
            }
            
            let refreshBlock: @convention(block) (REFLAspectInfo) -> () = { (info: REFLAspectInfo) -> () in
                self.refreshComputedProperties()
            }
            
            try self.view?.REFLAspect_hookSelector(NSSelectorFromString("layoutSubviews"), withOptions: .PositionBefore, usingBlock: unsafeBitCast(layoutSubviewsBlock, AnyObject.self))
            try self.view?.REFLAspect_hookSelector(NSSelectorFromString("didMoveToSuperview"), withOptions: .PositionBefore, usingBlock: unsafeBitCast(refreshBlock, AnyObject.self))
            try self.view?.REFLAspect_hookSelector(NSSelectorFromString("traitCollectionDidChange"), withOptions: .PositionBefore, usingBlock: unsafeBitCast(refreshBlock, AnyObject.self))
            
        } catch {
            assert(false, "Unable to swizzle the view's lifecycle methods")
        }

    }
}

var __appearanceProxyHandle: UInt8 = 0
var __useAppearanceProxyHandle: UInt8 = 0

extension UIView {

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
    convenience init(frame: CGRect, useAppearanceProxy: Bool, hookToViewLifecycle: Bool, trait: String? = nil) {
        self.init(frame: frame)
        
        self.refl_useAppearanceProxy = useAppearanceProxy;
        
        if hookToViewLifecycle {
            self.refl_appearanceProxy.hookToViewLifecycle()
        }
        
        self.refl_appearanceProxy.trait = trait
    }
    
}
