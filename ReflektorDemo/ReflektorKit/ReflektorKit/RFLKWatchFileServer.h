//
//  LTMarkupInjector.h
//  Latte
//
//  Created by Alex Usbergo on 6/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

extern const NSUInteger RFLKWatchFileServerDefaultPort;

@interface RFLKWatchFileServer : NSObject

+ (RFLKWatchFileServer*)sharedInstance;

- (void)startOnPort:(NSUInteger)port;
- (void)stop;
@end
