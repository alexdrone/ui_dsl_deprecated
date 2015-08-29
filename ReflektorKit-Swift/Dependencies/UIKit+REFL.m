//
// UIView+REFLAdditions.m
// ReflektorKit
//
// Created by Alex Usbergo on 22/04/15.
// Copyright (c) 2015 Alex Usbergo. All rights reserved.
//

#import "UIKit+REFL.h"
#import <objc/runtime.h>

static void *UIViewFlexContainerKey;

#pragma mark - UIView

@implementation UIView (REFLAdditions)

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

- (BOOL)refl_hasKey:(NSString*)key
{
    return [self respondsToSelector:NSSelectorFromString(key)];
}


@end

#pragma mark - UIScreen

@implementation UIScreen (RLFKAddtions)

- (CGRect)REFL_screenBounds
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

@implementation UIButton (REFLAdditions)

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

- (UIImage*)backgroundImage
{
    return [self backgroundImageForState:UIControlStateNormal];
}

- (void)setBackgroundImage:(UIImage*)backgroundImage
{
    [self setBackgroundImage:backgroundImage forState:UIControlStateNormal];
}

- (UIImage*)highlightedBackgroundImage
{
    return [self backgroundImageForState:UIControlStateHighlighted];
}

- (void)setHighlightedBackgroundImage:(UIImage*)highlightedBackgroundImage
{
    [self setBackgroundImage:highlightedBackgroundImage forState:UIControlStateHighlighted];
}

- (UIImage*)selectedBackgroundImage
{
    return [self backgroundImageForState:UIControlStateSelected];
}

- (void)setSelectedBackgroundImage:(UIImage*)selectedBackgroundImage
{
    [self setBackgroundImage:selectedBackgroundImage forState:UIControlStateSelected];
}

- (UIImage*)disabledBackgroundImage
{
    return [self backgroundImageForState:UIControlStateDisabled];
}

- (void)setDisabledBackgroundImage:(UIImage*)disabledBackgroundImage
{
    [self setBackgroundImage:disabledBackgroundImage forState:UIControlStateDisabled];
}

- (UIImage*)image
{
    return [self imageForState:UIControlStateNormal];
}

- (void)setImage:(UIImage*)image
{
    [self setImage:image forState:UIControlStateNormal];
}

- (UIImage*)highlightedImage
{
    return [self imageForState:UIControlStateHighlighted];
}

- (void)setHighlightedImage:(UIImage*)highlightedImage
{
    [self setImage:highlightedImage forState:UIControlStateHighlighted];
}

- (UIImage*)selectedImage
{
    return [self imageForState:UIControlStateSelected];
}

- (void)setSelectedImage:(UIImage*)selectedImage
{
    [self setImage:selectedImage forState:UIControlStateSelected];
}

- (UIImage*)disabledImage
{
    return [self imageForState:UIControlStateDisabled];
}

- (void)setDisabledImage:(UIImage*)disabledImage
{
    [self setImage:disabledImage forState:UIControlStateDisabled];
}

@end

#pragma mark - UIImage

@implementation UIImage (REFLAdditions)

+ (UIImage*)REFL_imageWithColor:(UIColor*)color
{
    return [self REFL_imageWithColor:color size:(CGSize){1,1}];
}

+ (UIImage*)REFL_imageWithColor:(UIColor*)color size:(CGSize)size
{
    CGRect rect = (CGRect){CGPointZero, size};
    UIGraphicsBeginImageContextWithOptions(size, NO, UIScreen.mainScreen.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

@end

@implementation NSObject (REFLAspects)

- (NSString*)refl_className
{
    return NSStringFromClass(self.class);
}

- (Class)refl_class
{
    return self.class;
}

@end

#pragma mark - UINotificationCenter

typedef void (^_REFLDeallocBlock)();

@interface NSObject (REFLAutoRemovalNotificationHelper)

@property (nonatomic, strong, setter=REFL_setDeallocContext:) id REFL_deallocContext;
- (void)REFL_setDeallocBlock:(_REFLDeallocBlock)block;

@end

@implementation NSObject (prmAutoRemovalNotification)

- (void)REFL_addObserverForName:(NSString*)name object:(id)obj queue:(NSOperationQueue*)queue usingBlock:(void (^)(NSNotification*))block
{
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:name object:obj queue:queue usingBlock:block];
    NSMutableArray *observers = [self REFL_deallocContext];
    
    if (observers == nil) {
        
        observers = @[].mutableCopy;
        [self REFL_setDeallocContext:observers];
        
        __weak typeof(self) weakSelf = self;
        [self REFL_setDeallocBlock:^{
            for (id o in weakSelf.REFL_deallocContext) [[NSNotificationCenter defaultCenter] removeObserver:o];
        }];
    }
    
    [observers addObject:observer];
}

- (void)REFL_addObserverForName:(NSString*)name usingBlock:(void (^)(NSNotification*))block
{
    [self REFL_addObserverForName:name object:nil queue:nil usingBlock:block];
}

@end


@interface _REFLDeallocBlockBox : NSObject

@property (nonatomic, retain) id context;
@property (nonatomic, copy) _REFLDeallocBlock block;

@end

static void *_REFLBlockBoxPropertyKey;
static void *_REFLObservervationAddedPropertyKey;


@implementation NSObject (prmAutoRemovalNotificationHelper)

- (id)REFL_deallocContext
{
    return [self REFL_box].context;
}

- (void)REFL_setDeallocContext:(id)context
{
    [self REFL_box].context = context;
}

- (void)REFL_setDeallocBlock:(_REFLDeallocBlock)block
{
    [self REFL_box].block = block;
}

- (_REFLDeallocBlockBox*)REFL_box
{
    _REFLDeallocBlockBox *box = objc_getAssociatedObject(self, &_REFLBlockBoxPropertyKey);
    
    if (box == nil) {
        box = [[_REFLDeallocBlockBox alloc] init];
        objc_setAssociatedObject(self, &_REFLBlockBoxPropertyKey, box, OBJC_ASSOCIATION_RETAIN);
    }
    
    return box;
}

- (void)setREFL_observationAdded:(BOOL)REFL_observationAdded
{
    objc_setAssociatedObject(self, &_REFLObservervationAddedPropertyKey, @(REFL_observationAdded), OBJC_ASSOCIATION_ASSIGN);
}

- (BOOL)REFL_observationAdded
{
    return [objc_getAssociatedObject(self, &_REFLObservervationAddedPropertyKey) boolValue];
}

@end

@implementation _REFLDeallocBlockBox

- (void)dealloc
{
    if (self.block) self.block();
}

@end
