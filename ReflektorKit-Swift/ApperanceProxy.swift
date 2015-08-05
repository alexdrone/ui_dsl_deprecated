//
//  Extensions.swift
//  ReflektorKitSwift
//
//  Created by Alex Usbergo on 05/08/15.
//  Copyright © 2015 Alex Usbergo. All rights reserved.
//

import UIKit

@objc class AppearanceProxy {
    private weak var view: UIView?
    
    //All the currently computed properties for this associated view
    let computedProperties = AppearanceManager.ComputedProperties()

    @objc subscript(key: String) -> AnyObject? {
        
        get {
            if let value = self.computedProperties.all[PropertyKeyPath(keyPath: key)] {
                return value.computeValue((self.view?.traitCollection)!, size: UIScreen.mainScreen().bounds.size)
                
            } else {
                return nil
            }
        }
    }
}

var __appearanceProxyHandle: UInt8 = 0
var __useAppearanceProxyHandle: UInt8 = 0

extension UIView {

    //The associated apperance proxy for this view
    @objc var refl_appearanceProxy: AppearanceProxy {
        get {
            var obj = objc_getAssociatedObject(self, &__appearanceProxyHandle) as? AppearanceProxy
            
            if obj == nil {
                obj = AppearanceProxy()
                obj!.view = self
                objc_setAssociatedObject(self, &__appearanceProxyHandle, obj, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            
            return obj!
        }

    }
    
    //Set this to true if you wish to use the apperance proxy
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
    
}
