//
//  RFLKPropertyValue.h
//  ReflektorKit
//
//  Created by Alex Usbergo on 21/04/15.
//  Copyright (c) 2015 Alex Usbergo. All rights reserved.
//

@import UIKit;

typedef NS_ENUM(NSInteger, RFLKExpressionLhs) {
    RFLKExpressionLhsSizeClassHorizontal,
    RFLKExpressionLhsSizeClassVertical,
    RFLKExpressionLhsSizeWidth,
    RFLKExpressionLhsSizeHeight,
    RFLKExpressionLhsIdiom
};

typedef NS_ENUM(NSInteger, RFLKExpressionOperator) {
    RFLKExpressionOperatorEqual,
    RFLKExpressionOperatorNotEqual,
    RFLKExpressionOperatorGreaterThan,
    RFLKExpressionOperatorGreaterOrEqualThan,
    RFLKExpressionOperatorLessThan,
    RFLKExpressionOperatorLessOrEqualThan
};

typedef NS_ENUM(NSInteger, RFLKExpressionRhs) {
    RFLKExpressionRhsRegular,
    RFLKExpressionRhsCompact,
    RFLKExpressionRhsConstant,
    RFLKExpressionRhsIdiomPad,
    RFLKExpressionRhsIdiomPhone
};

@interface RFLKExpression : NSObject

@property (nonatomic, readonly) NSString *expressionString;
@property (nonatomic, readonly) BOOL defaultExpression;
@property (nonatomic, readonly) RFLKExpressionLhs lhs;
@property (nonatomic, readonly) RFLKExpressionRhs rhs;
@property (nonatomic, readonly) RFLKExpressionOperator operator;
@property (nonatomic, readonly) CGFloat constant;

- (instancetype)initWithString:(NSString*)expressionString NS_DESIGNATED_INITIALIZER;

/// Returns 'YES' if the expression is satisfied within the trait collection passed as argument
/// and the bounds, 'NO' otherwise
- (BOOL)evaluateExpressionWithTraitCollection:(UITraitCollection*)traitCollection andBounds:(CGSize)bounds;

@end


@interface RFLKCondition : NSObject

@property (nonatomic, readonly) NSString *conditionString;

- (instancetype)initWithString:(NSString*)conditionString NS_DESIGNATED_INITIALIZER;

/// Returns 'YES' if all the expressions contained by this condition are satisfied within the trait collection passed as argument
/// and the bounds, 'NO' otherwise
- (BOOL)evaluatConditionWithTraitCollection:(UITraitCollection*)traitCollection andBounds:(CGSize)bounds;

@end

typedef NS_OPTIONS(NSInteger, RFLKPropertyValueOption) {
    RFLKPropertyValueOptionNone = 0,
    RFLKPropertyValueOptionPercentValue = 1 << 1,
    RFLKPropertyValueOptionLinearGradient = 1 << 2
};


@interface RFLKPropertyValue : NSObject

/// If YES this property must be computed and applied at layout time (when -[layoutSubviews] is called)
@property (nonatomic, assign) BOOL layoutTimeProperty;

- (instancetype)initWithString:(NSString*)propertyString NS_DESIGNATED_INITIALIZER;

/// Returns the value in the given context
- (id)valueWithTraitCollection:(UITraitCollection*)traitCollection andBounds:(CGSize)bounds;

@end

typedef NS_ENUM(NSInteger, RFLKSelectorType) {
    RFLKSelectorTypeClass,
    RFLKSelectorTypeTrait,
    RFLKSelectorTypeScope
};

@interface RFLKSelector : NSObject<NSCopying>

@property (nonatomic, readonly) NSUInteger selectorPriority;

/// What kind of selector this is
@property (nonatomic, readonly) RFLKSelectorType type;

/// If RFLKSelectorTypeClass or RFLKSelectorTypeClassWithAssociatedTraits this selector
/// will have an associated class
@property (nonatomic, readonly) Class associatedClass;

/// A list of strings representing the associated traits for this selector
@property (nonatomic, readonly) NSString *trait;

/// If RFLKSelectorTypeScope returns the name of the scope
@property (nonatomic, readonly) NSString *scopeName;

/// Not nil if the selector has a non-nil condition
@property (nonatomic, strong) RFLKCondition *condition;

/// The selector original string
@property (nonatomic, strong) NSString *selectorString;

- (instancetype)initWithString:(NSString*)selectorString NS_DESIGNATED_INITIALIZER;

/// Compare this selector priority with another one
- (NSComparisonResult)comparePriority:(RFLKSelector*)otherSelector;


@end


