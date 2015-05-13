//
// RFLKParser.h
// ReflektorKit
//
// Created by Alex Usbergo on 20/04/15.
// Copyright (c) 2015 Alex Usbergo. All rights reserved.
//

@import UIKit;

extern NSString *const RFLKTokenVariablePrefix;
extern NSString *const RFLKTokenImportantModifierSuffix;
extern NSString *const RFLKTokenConditionPrefix;
extern NSString *const RFLKTokenAppliesToSubclassesDirective;
extern NSString *const RFLKTokenSelectorSeparator;
extern NSString *const RFLKTokenConditionSeparator;
extern NSString *const RFLKTokenSeparator;
extern NSString *const RFLKTokenExpressionLessThan;
extern NSString *const RFLKTokenExpressionLessThanOrEqual;
extern NSString *const RFLKTokenExpressionEqual;
extern NSString *const RFLKTokenExpressionGreaterThan;
extern NSString *const RFLKTokenExpressionGreaterThanOrEqual;
extern NSString *const RFLKTokenExpressionNotEqual;

///Parse a payload and return a stylesheet dictionary
extern NSDictionary *rflk_parseStylesheet(NSString *stylesheet);

///Parse a right-hand side value for a property and put the result in 'returnValue'
extern void rflk_parseRhsValue(NSString *stringValue, id *returnValue, NSInteger *option, BOOL *layoutTimeProperty);

//Helpers

///Remove the quotation marks from a string
extern NSString *rflk_stripQuotesFromString(NSString *string);

///Convenience method for returning the absolute path for a file with the given extension
extern NSString *rflk_bundlePath(NSString *file, NSString *extension);
