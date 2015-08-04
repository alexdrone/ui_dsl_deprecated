//
//  ReflektorConfiguration.swift
//  ReflektorKit-Swift
//
//  Created by Alex Usbergo on 19/07/15.
//  Copyright © 2015 Alex Usbergo. All rights reserved.
//

import Foundation


@objc class Configuration {
    
    ///The unique shared configuration
    static let sharedConfiguration = Configuration()
    
    internal var propertyValuePlugins = [PropertyValuePlugin]()
    internal var externalConditions = [String: ExternalConditionClosure]()
    
    ///Add the plugin passed as argument to the registed plugins
    @objc  func registerPropertyValuePlugin(plugin: PropertyValuePlugin) {
        self.propertyValuePlugins.append(plugin)
    }
    
    ///Register an external condition.
    ///External conditions are expressed in the stylesheet in the form of 'external:key'
    @objc func registerExternalCondition(conditionName: String, conditionClosure: ExternalConditionClosure) {
        self.externalConditions[conditionName.lowercaseString] = conditionClosure
    }
    
}