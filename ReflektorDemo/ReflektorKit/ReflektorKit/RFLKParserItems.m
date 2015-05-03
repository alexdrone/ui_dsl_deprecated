//
//  RFLKPropertyValue.m
//  ReflektorKit
//
//  Created by Alex Usbergo on 21/04/15.
//  Copyright (c) 2015 Alex Usbergo. All rights reserved.
//

#import "RFLKParserItems.h"
#import "RFLKParser.h"
#import "UIColor+HTMLColors.h"
#import "UIKit+RFLKAdditions.h"

#pragma mark - RFLKPropertyValueContainer

@interface RFLKPropertyValueContainer : NSObject

@property (nonatomic, assign) RFLKPropertyValueOption option;
@property (nonatomic, strong) id value;

- (instancetype)initWithValue:(id)value option:(RFLKPropertyValueOption)option NS_DESIGNATED_INITIALIZER;

@end

@implementation RFLKPropertyValueContainer

- (instancetype)initWithValue:(id)value option:(RFLKPropertyValueOption)option
{
    if (self = [super init]) {
        _value = value;
        _option = option;
    }
    
    return self;
}

@end

#pragma mark - RFLKExpression

@implementation RFLKExpression

- (instancetype)initWithString:(NSString*)expressionString
{
    if (self = [super init]) {
        
        _expressionString = expressionString;
        _constant = 0;
        
        static NSString *const defaultExpression = @"default";
        
        if ([expressionString containsString:defaultExpression]) {
            _defaultExpression = YES;
            
        } else {
            
            NSArray *operands = @[];
            
            if ([expressionString containsString:RFLKTokenExpressionEqual]) {
                operands = [expressionString componentsSeparatedByString:RFLKTokenExpressionEqual];
                _operator = RFLKExpressionOperatorEqual;
                
            } else if ([expressionString containsString:RFLKTokenExpressionNotEqual]) {
                operands = [expressionString componentsSeparatedByString:RFLKTokenExpressionNotEqual];
                _operator = RFLKExpressionOperatorNotEqual;
                
            } else if ([expressionString containsString:RFLKTokenExpressionLessThan]) {
                operands = [expressionString componentsSeparatedByString:RFLKTokenExpressionLessThan];
                _operator = RFLKExpressionOperatorLessThan;
                
            } else if ([expressionString containsString:RFLKTokenExpressionLessThanOrEqual]) {
                operands = [expressionString componentsSeparatedByString:RFLKTokenExpressionLessThanOrEqual];
                _operator = RFLKExpressionOperatorLessOrEqualThan;
                
            } else if ([expressionString containsString:RFLKTokenExpressionGreaterThan]) {
                operands = [expressionString componentsSeparatedByString:RFLKTokenExpressionGreaterThan];
                _operator = RFLKExpressionOperatorGreaterThan;
                
            } else if ([expressionString containsString:RFLKTokenExpressionGreaterThanOrEqual]) {
                operands = [expressionString componentsSeparatedByString:RFLKTokenExpressionGreaterThanOrEqual];
                _operator = RFLKExpressionOperatorGreaterOrEqualThan;
            }
            
            NSString *lhsString = operands[0];
            
            static NSString *const lhsHorizontal = @"horizontal";
            static NSString *const lhsVertical = @"vertical";
            static NSString *const lhsWidth = @"width";
            static NSString *const lhsHeight = @"height";
            static NSString *const lhsIdiom = @"height";
            
            if ([lhsString containsString:lhsHorizontal])
                _lhs = RFLKExpressionLhsSizeClassHorizontal;
            
            else if ([lhsString containsString:lhsVertical])
                _lhs = RFLKExpressionLhsSizeClassVertical;
            
            else if ([lhsString containsString:lhsWidth])
                _lhs = RFLKExpressionLhsSizeWidth;
            
            else if ([lhsString containsString:lhsHeight])
                _lhs = RFLKExpressionLhsSizeHeight;
            
            else if ([lhsString containsString:lhsIdiom])
                _lhs = RFLKExpressionLhsIdiom;
            
            NSString *rhsString = operands[1];
            
            static NSString *const rhsRegular = @"regular";
            static NSString *const rhsCompact = @"compact";
            static NSString *const rhsIdiomPad = @"pad";
            static NSString *const rhsIdiomPhone = @"phone";
            
            if ([rhsString containsString:rhsRegular])
                _rhs = RFLKExpressionRhsRegular;
            
            else if ([rhsString containsString:rhsCompact])
                _rhs = RFLKExpressionRhsCompact;
            
            else if ([rhsString containsString:rhsIdiomPad])
                _rhs = RFLKExpressionRhsIdiomPad;
            
            else if ([rhsString containsString:rhsIdiomPhone])
                _rhs = RFLKExpressionRhsIdiomPhone;
            
            else {
                _rhs = RFLKExpressionRhsConstant;
                _constant = [rhsString floatValue];
            }
        }
    }
    
    return self;
}

- (BOOL)evaluateExpressionWithTraitCollection:(UITraitCollection*)traitCollection andBounds:(CGSize)bounds
{
    if (self.defaultExpression)
        return YES;
    
    switch (self.lhs) {
        case RFLKExpressionLhsSizeClassHorizontal:
            return [self compareSizeClassesWithLhs:traitCollection.horizontalSizeClass
                                               rhs:self.rhs == RFLKExpressionRhsRegular ? UIUserInterfaceSizeClassRegular : UIUserInterfaceSizeClassCompact];
            
        case RFLKExpressionLhsSizeClassVertical:
            return [self compareSizeClassesWithLhs:traitCollection.verticalSizeClass
                                               rhs:self.rhs == RFLKExpressionRhsRegular ? UIUserInterfaceSizeClassRegular : UIUserInterfaceSizeClassCompact];

        case RFLKExpressionLhsSizeWidth:
            return [self compareConstantWithLhs:bounds.width rhs:self.constant];
            
        case RFLKExpressionLhsSizeHeight:
            return [self compareConstantWithLhs:bounds.height rhs:self.constant];

        case RFLKExpressionLhsIdiom: {
            
            UIUserInterfaceIdiom idiom = [UIDevice currentDevice].userInterfaceIdiom;
            
            if ((idiom == UIUserInterfaceIdiomPad && self.rhs == RFLKExpressionRhsIdiomPad) ||
                (idiom == UIUserInterfaceIdiomPhone && self.rhs == RFLKExpressionRhsIdiomPhone) )
                return YES;
            
            else
                return NO;
        }
    }
    
    return NO;
}

- (BOOL)compareSizeClassesWithLhs:(UIUserInterfaceSizeClass)lhs rhs:(UIUserInterfaceSizeClass)rhs
{
    switch (self.operator) {
        case RFLKExpressionOperatorEqual:
            return lhs == rhs;
            break;
        case RFLKExpressionOperatorNotEqual:
            return lhs != rhs;
            break;
        case RFLKExpressionOperatorGreaterThan:
        case RFLKExpressionOperatorGreaterOrEqualThan:
        case RFLKExpressionOperatorLessThan:
        case RFLKExpressionOperatorLessOrEqualThan:
            return NO;
    }
}

- (BOOL)compareConstantWithLhs:(CGFloat)lhs rhs:(CGFloat)rhs
{
    switch (self.operator) {
        case RFLKExpressionOperatorEqual:
            return fabs(lhs - rhs) < FLT_EPSILON;

        case RFLKExpressionOperatorNotEqual:
            return fabs(lhs - rhs) > FLT_EPSILON;
            
        case RFLKExpressionOperatorGreaterThan:
            return lhs > rhs;
            
        case RFLKExpressionOperatorGreaterOrEqualThan:
            return lhs >= rhs;
            
        case RFLKExpressionOperatorLessThan:
            return lhs < rhs;
            
        case RFLKExpressionOperatorLessOrEqualThan:
            return lhs <= rhs;
    }
}

- (id)copyWithZone:(NSZone*)zone
{
    RFLKExpression *expression = [[RFLKExpression alloc] initWithString:self.expressionString];
    return expression;
}

- (NSUInteger)hash
{
    return self.expressionString.hash;
}

@end

#pragma mark - RFLKCondition

@interface RFLKCondition ()

// holds on to all the expressions (expr1 and expr2 and ...)
@property (nonatomic, strong) NSArray *expressions;

@end

@implementation RFLKCondition

- (instancetype)initWithString:(NSString*)originalString
{
    if (self = [super init]) {
        
        _conditionString = originalString;
        
        NSMutableArray *conditions = @[].mutableCopy;
        NSArray *expressions = [originalString componentsSeparatedByString:RFLKTokenConditionSeparator];

        for (NSString *expr in expressions)
            [conditions addObject:[[RFLKExpression alloc] initWithString:expr]];
            
        self.expressions = expressions;
    }
    
    return self;
}

- (BOOL)evaluatConditionWithTraitCollection:(UITraitCollection *)traitCollection andBounds:(CGSize)bounds
{
    return YES;
    
    BOOL satisfied = YES;
    for (RFLKExpression *expr in self.expressions) {
        satisfied &= [expr evaluateExpressionWithTraitCollection:traitCollection andBounds:bounds];
    }
    
    return satisfied;
}

- (id)copyWithZone:(NSZone*)zone
{
    RFLKCondition *condition = [[RFLKCondition alloc] initWithString:self.conditionString];
    return condition;
}

- (NSUInteger)hash
{
    return self.conditionString.hash;
}

- (NSString*)description
{
    return self.conditionString;
}

@end

#pragma mark - RFLKPropertyValue

@interface RFLKPropertyValue ()

@property (nonatomic, strong, readonly) NSString *originalString;
@property (nonatomic, strong) id value;

@end

@implementation RFLKPropertyValue

- (instancetype)initWithString:(NSString*)propertyString
{
    if (self = [super init]) {
        
        _originalString = propertyString;
        
        id value = NSNull.null;
        RFLKPropertyValueOption option = RFLKPropertyValueOptionNone;
        rflk_parseRhsValue(propertyString, &value, &option);
        _value = [[RFLKPropertyValueContainer alloc] initWithValue:value option:option];
    }
    
    return self;
}

- (id)valueWithTraitCollection:(UITraitCollection*)traitCollection andBounds:(CGSize)bounds
{
    id (^valueFromValueContainer)(RFLKPropertyValueContainer *container) = ^id(RFLKPropertyValueContainer *container) {
    
        CGFloat min = MIN(bounds.width, bounds.height);
        
        // % measure unit
        if (container.option & RFLKPropertyValueOptionPercentValue) {
            
            // number
            if ([container.value isKindOfClass:NSNumber.class]) {
                CGFloat percent = [container.value floatValue];
                return @((percent/100)*min);
                
            // font size
            } else if ([container.value isKindOfClass:UIFont.class]) {
                CGFloat percent = [container.value pointSize];
                return [UIFont fontWithName:[container.value fontName] size:(percent/100)*min];
            }
        }
        
        // linear-gradient
        if (container.option & RFLKPropertyValueOptionLinearGradient) {
            NSAssert([container.value isKindOfClass:NSArray.class], nil);
            return [UIColor gradientFromColor:container.value[0] toColor:container.value[1] withSize:bounds];
        }
        
        return container.value;
    };
    
    return valueFromValueContainer(((RFLKPropertyValueContainer*)self.value));
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"%@ -> %@>", NSStringFromClass(self.class), [self valueWithTraitCollection:[UIScreen mainScreen].traitCollection andBounds:[UIScreen mainScreen].rflk_screenBounds.size]];
}

@end

#pragma mark - RFLKSelector

@implementation RFLKSelector

- (instancetype)initWithString:(NSString*)selectorString
{
    if (self = [super init]) {
        
        _selectorString = selectorString;
        
        // the string is assumed to be legal selector
        // @see rflk_isValidSelector
        
        NSArray *components = [selectorString componentsSeparatedByString:RFLKTokenSelectorSeparator];
        NSString *selector = components.firstObject;
        
        if ([selector hasPrefix:RFLKTokenTraitPrefix]) {
            _type = RFLKSelectorTypeTrait;
            _trait = [selector stringByReplacingOccurrencesOfString:RFLKTokenTraitPrefix withString:@""];
            
        } else if ([selector hasPrefix:RFLKTokenVariablePrefix]) {
            _type = RFLKSelectorTypeScope;
            _scopeName =[selector stringByReplacingOccurrencesOfString:RFLKTokenVariablePrefix withString:@""];
            
        } else if ([selector hasPrefix:RFLKTokenClassPrefix]) {
            _type = RFLKSelectorTypeClass;
            
            NSString *className = [selector stringByReplacingOccurrencesOfString:RFLKTokenClassPrefix withString:@""];
            NSAssert(NSClassFromString(className) != nil, @"invalid class name");
            
            _associatedClass = NSClassFromString(className);
        }
        
        if (components.count > 1) {
            NSAssert(_type == RFLKSelectorTypeClass, @"if it's a compound selector, the base selector should be a class");
            
            if ([components[1] hasPrefix:RFLKTokenTraitPrefix])
                _trait = [components[1] stringByReplacingOccurrencesOfString:RFLKTokenTraitPrefix withString:@""];
        }
        
    }
    
    return self;
}

- (BOOL)isEqual:(id)object
{
    RFLKSelector *otherSelector = object;
    
    if ((self == otherSelector) ||
        (self.hash == otherSelector.hash))
        return YES;
    
    return NO;
}

- (NSUInteger)hash
{
    return self.trait.hash ^ NSStringFromClass(self.associatedClass).hash ^ self.scopeName.hash ^ self.condition.hash;
}

- (id)copyWithZone:(NSZone *)zone
{
    RFLKSelector *selector = [[RFLKSelector alloc] init];
    selector->_associatedClass = [_associatedClass copy];
    selector->_type = _type;
    selector->_trait = [_trait copyWithZone:zone];
    selector->_scopeName = [_scopeName copyWithZone:zone];
    selector->_condition = [_condition copyWithZone:zone];
    
    return selector;
}

- (NSString*)description
{
    switch (self.type) {
        case RFLKSelectorTypeClass:
            return [NSString stringWithFormat:@"<RFLKSelectorTypeClass class: %@ trait: %@ condition: %@>", NSStringFromClass(self.associatedClass), self.trait, self.condition];
            
        case RFLKSelectorTypeTrait:
            return [NSString stringWithFormat:@"<RFLKSelectorTypeTrait trait: %@>", self.trait];
            
        case RFLKSelectorTypeScope:
            return [NSString stringWithFormat:@"<RFLKSelectorTypeScope scope: %@>", self.scopeName];
    }
}

- (NSUInteger)selectorPriority
{
    NSUInteger priority = 0;
    
    if (!self.associatedClass && self.trait.length && self.condition)
        priority = 1;
 
    if (self.associatedClass && self.trait.length && !self.condition)
        priority = 2;
    
    if (!self.associatedClass && self.trait.length && !self.condition)
        priority = 3;
    
    if (self.associatedClass && !self.trait.length && self.condition)
        priority = 4;
    
    if (self.associatedClass && !self.trait.length && !self.condition)
        priority = 5;
    
    return NSUIntegerMax-priority;
}

@end



