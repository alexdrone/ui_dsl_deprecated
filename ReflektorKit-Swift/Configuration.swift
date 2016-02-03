//
//  ReflektorConfiguration.swift
//  ReflektorKit-Swift
//
//  Created by Alex Usbergo on 19/07/15.
//  Copyright © 2015 Alex Usbergo. All rights reserved.
//

import Foundation

@objc public class Configuration: NSObject {
    
    ///The unique shared configuration
    @objc public static let sharedConfiguration = Configuration()
    
    ///When set to 'true' when an apperance proxy refreshes its computed properties 
    ///These are automatically passed down to the associated view
    @objc public var shouldAutomaticallySetViewProperties = true
    
    ///Call start on this to have the refresh server available.
    private lazy var refreshServer: HttpServer = {
        
        let server = HttpServer()
        server["/refresh"] = { request in
            
            var location: String = ""
            for param in request.queryParams { if param.0 == "location" { location = param.1 }}
            
            //reload the stylesheets
            AppearanceManager.sharedManager.loadStylesheetFromFile(self.stylesheetEntryPoint.0, fileExtension: self.stylesheetEntryPoint.1, url: NSURL(string: location))
            
            //make sure that the views on screen are updated
            dispatch_async(dispatch_get_main_queue()) {
                
                assert(NSThread.isMainThread())
                
                UIApplication.sharedApplication().keyWindow?.rootViewController?.refl_applyStyleToViewRecursive()
                UIApplication.sharedApplication().keyWindow?.rootViewController?.updateViewConstraints()
            }
            
            //response
            return HttpResponse.OK(HttpResponseBody.Html(""))
        }
        
        return server
    }()
    
    //MARK: Plugins
    
    internal var propertyValuePlugins = [PropertyValuePlugin]()
    internal var externalConditions = [String: ExternalConditionClosure]()
    internal var stylesheetEntryPoint: (String, String) = ("main", "less")
    
    ///Add the plugin passed as argument to the registed plugins
    @objc public func registerPropertyValuePlugin(plugin: PropertyValuePlugin) {
        self.propertyValuePlugins.append(plugin)
    }
    
    ///Register an external condition.
    ///External conditions are expressed in the stylesheet in the form of 'external:key'
    @objc public func registerExternalCondition(conditionName: String, conditionClosure: ExternalConditionClosure) {
        self.externalConditions[conditionName.lowercaseString] = conditionClosure
    }
    
    ///Starts the refresh server
    @objc public func startRefreshServer(port: UInt = 8080) {
        try! self.refreshServer.start(in_port_t(port))
    }
    
}