//
// RFLKPropertyValue.h
// ReflektorKit
//
// Created by Alex Usbergo on 21/04/15.
// Copyright (c) 2015 Alex Usbergo. All rights reserved.
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

///An expression is a term of a condition (e.g. 'idiom == pad' and ' width < 100' are two expressions in 'idiom == pad and width < 100')
@interface RFLKExpression : NSObject

///The original expression string (e.g. 'idiom == pad')
@property (nonatomic, readonly) NSString *expressionString;

///Wether this expression if a tautology ('default' in the stylesheet)
@property (nonatomic, readonly) BOOL tautology;

///The left-hand side term for this expression ('idiom', 'horizontal', 'vertical', 'width' and 'height' in the stylesheet)
@property (nonatomic, readonly) RFLKExpressionLhs lhs;

///The right-hand side term for this expression ('phone', 'pad', 'compact', 'regular' or a number)
@property (nonatomic, readonly) RFLKExpressionRhs rhs;

///The expression operator ('<','<=','==','!=','>=','>')
@property (nonatomic, readonly) RFLKExpressionOperator operator;

///If the Rhs is a number
@property (nonatomic, readonly) CGFloat constant;

///Initialise the expression object with a valid expression string (e.g. 'idiom == pad')
- (instancetype)initWithString:(NSString*)expressionString NS_DESIGNATED_INITIALIZER;

///Returns 'YES' if the expression is satisfied within the trait collection passed as argument
///and the bounds, 'NO' otherwise
- (BOOL)evaluateExpressionWithTraitCollection:(UITraitCollection*)traitCollection andBounds:(CGSize)bounds;

@end

///Object associated to a condition string (e.g. 'idiom == pad and width < 100')
@interface RFLKCondition : NSObject

///The original condition string
@property (nonatomic, readonly) NSString *conditionString;

///Create a condition object from a condition string (e,g, 'idiom == pad and width < 100')
- (instancetype)initWithString:(NSString*)conditionString NS_DESIGNATED_INITIALIZER;

///Returns 'YES' if all the expressions contained by this condition are satisfied within the trait collection passed as argument
///and the bounds, 'NO' otherwise
- (BOOL)evaluatConditionWithTraitCollection:(UITraitCollection*)traitCollection andBounds:(CGSize)bounds;

@end

typedef NS_OPTIONS(NSInteger, RFLKPropertyValueOption) {
    RFLKPropertyValueOptionNone = 0,
    RFLKPropertyValueOptionPercentValue = 1 << 1,
    RFLKPropertyValueOptionLinearGradient = 1 << 2,
    RFLKPropertyValueOptionImage = 1 << 3
};

///The object associated to a Rhs value
@interface RFLKPropertyValue : NSObject

///The original string that originated this object (e.g. font('Helvetica', 12px)
@property (nonatomic, strong, readonly) NSString *originalString;

///The resulting value (@see RFLKPropertyValueContainer)
@property (nonatomic, strong) id value;

///If YES this property must be computed and applied at layout time (when -[layoutSubviews] is called)
///This properties are the ones marked with !important
@property (nonatomic, assign) BOOL layoutTimeProperty;

///Creates a new Rhs value container from a valid rhs string (e.g. font('Helvetica', 12pt)
///@see rflk_parseRhsValue
- (instancetype)initWithString:(NSString*)propertyString NS_DESIGNATED_INITIALIZER;

///Returns the value in the given context
- (id)valueWithTraitCollection:(UITraitCollection*)traitCollection andBounds:(CGSize)bounds;

@end

typedef NS_ENUM(NSInteger, RFLKSelectorType) {
    RFLKSelectorTypeClass,
    RFLKSelectorTypeTrait,
    RFLKSelectorTypeScope
};

///This class represent a stylesheet selector (e.g Class:trait)
@interface RFLKSelector : NSObject<NSCopying>

///If this selector is of kind 'RFLKSelectorTypeClass', if this flag is YES then
///all the subclasses of 'associatedClass' will match this selector as wells
@property (nonatomic, assign) BOOL appliesToSubclasses;

///What kind of selector this is
@property (nonatomic, readonly) RFLKSelectorType type;

///If RFLKSelectorTypeClass or RFLKSelectorTypeClassWithAssociatedTraits this selector
///will have an associated class
@property (nonatomic, readonly) Class associatedClass;

///A list of strings representing the associated traits for this selector
@property (nonatomic, readonly) NSString *trait;

///If RFLKSelectorTypeScope returns the name of the scope
@property (nonatomic, readonly) NSString *scopeName;

///Not nil if the selector has a non-nil condition
@property (nonatomic, strong) RFLKCondition *condition;

///The selector original string
@property (nonatomic, strong) NSString *selectorString;

///The selector priority
@property (nonatomic, readonly) NSUInteger selectorPriority;

///Initialise the selector object from a well-formed stylesheet selector (e.g. Class:trait)
- (instancetype)initWithString:(NSString*)selectorString NS_DESIGNATED_INITIALIZER;

///Compare this selector priority with another one
- (NSComparisonResult)comparePriority:(RFLKSelector*)otherSelector;


@end


