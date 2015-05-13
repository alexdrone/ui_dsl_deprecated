//
//  RFLKAppearance.m
//  ReflektorKit
//
//  Created by Alex Usbergo on 22/04/15.
//  Copyright (c) 2015 Alex Usbergo. All rights reserved.
//

#import "RFLKAppearance.h"
#import <objc/runtime.h>
#import "RFLKAspects.h"
#import "RFLKParser.h"
#import "RFLKParserItems.h"
#import "RFLKMacros.h"
#import "UIKit+RFLKAdditions.h"
#import "RFLKWatchFileServer.h"
#import "UIView+FLEXBOX.h"

NSString *RFLKApperanceStylesheetDidChangeNotification = @"RFLKApperanceStylesheetDidChangeNotification";

static const void *UIViewTraitsKey;
static const void *UIViewComputedPropertiesKey;

@implementation UIView (RFLKAppearance)

- (NSDictionary*)rflk_computedProperties
{
    return objc_getAssociatedObject(self, &UIViewComputedPropertiesKey);
}

- (void)setRflk_computedProperties:(NSDictionary*)rflk_computedProperties
{
    objc_setAssociatedObject(self, &UIViewComputedPropertiesKey, rflk_computedProperties, OBJC_ASSOCIATION_RETAIN);
}

- (NSSet*)rflk_traits
{
    return objc_getAssociatedObject(self, &UIViewTraitsKey);
}

- (void)rflk_addTrait:(NSString*)traitName
{
    NSMutableSet *set = objc_getAssociatedObject(self, &UIViewTraitsKey);
    
    if (set == nil)
        set = [[NSMutableSet alloc] init];
    
    [set addObject:traitName];
    
    objc_setAssociatedObject(self, &UIViewTraitsKey, set, OBJC_ASSOCIATION_RETAIN);
    [self rflk_stylesheetDidChangeNotification:nil];
}

- (void)rflk_removeTrait:(NSString*)traitName
{
    NSMutableSet *set = objc_getAssociatedObject(self, &UIViewTraitsKey);
    
    if (set == nil)
        set = [[NSMutableSet alloc] init];
    
    [set removeObject:traitName];
    
    objc_setAssociatedObject(self, &UIViewTraitsKey, set, OBJC_ASSOCIATION_RETAIN);
    [self rflk_stylesheetDidChangeNotification:nil];
}

- (id)rflk_property:(NSString*)propertyName
{
    return [self rflk_property:propertyName withTraitCollection:[UIScreen mainScreen].traitCollection andBounds:[UIScreen mainScreen].rflk_screenBounds.size];
}

- (id)rflk_property:(NSString*)propertyName withTraitCollection:(UITraitCollection*)traitCollection andBounds:(CGSize)size
{
    NSDictionary *computedProperties = self.rflk_computedProperties;
    
    if (computedProperties == nil)
        computedProperties = [[RFLKAppearance sharedAppearance] computePropertiesForView:self];
    
    if (computedProperties[propertyName] == nil)
        [NSException raise:[NSString stringWithFormat:@"Property not defined: %@", propertyName] format:nil];
    
    return [computedProperties[propertyName] valueWithTraitCollection:traitCollection andBounds:size];
}

- (void)rflk_stylesheetDidChangeNotification:(id)notification
{
    self.rflk_computedProperties = [[RFLKAppearance sharedAppearance] computePropertiesForView:self];
    [self rflk_applyComputedStyle:self.rflk_computedProperties];
    [self setNeedsLayout];
}

- (void)rflk_applyComputedStyle:(NSDictionary*)computedStyle
{
    if (computedStyle.count != 0) {
        
        for (NSString *key in computedStyle)
            if ([self respondsToSelector:NSSelectorFromString(key)]) {
                
                // compute the value and set it in the view
                id value = [computedStyle[key] valueWithTraitCollection:self.traitCollection andBounds:self.bounds.size];
                if (![value isEqual:[self valueForKey:key]])
                    [self setValue:value forKey:key];
            }
    }
}

@end

@interface RFLKAppearance ()

// a map from selectors to a dictionary of properties
@property (nonatomic, strong) NSDictionary *properties;
@property (nonatomic, strong) NSDictionary *layoutProperties;

@end

@implementation RFLKAppearance

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        NSError *error;
        [UIView rflkAspect_hookSelector:@selector(layoutSubviews) withOptions:RFLKAspectPositionAfter usingBlock:^(id<RFLKAspectInfo> aspectInfo) {
            
            UIView *_self = aspectInfo.instance;
            NSDictionary *computedLayoutProperties = [[RFLKAppearance sharedAppearance] computeLayoutPropertiesForView:_self];
            
            // applies the properties that are marked as !important
            if (computedLayoutProperties.count != 0) {
                [_self rflk_applyComputedStyle:computedLayoutProperties];
            }
            
            // compute the flex layout if this view is a flex container
            if (_self.flexContainer)
                [_self flexLayoutSubviews];
            
        } error:&error];
        
        [UIView rflkAspect_hookSelector:@selector(didMoveToSuperview) withOptions:RFLKAspectPositionAfter usingBlock:^(id<RFLKAspectInfo> aspectInfo) {
            
            UIView *_self = aspectInfo.instance;
            
            if (!_self.rflk_observationAdded) {

                // triggers rflk_stylesheetDidChangeNotification to be called when the stylesheet changes
                _self.rflk_observationAdded = YES;
                [_self rflk_addObserverForName:RFLKApperanceStylesheetDidChangeNotification usingBlock:^(NSNotification *note) {
                    [_self rflk_stylesheetDidChangeNotification:note];
                }];
                
                //applies the stylesheet on the next runloop
                __weak __typeof(_self) weakSelf = _self;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [weakSelf rflk_stylesheetDidChangeNotification:nil];
                });
            }
            
        } error:&error];
    });
    
#ifdef DEBUG
    [[RFLKWatchFileServer sharedInstance] startOnPort:RFLKWatchFileServerDefaultPort];
#endif
}

+ (instancetype)sharedAppearance
{ 
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)parseStylesheetData:(NSString*)stylesheet
{
    self.properties = rflk_parseStylesheet(stylesheet);
    [[NSNotificationCenter defaultCenter] postNotificationName:RFLKApperanceStylesheetDidChangeNotification object:nil userInfo:@{}];
    
    // filter out the !layout properties
    NSMutableDictionary *layoutProperties = @{}.mutableCopy;
    for (RFLKSelector *selector in self.properties.allKeys)
        for (NSString *propertyKey in [self.properties[selector] allKeys]) {
            
            RFLKPropertyValue *value = self.properties[selector][propertyKey];
            if (value.layoutTimeProperty) {
                
                // creates a container for the selector
                if (layoutProperties[selector] == nil)
                    layoutProperties[selector] = @{}.mutableCopy;
                
                layoutProperties[selector][propertyKey] = value;
            }
        }
    
    self.layoutProperties = layoutProperties.copy;
}

- (NSDictionary*)computeStyleFromDictionary:(NSDictionary*)properties forClass:(Class)klass withTraits:(NSSet*)traits traitCollection:(UITraitCollection*)traitCollection bounds:(CGSize)bounds
{    
    NSMutableDictionary *computedProperties = @{}.mutableCopy;
    NSMutableArray *selectors = @[].mutableCopy;
    
    for (RFLKSelector *selector in properties.allKeys) {
        
        switch (selector.type) {
                
            case RFLKSelectorTypeClass:
                if (selector.associatedClass == klass || (selector.appliesToSubclasses && [klass isSubclassOfClass:selector.associatedClass]))
                    if (!selector.trait.length || (selector.trait.length && [traits containsObject:selector.trait]))
                        if (!selector.condition || (selector.condition && [selector.condition evaluatConditionWithTraitCollection:traitCollection andBounds:[UIScreen mainScreen].rflk_screenBounds.size]))
                            [selectors addObject:selector];
                break;
                
            case RFLKSelectorTypeTrait:
                if ([traits containsObject:selector.trait])
                    [selectors addObject:selector];
                break;
                
            default:
                break;
        }
    }
    
    //selector priorities: RFLKSelectorTypeClass > RFLKSelectorTypeTrait > RFLKSelectorTypeClassWithAssociatedTrait
    NSArray *sortedSelectors = [selectors sortedArrayUsingComparator:^NSComparisonResult(RFLKSelector *obj1, RFLKSelector *obj2) {
        return [obj1 comparePriority:obj2];
    }];

    
    for (RFLKSelector *selector in sortedSelectors)
        for (NSString *key in properties[selector])
            computedProperties[key] = properties[selector][key];
    
    return computedProperties;
}

- (NSDictionary*)computePropertiesForView:(UIView*)view
{
    NSDictionary *computedProperties = [self computeStyleFromDictionary:self.properties forClass:view.class withTraits:view.rflk_traits traitCollection:view.traitCollection bounds:view.bounds.size];
    view.rflk_computedProperties = computedProperties;
    return computedProperties;
}

- (NSDictionary*)computeLayoutPropertiesForView:(UIView*)view
{
    NSDictionary *computedLayoutProperties = [self computeStyleFromDictionary:self.layoutProperties forClass:view.class withTraits:view.rflk_traits traitCollection:view.traitCollection bounds:view.bounds.size];
    
    NSMutableDictionary *computedProperties = view.rflk_computedProperties.mutableCopy;
    for (NSString *key in computedLayoutProperties)
        computedProperties[key] = computedProperties[key];
    
    view.rflk_computedProperties = computedProperties;
    return computedLayoutProperties;
}

@end

id rflk_computedProperty(UIView *view, NSString *propertyName)
{
    NSDictionary *computedProperties = view.rflk_computedProperties;
    
    if (computedProperties == nil)
        computedProperties = [[RFLKAppearance sharedAppearance] computePropertiesForView:view];
    
    NSCAssert(computedProperties[propertyName] != nil, @"property not defined");
    
    return [computedProperties[propertyName] valueWithTraitCollection:[UIScreen mainScreen].traitCollection andBounds:view.bounds.size];
}
