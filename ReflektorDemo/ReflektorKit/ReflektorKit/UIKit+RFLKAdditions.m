//
// UIView+RFLKAdditions.m
// ReflektorKit
//
// Created by Alex Usbergo on 22/04/15.
// Copyright (c) 2015 Alex Usbergo. All rights reserved.
//

#import "UIKit+RFLKAdditions.h"
#import "RFLKMacros.h"
#import <objc/runtime.h>

static void *UIViewFlexContainerKey;

#pragma mark - UIView

@implementation UIView (RFLKAdditions)

- (CGFloat)cornerRadius
{
    return self.layer.cornerRadius;
}

- (void)setCornerRadius:(CGFloat)cornerRadius
{
    self.clipsToBounds = YES;
    self.layer.cornerRadius = cornerRadius;
}

- (CGFloat)borderWidth
{
    return self.layer.borderWidth;
}

- (void)setBorderWidth:(CGFloat)borderWidth
{
    self.layer.borderWidth = borderWidth;
}

- (UIColor*)borderColor
{
    return [UIColor colorWithCGColor:self.layer.borderColor];
}

- (void)setBorderColor:(UIColor*)borderColor
{
    self.layer.borderColor = borderColor.CGColor;
}

- (CGFloat)paddingLeft
{
    return 0;
}

- (CGFloat)x
{
    return self.frame.origin.x;
}

- (CGFloat)y
{
    return self.frame.origin.y;
}

- (CGFloat)height
{
    return CGRectGetHeight(self.frame);
}

- (CGFloat)width
{
    return CGRectGetWidth(self.frame);;
}

- (void)setX:(CGFloat)x
{
    CGRect rect = self.frame;
    rect.origin.x = x;
    self.frame = rect;
}

- (void)setY:(CGFloat)y
{
    CGRect rect = self.frame;
    rect.origin.y = y;
    self.frame = rect;
}

- (void)setHeight:(CGFloat)height
{
    CGRect rect = self.frame;
    rect.size.height = height;
    self.frame = rect;
}

- (void)setWidth:(CGFloat)width
{
    CGRect rect = self.frame;
    rect.size.width = width;
    self.frame = rect;
}

- (CGFloat)shadowOpacity
{
    return self.layer.shadowOpacity;
}

- (void)setShadowOpacity:(CGFloat)shadowOpacity
{
    self.layer.shadowOpacity = shadowOpacity;
}

- (CGFloat)shadowRadius
{
    return self.layer.shadowRadius;
}

- (void)setShadowRadius:(CGFloat)shadowRadius
{
    self.layer.shadowRadius = shadowRadius;
}

- (CGSize)shadowOffset
{
    return self.layer.shadowOffset;
}

- (void)setShadowOffset:(CGSize)shadowOffset
{
    self.layer.shadowOffset = shadowOffset;
}

- (UIColor*)shadowColor
{
    return [UIColor colorWithCGColor:self.layer.shadowColor];
}

- (void)setShadowColor:(UIColor*)shadowColor
{
    self.layer.shadowColor = shadowColor.CGColor;
}

- (BOOL)flexContainer
{
    return [objc_getAssociatedObject(self, &UIViewFlexContainerKey) boolValue];
}

- (void)setFlexContainer:(BOOL)flexContainer
{
    objc_setAssociatedObject(self, &UIViewFlexContainerKey, @(flexContainer), OBJC_ASSOCIATION_RETAIN);
}

@end

#pragma mark - UIScreen

@implementation UIScreen (RLFKAddtions)

- (CGRect)rflk_screenBounds
{
    UIScreen *screen = self;
    
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
    if ([screen respondsToSelector:@selector(fixedCoordinateSpace)])
        return [screen.coordinateSpace convertRect:screen.bounds toCoordinateSpace:screen.fixedCoordinateSpace];
#endif
    
    return screen.bounds;
}

@end


#pragma mark - UIButton

@implementation UIButton (RFLKAdditions)

- (NSString*)text
{
    return [self titleForState:UIControlStateNormal];
}

- (void)setText:(NSString*)text
{
    [self setTitle:text forState:UIControlStateNormal];
}

- (NSString*)highlightedText
{
    return [self titleForState:UIControlStateHighlighted];
}

- (void)setHighlightedText:(NSString*)highlightedText
{
    [self setTitle:highlightedText forState:UIControlStateHighlighted];
}

- (NSString*)selectedText
{
    return [self titleForState:UIControlStateSelected];
}

-  (void)setSelectedText:(NSString*)selectedText
{
    [self setTitle:selectedText forState:UIControlStateSelected];
}

- (NSString*)disabledText
{
    return [self titleForState:UIControlStateDisabled];
}

- (void)setDisabledText:(NSString*)disabledText
{
    [self setTitle:disabledText forState:UIControlStateDisabled];
}

- (UIColor*)textColor
{
    return [self titleColorForState:UIControlStateNormal];
}

- (void)setTextColor:(UIColor*)textColor
{
    [self setTitleColor:textColor forState:UIControlStateNormal];
}

- (UIColor*)highlightedTextColor
{
    return [self titleColorForState:UIControlStateHighlighted];
}

- (void)setHighlightedTextColor:(UIColor*)highlightedTextColor
{
    [self setTitleColor:highlightedTextColor forState:UIControlStateHighlighted];
}

- (UIColor*)selectedTextColor
{
    return [self titleColorForState:UIControlStateSelected];
}

- (void)setSelectedTextColor:(UIColor*)selectedTextColor
{
    [self setTitleColor:selectedTextColor forState:UIControlStateSelected];
}

- (UIColor*)disabledTextColor
{
    return [self titleColorForState:UIControlStateDisabled];
}

- (void)setDisabledTextColor:(UIColor*)disabledTextColor
{
    [self setTitleColor:disabledTextColor forState:UIControlStateDisabled];
}

@end

#pragma mark - UINotificationCenter

typedef void (^_RFLKDeallocBlock)();

@interface NSObject (RFLKAutoRemovalNotificationHelper)

@property (nonatomic, strong, setter=rflk_setDeallocContext:) id rflk_deallocContext;
- (void)rflk_setDeallocBlock:(_RFLKDeallocBlock)block;

@end

@implementation NSObject (prmAutoRemovalNotification)

- (void)rflk_addObserverForName:(NSString*)name object:(id)obj queue:(NSOperationQueue*)queue usingBlock:(void (^)(NSNotification*))block
{
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:name object:obj queue:queue usingBlock:block];
    NSMutableArray *observers = [self rflk_deallocContext];
    
    if (observers == nil) {
        
        observers = @[].mutableCopy;
        [self rflk_setDeallocContext:observers];
        
        __weak typeof(self) weakSelf = self;
        [self rflk_setDeallocBlock:^{
            for (id o in weakSelf.rflk_deallocContext) [[NSNotificationCenter defaultCenter] removeObserver:o];
        }];
    }
    
    [observers addObject:observer];
}

- (void)rflk_addObserverForName:(NSString*)name usingBlock:(void (^)(NSNotification*))block
{
    [self rflk_addObserverForName:name object:nil queue:nil usingBlock:block];
}

@end


@interface _RFLKDeallocBlockBox : NSObject

@property (nonatomic, retain) id context;
@property (nonatomic, copy) _RFLKDeallocBlock block;

@end

static void *_RFLKBlockBoxPropertyKey;
static void *_RFLKObservervationAddedPropertyKey;


@implementation NSObject (prmAutoRemovalNotificationHelper)

- (id)rflk_deallocContext
{
    return [self rflk_box].context;
}

- (void)rflk_setDeallocContext:(id)context
{
    [self rflk_box].context = context;
}

- (void)rflk_setDeallocBlock:(_RFLKDeallocBlock)block
{
    [self rflk_box].block = block;
}

- (_RFLKDeallocBlockBox*)rflk_box
{
    _RFLKDeallocBlockBox *box = objc_getAssociatedObject(self, &_RFLKBlockBoxPropertyKey);
    
    if (box == nil) {
        box = [[_RFLKDeallocBlockBox alloc] init];
        objc_setAssociatedObject(self, &_RFLKBlockBoxPropertyKey, box, OBJC_ASSOCIATION_RETAIN);
    }
    
    return box;
}

- (void)setRflk_observationAdded:(BOOL)rflk_observationAdded
{
    objc_setAssociatedObject(self, &_RFLKObservervationAddedPropertyKey, @(rflk_observationAdded), OBJC_ASSOCIATION_ASSIGN);
}

- (BOOL)rflk_observationAdded
{
    return [objc_getAssociatedObject(self, &_RFLKObservervationAddedPropertyKey) boolValue];
}

@end

@implementation _RFLKDeallocBlockBox

- (void)dealloc
{
    if (self.block) self.block();
}

@end
