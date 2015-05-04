//
//  LTMenu.m
//  Latte
//
//  Created by Alex Usbergo on 6/27/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RFLKWatchFileMenu.h"
#import "UKKQueue.h"

typedef NS_ENUM(NSInteger, LTMenuIconStatus) {
    LTMenuIconStatusSending,
    LTMenuIconStatusIdle
};

@interface RFLKWatchFileMenu ()

/* The status item associated to this menu */
@property (strong) NSStatusItem *statusItem;

/* Wether the popup is presented or not */
@property (assign, getter = isPopoverPresented) BOOL popoverPresented;

/* The current IP address of the targetted device */
@property (strong) NSString *IPAddress;
@end

@implementation RFLKWatchFileMenu

#pragma mark - Init

static RFLKWatchFileMenu *sharedInstace = nil;

+ (RFLKWatchFileMenu*)sharedInstance
{
    return [[RFLKWatchFileMenu alloc] init];
}

/* Creates and returns the only
 * shared instance of the menu */
- (id)init
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        sharedInstace = [super init];
    
        //Prompt for file selection
        [self selectFiles];
        
        //Register the file watcher notification
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:sharedInstace 
                                                               selector:@selector(fileChanged:) 
                                                                   name:UKFileWatcherWriteNotification 
                                                                 object:nil];
        
        //get the last used IPAddress
        sharedInstace.IPAddress = [[NSUserDefaults standardUserDefaults] objectForKey:@"IPAddress"];
        sharedInstace.IPAddress = sharedInstace.IPAddress ? sharedInstace.IPAddress : @"http://127.0.0.1:3000";
    });
    
    return sharedInstace;
}

/* After IB init */
- (void)awakeFromNib
{
    //Set up the status item
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    _statusItem.highlightMode = YES;
    _statusItem.menu = self.menu;
    _statusItem.title = @"Reflektor";
    
    //and set the icon status to idle
    [self changeIconForStatus:LTMenuIconStatusIdle];
}

#pragma mark - Private methods

/* File picked dialog. Select the files that 
 * will be watched and observe them */
- (void)selectFiles
{
    //Set up the dialog panel
    NSOpenPanel* dialog = [NSOpenPanel openPanel];
    dialog.canChooseFiles = YES;
    dialog.canChooseDirectories = NO;
    dialog.allowedFileTypes = @[@"reflektor", @"less", @"css"];
    dialog.allowsMultipleSelection = YES;

    //Remove all the old files from the queue
    [[UKKQueue sharedFileWatcher] performSelector:@selector(removeAllPathsFromQueue)];
    
    //Once the file are selected, the paths are added to the queue
    if ([dialog runModal] == NSOKButton)
        for (NSURL *url in dialog.URLs)
            [[UKKQueue sharedFileWatcher] addPathToQueue:url.path];
}


/* Change the menu icon for the given status */
- (void)changeIconForStatus:(LTMenuIconStatus)status
{
    NSString *ip = [[self.IPAddress componentsSeparatedByString:@"//"][1] componentsSeparatedByString:@":"][0];
    ip = [ip isEqualToString:@"127.0.0.1"] ? @"localhost" : ip;
    _statusItem.title = [NSString stringWithFormat:@"reflektor@%@", ip];
}

/* This is the only method to be implemented to conform to the SCEventListenerProtocol.
 * As this is only an example the event received is simply printed to the console.
 * pathwatcher: the SCEvents instance that received the event
 * event: the actual event */
- (void)fileChanged:(NSNotification*)note
{
    [self changeIconForStatus:LTMenuIconStatusSending];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5f * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
        [self changeIconForStatus:LTMenuIconStatusIdle];
    });
    
    //The filename
    NSString *path = [note.userInfo objectForKey:@"path"];
    NSLog(@"Latte file changed: %@", path);
    
    NSError *error = nil;
    NSString *file = [NSString stringWithContentsOfFile:path
                                               encoding:NSUTF8StringEncoding
                                                  error:&error];
    
    file = [NSString stringWithFormat:@"!!reflektor-payload-begin\n%@",file];
    
    if (nil != error) {
        NSLog(@"Unable to encode the file: %@", error.description);
        return;
    }
    
    //Create and send the request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.IPAddress]];
    request.HTTPBody = [file dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPMethod:@"POST"];
    request.timeoutInterval = 1.0f;
    
    //No response - acknowledgment
    NSURLResponse *response;
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];    
}

#pragma mark - IBActions 

/* Change the IP address of the targetted device */
- (IBAction)changeIPAddress:(id)sender
{
    //show the popover
    if (!self.popoverPresented) {
        
        //change the icon for the sending status 
        [self changeIconForStatus:LTMenuIconStatusSending];
        
        //shows the popover
        [self.popover showRelativeToRect:[[_statusItem valueForKey:@"fView"] bounds] 
                                  ofView:[_statusItem valueForKey:@"fView"] 
                           preferredEdge:NSMaxYEdge];
        self.popoverPresented = YES;
        
    //hide the popover
    } else {
        
        //change the icon for the sending status
        [self changeIconForStatus:LTMenuIconStatusIdle];
        
        //close the popover
        [self.popover close];
        self.popoverPresented = NO;
    }
}

- (IBAction)changeSelectedFiles:(id)sender
{
    [self selectFiles];
}

- (IBAction)applyChangesToIPAddress:(id)sender
{
    //The IP address components
    NSString *ip1  = [[[sender superview] viewWithTag:1] stringValue];
    NSString *ip2  = [[[sender superview] viewWithTag:2] stringValue];
    NSString *ip3  = [[[sender superview] viewWithTag:3] stringValue];
    NSString *ip4  = [[[sender superview] viewWithTag:4] stringValue];
    NSString *port = [[[sender superview] viewWithTag:5] stringValue];
    
    //Assemble the new IP
    self.IPAddress = [NSString stringWithFormat:@"http://%@.%@.%@.%@:%@", ip1, ip2, ip3, ip4, port];
    NSLog(@"New IP Address %@", self.IPAddress);
    
    //Save it in the user defaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:self.IPAddress forKey:@"IPAddress"];
	[defaults synchronize];
        
    //hide the popover
    [self changeIconForStatus:LTMenuIconStatusIdle];
    [self.popover close];
    self.popoverPresented = NO;
}

- (IBAction)discardChangesToIPAddress:(id)sender
{
    //hide the popover
    [self changeIconForStatus:LTMenuIconStatusIdle];
    [self.popover close];
    self.popoverPresented = NO;
}

- (IBAction)quit:(id)sender
{
    [NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0.0];
}



@end
