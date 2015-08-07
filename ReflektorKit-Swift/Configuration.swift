//
//  ReflektorConfiguration.swift
//  ReflektorKit-Swift
//
//  Created by Alex Usbergo on 19/07/15.
//  Copyright © 2015 Alex Usbergo. All rights reserved.
//

import Foundation

@objc public class Configuration {
    
    ///The unique shared configuration
    public static let sharedConfiguration = Configuration()
    
    ///When set to 'true' when an apperance proxy refreshes its computed properties 
    ///These are automatically passed down to the associated view
    @objc public var shouldAutomaticallySetViewProperties = true
    
    //MARK: Plugins
    
    internal var propertyValuePlugins = [PropertyValuePlugin]()
    internal var externalConditions = [String: ExternalConditionClosure]()
    
    ///Add the plugin passed as argument to the registed plugins
    @objc public func registerPropertyValuePlugin(plugin: PropertyValuePlugin) {
        self.propertyValuePlugins.append(plugin)
    }
    
    ///Register an external condition.
    ///External conditions are expressed in the stylesheet in the form of 'external:key'
    @objc public func registerExternalCondition(conditionName: String, conditionClosure: ExternalConditionClosure) {
        self.externalConditions[conditionName.lowercaseString] = conditionClosure
    }
    
}