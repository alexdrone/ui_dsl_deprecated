//
//  ReflektorConfiguration.swift
//  ReflektorKit-Swift
//
//  Created by Alex Usbergo on 19/07/15.
//  Copyright © 2015 Alex Usbergo. All rights reserved.
//

import Foundation

public class Configuration: NSObject {
    
    ///The unique shared configuration
    @objc public static let sharedConfiguration = Configuration()
    
    ///When set to 'true' when an apperance proxy refreshes its computed properties 
    ///These are automatically passed down to the associated view
    @objc public var shouldAutomaticallySetViewProperties = true
    
    ///Call start on this to have the refresh server available.
    
    public lazy var refreshServer: HttpServer = {
        
        let server = HttpServer()
        server["/refresh"] = { request in
            
            var location: String = ""
            var file: String = ""
            for param in request.queryParams {
                if param.0 == "location" { location = param.1 }
                if param.0 == "file" { file = param.1 }
            }
            
            print("\(request.path) \(request.queryParams)")
            
            return HttpResponse.OK(HttpResponseBody.Html("Attemping to refresh \(file) from \(location)"))
        }
        
        return server
    }()
    
    
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