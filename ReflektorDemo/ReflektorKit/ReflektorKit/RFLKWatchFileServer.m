//
//  LTMarkupInjector.m
//  Latte
//
//  Created by Alex Usbergo on 6/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RFLKWatchFileServer.h"
#import "RFLKMacros.h"
#import "AsyncSocket.h"

const NSUInteger RFLKWatchFileServerDefaultPort = 3000;

@interface RFLKWatchFileServer ()

@property (strong) NSMutableArray *clients;
@property (strong) AsyncSocket *socket;
@property (assign, atomic, getter = isRunning) BOOL running;

@end

@implementation RFLKWatchFileServer

#pragma mark Singleton initialization code

+ (RFLKWatchFileServer*)sharedInstance
{
    static dispatch_once_t pred;
    static RFLKWatchFileServer *shared = nil;
    
    dispatch_once(&pred, ^{
        shared = [[RFLKWatchFileServer alloc] init];
    });
    
    return shared;
}

- (id)init
{
    if (self = [super init]) {
        _clients = [[NSMutableArray alloc] init];
        _socket = [[AsyncSocket alloc] initWithDelegate:self];
        _running = NO;
    }
    
    return self;
}

- (void)dealloc
{
    [self stop];
}

#pragma mark Socket

/* Start the guard manager on the given port */
- (void)startOnPort:(NSUInteger)port 
{
    //the server is already running
    if ([self isRunning]) return;
 
    if (port > 65535) port = 0;
        
    NSError *err = nil;
    if (NO == [_socket acceptOnPort:port error:&err]) {
        RFLKLog(@"Can't open the socket - %@", err);
        return;
    }
    
    self.running = YES;
}

- (void)stop
{
    if (NO == [self isRunning]) return;

    [self.socket disconnect];

    for (AsyncSocket *c in self.clients)
        [c disconnect];

    self.running = NO;
}


#pragma mark Delegate

- (void)onSocket:(AsyncSocket*)socket didAcceptNewSocket:(AsyncSocket*)newSocket 
{
	[self.clients addObject:newSocket];
}

- (void)onSocketDidDisconnect:(AsyncSocket*)socket 
{
	[self.clients removeObject:socket];
}

- (void)onSocket:(AsyncSocket*)socket didConnectToHost:(NSString*)host port:(UInt16)port;
{
    [socket readDataWithTimeout:-1 tag:0];
}

/* Triggered when guard.js send some markup data.
 * All the views are refreshed with the new markup */
- (void)onSocket:(AsyncSocket*)socket didReadData:(NSData*)data withTag:(long)tag 
{
    //ackwoledgement
    [socket writeData:[@"HTTP/1.1 200" dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
    
    @try {
        NSString *payload = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        RFLKLog(@"%@", payload);
    }
    
    @catch (NSException *exception) {
        RFLKLog(@"Corrupted request");
    }
}


@end
