//
// UIView+RFLKAdditions.h
// ReflektorKit
//
// Created by Alex Usbergo on 22/04/15.
// Copyright (c) 2015 Alex Usbergo. All rights reserved.
//

#import <objc/runtime.h>

@import UIKit;

@interface UIView (RFLKAdditions)

///Redirects to 'layer.cornerRadius'
@property (nonatomic, assign) CGFloat cornerRadius;

///Redirects to 'layer.borderWidth'
@property (nonatomic, assign) CGFloat borderWidth;

///Redirects to 'layer.borderColor'
@property (nonatomic, strong) UIColor *borderColor;

///Frame helper (self.frame.origin.x)
@property (nonatomic, assign) CGFloat x;

///Frame helper (self.frame.origin.y)
@property (nonatomic, assign) CGFloat y;

///Frame helper (self.frame.size.width)
@property (nonatomic, assign) CGFloat width;

///Frame helper (self.frame.size.height)
@property (nonatomic, assign) CGFloat height;

///The opacity of the shadow. Defaults to 0. Specifying a value outside the
@property (nonatomic, assign) CGFloat shadowOpacity;

///The blur radius used to create the shadow. Defaults to 3.
@property (nonatomic, assign) CGFloat shadowRadius;

///The shadow offset. Defaults to (0, -3)
@property (nonatomic, assign) CGSize shadowOffset;

///The color of the shadow. Defaults to opaque black.
@property (nonatomic, strong) UIColor *shadowColor;

///Wheter this view uses flexbox layout for its children or not
@property (nonatomic, assign) BOOL flexContainer;

@end

@interface UIScreen (RLFKAddtions)

@property (nonatomic, readonly) CGRect rflk_screenBounds;

@end

@interface UIButton (RFLKAdditions)

//Symeetrical to  -[UIButton titleForState:]
@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) NSString *highlightedText;
@property (nonatomic, strong) NSString *selectedText;
@property (nonatomic, strong) NSString *disabledText;

//Symeetrical to  -[UIButton titleColorForState:]
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, strong) UIColor *highlightedTextColor;
@property (nonatomic, strong) UIColor *selectedTextColor;
@property (nonatomic, strong) UIColor *disabledTextColor;

//Symmetrical to -[UIButton backgroundImageForState:]
@property (nonatomic, strong) UIImage *backgroundImage;
@property (nonatomic, strong) UIImage *highlightedBackgroundImage;
@property (nonatomic, strong) UIImage *selectedBackgroundImage;
@property (nonatomic, strong) UIImage *disabledBackgroundImage;

//Symmetrical to -[UIButton imageForState:]
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) UIImage *highlightedImage;
@property (nonatomic, strong) UIImage *selectedImage;
@property (nonatomic, strong) UIImage *disabledImage;

@end

@interface UIImage (RFLKAdditions)

+ (UIImage*)rflk_imageWithColor:(UIColor*)color;
+ (UIImage*)rflk_imageWithColor:(UIColor*)color size:(CGSize)size;

@end

@interface NSObject (RFLKAutoRemovalNotification)

@property (nonatomic, assign) BOOL rflk_observationAdded;

- (void)rflk_addObserverForName:(NSString*)name object:(id)obj queue:(NSOperationQueue*)queue usingBlock:(void (^)(NSNotification*note))block;
- (void)rflk_addObserverForName:(NSString*)name usingBlock:(void (^)(NSNotification*note))block;

@end

