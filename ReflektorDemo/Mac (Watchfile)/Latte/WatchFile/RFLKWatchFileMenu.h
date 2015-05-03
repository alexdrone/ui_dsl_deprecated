//
//  LTMenu.h
//  Latte
//
//  Created by Alex Usbergo on 6/27/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSWindow+CanBecomeWindowKey.h"

@interface RFLKWatchFileMenu : NSObject

+ (RFLKWatchFileMenu*)sharedInstance;

@property (strong) IBOutlet NSMenu *menu;
@property (strong) IBOutlet NSPopover *popover;


- (IBAction)changeIPAddress:(id)sender;
- (IBAction)applyChangesToIPAddress:(id)sender;
- (IBAction)discardChangesToIPAddress:(id)sender;
- (IBAction)changeSelectedFiles:(id)sender;
- (IBAction)quit:(id)sender;
- (IBAction)about:(id)sender;

@end
