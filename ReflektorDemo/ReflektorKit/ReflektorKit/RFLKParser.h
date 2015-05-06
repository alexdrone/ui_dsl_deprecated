//
//  RFLKParser.h
//  ReflektorKit
//
//  Created by Alex Usbergo on 20/04/15.
//  Copyright (c) 2015 Alex Usbergo. All rights reserved.
//

@import UIKit;

extern NSString *const RFLKTokenVariablePrefix;
extern NSString *const RFLKTokenConditionPrefix;
extern NSString *const RFLKTokenLayoutModifierSuffix;
extern NSString *const RFLKTokenSelectorSeparator;
extern NSString *const RFLKTokenConditionSeparator;
extern NSString *const RFLKTokenSeparator;
extern NSString *const RFLKTokenConditionPrefix;

extern NSString *const RFLKTokenExpressionLessThan;
extern NSString *const RFLKTokenExpressionLessThanOrEqual;
extern NSString *const RFLKTokenExpressionEqual;
extern NSString *const RFLKTokenExpressionGreaterThan;
extern NSString *const RFLKTokenExpressionGreaterThanOrEqual;
extern NSString *const RFLKTokenExpressionNotEqual;

extern NSDictionary *rflk_parseStylesheet(NSString *stylesheet);
extern void rflk_parseRhsValue(NSString *stringValue, id *returnValue, NSInteger *option, BOOL *layoutTimeProperty);
extern NSString *rflk_bundlePath(NSString *file, NSString *extension);

