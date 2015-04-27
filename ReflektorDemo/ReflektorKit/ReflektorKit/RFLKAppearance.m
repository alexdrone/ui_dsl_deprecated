//
//  RFLKAppearance.m
//  ReflektorKit
//
//  Created by Alex Usbergo on 22/04/15.
//  Copyright (c) 2015 Alex Usbergo. All rights reserved.
//

#import "RFLKAppearance.h"
#import <objc/runtime.h>
#import "Aspects.h"
#import "RFLKParser.h"
#import "RFLKParserItems.h"
#import "RFLKMacros.h"

NSString *RFLKApperanceStylesheetDidChangeNotification = @"RFLKApperanceStylesheetDidChangeNotification";

static const void *UIViewTraitsKey;
static const void *UIViewComputedPropertiesKey;

@implementation UIView (RFLKAppearance)

- (NSDictionary*)RFLK_computedProperties
{
    return objc_getAssociatedObject(self, &UIViewComputedPropertiesKey);
}

- (void)setRFLK_computedProperties:(NSDictionary*)RFLK_computedProperties
{
    objc_setAssociatedObject(self, &UIViewComputedPropertiesKey, RFLK_computedProperties, OBJC_ASSOCIATION_RETAIN);
}

- (NSSet*)RFLK_traits
{
    return objc_getAssociatedObject(self, &UIViewTraitsKey);
}

- (void)RFLK_addTrait:(NSString*)traitName
{
    NSMutableSet *set = objc_getAssociatedObject(self, &UIViewTraitsKey);
    
    if (set == nil)
        set = [[NSMutableSet alloc] init];
    
    [set addObject:traitName];
    
    objc_setAssociatedObject(self, &UIViewTraitsKey, set, OBJC_ASSOCIATION_RETAIN);
    [self setNeedsLayout];
}

- (void)RFLK_removeTrait:(NSString*)traitName
{
    NSMutableSet *set = objc_getAssociatedObject(self, &UIViewTraitsKey);
    
    if (set == nil)
        set = [[NSMutableSet alloc] init];
    
    [set removeObject:traitName];
    
    objc_setAssociatedObject(self, &UIViewTraitsKey, set, OBJC_ASSOCIATION_RETAIN);
    [self setNeedsLayout];
}

- (id)RFLK_property:(NSString*)propertyName
{
    return [self RFLK_property:propertyName withTraitCollection:[UIScreen mainScreen].traitCollection andBounds:[UIScreen mainScreen].bounds.size];
}

- (id)RFLK_property:(NSString*)propertyName withTraitCollection:(UITraitCollection*)traitCollection andBounds:(CGSize)size
{
    NSDictionary *computedProperties = self.RFLK_computedProperties;
    
    if (computedProperties == nil)
        computedProperties = [[RFLKAppearance sharedAppearance] computeStyleForView:self];
    
    if (computedProperties[propertyName] == nil)
        [NSException raise:[NSString stringWithFormat:@"Property not defined: %@", propertyName] format:nil];
    
    return [computedProperties[propertyName] valueWithTraitCollection:traitCollection andBounds:size];
}

- (void)RFLK_stylesheetDidChangeNotification:(id)notification
{
    [self setNeedsUpdateConstraints];
    [self setNeedsLayout];
}

@end

@interface RFLKAppearance ()

@property (nonatomic, strong) NSDictionary *propertyMap;
@property (nonatomic, strong) NSSet *classCache;

@end

@implementation RFLKAppearance

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        NSError *error;
        [UIView aspect_hookSelector:@selector(layoutSubviews) withOptions:AspectPositionBefore usingBlock:^(id<AspectInfo> aspectInfo) {
            
            UIView *_self = aspectInfo.instance;
            [[RFLKAppearance sharedAppearance] computeStyleForView:_self];
            
            if (_self.RFLK_computedProperties.count != 0) {
            
                for (NSString *key in _self.RFLK_computedProperties)
                    if ([_self respondsToSelector:NSSelectorFromString(key)]) {
                        
                        // compute the value and set it in the view
                        id value = [_self.RFLK_computedProperties[key] valueWithTraitCollection:_self.traitCollection andBounds:_self.bounds.size];
                        [_self setValue:value forKey:key];
                    }
            }
            
        } error:&error];
        
        [UIView aspect_hookSelector:@selector(didMoveToSuperview) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> aspectInfo) {
            
            UIView *_self = aspectInfo.instance;
            
            // triggers RFLK_stylesheetDidChangeNotification to be called when the stylesheet changes
            if (_self.superview != nil) {
                [[NSNotificationCenter defaultCenter] addObserver:_self selector:@selector(RFLK_stylesheetDidChangeNotification:) name:RFLKApperanceStylesheetDidChangeNotification object:nil];

            } else {
                [[NSNotificationCenter defaultCenter] removeObserver:self];
            }
            
        } error:&error];
        
    });
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
    self.propertyMap = RFLK_parseStylesheet(stylesheet);
    
    NSMutableSet *set = [[NSMutableSet alloc] init];
    
    // adds all the classes that have a style
    for (RFLKSelector *selector in self.propertyMap.allKeys)
        if (selector.associatedClass != nil)
            [set addObject:selector.associatedClass];
    
    self.classCache = set.copy;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:RFLKApperanceStylesheetDidChangeNotification object:nil];
}

- (NSDictionary*)computeStyleForClass:(Class)klass withTraits:(NSSet*)traits traitCollection:(UITraitCollection*)traitCollection bounds:(CGSize)bounds
{
    // there's no style defined for this class or the traits set passed as arg is empty
    if (!([self.classCache containsObject:klass] || traits.count > 0))
        return @{};
    
    NSMutableDictionary *computedProperties = @{}.mutableCopy;
    NSMutableArray *selectors = @[].mutableCopy;
    
    for (RFLKSelector *selector in self.propertyMap.allKeys) {
        
        switch (selector.type) {
                
            case RFLKSelectorTypeClass:
                if (selector.associatedClass == klass)
                    if (!selector.trait.length || (selector.trait.length && [traits containsObject:selector.trait]))
                        if (!selector.condition || (selector.condition && [selector.condition evaluatConditionWithTraitCollection:traitCollection andBounds:bounds]))
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
        if (obj1.selectorPriority < obj2.selectorPriority)
            return NSOrderedAscending;
        else
            return NSOrderedDescending;
    }];
    
    NSLog(@"selectors: %@", sortedSelectors);

    
    for (RFLKSelector *selector in sortedSelectors)
        for (NSString *key in self.propertyMap[selector])
            computedProperties[key] = self.propertyMap[selector][key];
    
    return computedProperties;
}



- (NSDictionary*)computeStyleForView:(UIView*)view
{
    NSDictionary *computedProperties = [self computeStyleForClass:view.class withTraits:view.RFLK_traits traitCollection:view.traitCollection bounds:[UIScreen mainScreen].bounds.size];
    view.RFLK_computedProperties = computedProperties;
    return computedProperties;
}

@end

id RFLK_computedProperty(UIView *view, NSString *propertyName)
{
    NSDictionary *computedProperties = view.RFLK_computedProperties;
    
    if (computedProperties == nil)
        computedProperties = [[RFLKAppearance sharedAppearance] computeStyleForView:view];
    
    NSCAssert(computedProperties[propertyName] != nil, @"property not defined");
    
    return [computedProperties[propertyName] valueWithTraitCollection:[UIScreen mainScreen].traitCollection andBounds:[UIScreen mainScreen].bounds.size];
}
