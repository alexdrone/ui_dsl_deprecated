//
//  UIView+RFLKAdditions.h
//  ReflektorKit
//
//  Created by Alex Usbergo on 22/04/15.
//  Copyright (c) 2015 Alex Usbergo. All rights reserved.
//

#import <objc/runtime.h>

@import UIKit;

@interface UIView (RFLKAdditions)

/// Redirects to 'layer.cornerRadius'
@property (nonatomic, assign) CGFloat cornerRadius;

/// Redirects to 'layer.borderWidth'
@property (nonatomic, assign) CGFloat borderWidth;

/// Redirects to 'layer.borderColor'
@property (nonatomic, strong) UIColor *borderColor;

/// Frame helper (self.frame.origin.x)
@property (nonatomic, assign) CGFloat x;

/// Frame helper (self.frame.origin.y)
@property (nonatomic, assign) CGFloat y;

/// Frame helper (self.frame.size.width)
@property (nonatomic, assign) CGFloat width;

/// Frame helper (self.frame.size.height)
@property (nonatomic, assign) CGFloat height;

@end

@interface UIScreen (RLFKAddtions)

@property (nonatomic, readonly) CGRect rflk_screenBounds;

@end

@interface NSObject (RFLKAutoRemovalNotification)

@property (nonatomic, assign) BOOL rflk_observationAdded;

- (void)rflk_addObserverForName:(NSString*)name object:(id)obj queue:(NSOperationQueue*)queue usingBlock:(void (^)(NSNotification*note))block;
- (void)rflk_addObserverForName:(NSString*)name usingBlock:(void (^)(NSNotification*note))block;

@end

