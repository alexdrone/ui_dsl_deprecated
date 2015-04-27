//
//  RFLKParser.m
//  ReflektorKit
//
//  Created by Alex Usbergo on 20/04/15.
//  Copyright (c) 2015 Alex Usbergo. All rights reserved.
//

#import "RFLKParser.h"
#import "CSSParser.h"
#import "RFLKMacros.h"
#import "UIColor+HTMLColors.h"
#import "RFLKParserItems.h"
#import "UIKit+RFLKAdditions.h"

void    RFLK_flattenInheritance(NSMutableDictionary *dictionary, NSString *key);
BOOL    RFLK_isValidSelector(NSString *selector, BOOL constrainedToTrait);

NSString *const RFLKTokenClassPrefix = @"class";
NSString *const RFLKTokenTraitPrefix = @"trait";
NSString *const RFLKTokenVariablePrefix = @"-var";
NSString *const RFLKTokenSelectorSeparator = @".";
NSString *const RFLKTokenSeparator = @",";
NSString *const RFLKTokenConditionSeparator = @"and";
NSString *const RFLKTokenConditionPrefix = @"condition";

NSString *const RFLKTokenExpressionLessThan = @"<";
NSString *const RFLKTokenExpressionLessThanOrEqual = @"<=";
NSString *const RFLKTokenExpressionEqual = @"=";
NSString *const RFLKTokenExpressionGreaterThan = @">";
NSString *const RFLKTokenExpressionGreaterThanOrEqual = @">=";
NSString *const RFLKTokenExpressionNotEqual = @"!=";

NSString *const RFLKTokenInclude = @"include";

#pragma mark - Private functions

NSArray *RFLK_getArgumentForValue(NSString* stringValue)
{
    NSCParameterAssert(stringValue);
    NSArray *components = [stringValue componentsSeparatedByString:@"("];
    NSString *arguments = [components[1] substringToIndex:[components[1]  length] - 1];
    
    NSMutableArray *result = @[].mutableCopy;
    
    for (NSString *argument in [arguments componentsSeparatedByString:RFLKTokenSeparator]) {
        NSString *arg = [argument stringByReplacingOccurrencesOfString:@"\"" withString:@""];
        arg = [arg stringByReplacingOccurrencesOfString:@"'" withString:@""];
        [result addObject:arg];
    }
    
    return result;
}

void RFLK_assertOnMalformedValue(NSArray *arguments, NSInteger count, NSString *type, NSString *format)
{
    NSCAssert(arguments.count == count, @"Malformed %@ value. Expected format: %@", type, format);
}

void RFLK_flattenInheritance(NSMutableDictionary *dictionary, NSString *key)
{
    NSCParameterAssert(dictionary);
    NSCParameterAssert(key);

    NSString *inherit = dictionary[key][RFLKTokenInclude];
    
    if (inherit == nil)
        return;
 
    NSArray *components = [inherit componentsSeparatedByString:RFLKTokenSeparator];
    
    for (NSString *inheritedKey in components)
        RFLK_flattenInheritance(dictionary, inheritedKey);
    
    NSMutableDictionary *newValuesForSelector = [dictionary[key] mutableCopy];
    [newValuesForSelector removeObjectForKey:RFLKTokenInclude];
    
    for (NSString *inheritedKey in components)
        for (NSString *property in [dictionary[inheritedKey] allKeys])
            
            if (newValuesForSelector[property] == nil)
                newValuesForSelector[property] = dictionary[inheritedKey][property];
    
    dictionary[key] = newValuesForSelector;
}

BOOL RFLK_isValidSelector(NSString *selector, BOOL constrainedToTrait)
{
    NSCParameterAssert(selector);
    
    if ([selector hasPrefix:RFLKTokenTraitPrefix])
        return YES;
    
    if([selector hasPrefix:RFLKTokenConditionPrefix])
        return YES;
    
    if (!constrainedToTrait) {
    
        if ([selector hasPrefix:RFLKTokenClassPrefix])
            return YES;

        if ([selector hasPrefix:RFLKTokenVariablePrefix])
            return YES;
    }

    RFLKLog(@"Invalid selector: %@", selector);
    
    return NO;
}

NSString *RFLK_stringToCamelCase(NSString *string)
{
    NSMutableString *output = [NSMutableString string];
    BOOL makeNextCharacterUpperCase = NO;
    for (NSInteger i = 0; i < string.length; i++) {
        
        unichar c = [string characterAtIndex:i];
        
        if (c == '-') {
            makeNextCharacterUpperCase = YES;
        } else if (makeNextCharacterUpperCase) {
            [output appendString:[[NSString stringWithCharacters:&c length:1] uppercaseString]];
            makeNextCharacterUpperCase = NO;
        } else {
            [output appendFormat:@"%C", c];
        }
    }
    return output;
}


#pragma mark - Public functions

NSString *RFLK_bundlePath(NSString *file, NSString *extension)
{
    NSString *const resourcePath = @"Frameworks/ReflektorKit.framework/";
    NSString *path = [[NSBundle mainBundle] pathForResource:file ofType:extension];
    
    if (!path)
        path = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"%@%@", resourcePath, file] ofType:extension];
    
    return path;
}

BOOL RFLK_checkForPresenceOfOptionInString(NSString *string, RFLKPropertyValueOption option)
{
    switch (option) {
        case RFLKPropertyValueOptionNone:
            return YES;
            break;
            
        case RFLKPropertyValueOptionPercentValue:
            return [string containsString:@"%"];
            
        default:
            break;
    }
}

void RFLK_parseRhsValue(NSString *stringValue, id *returnValue, NSInteger *option)
{
    NSCParameterAssert(stringValue);
    NSCAssert(![stringValue hasPrefix:RFLKTokenConditionPrefix], @"This can't be a condition value.");
    
    id value = stringValue;
    
    float numericValue;
    NSScanner *scan = [NSScanner scannerWithString:stringValue];
    
    if ([scan scanFloat:&numericValue]) {
        value = [NSNumber numberWithFloat:numericValue];
        (*option) = RFLK_checkForPresenceOfOptionInString(stringValue, RFLKPropertyValueOptionPercentValue) ? RFLKPropertyValueOptionPercentValue : RFLKPropertyValueOptionNone;

    } else if ([stringValue isEqualToString:@"true"] || [stringValue isEqualToString:@"false"]) {
        value = [stringValue isEqualToString:@"true"] ? [NSNumber numberWithBool:YES] : [NSNumber numberWithBool:NO];
        
    } else if ([stringValue hasPrefix:@"'"] || [stringValue hasPrefix:@"\""]) {
        value = [stringValue stringByReplacingOccurrencesOfString:@"\"" withString:@""];
        value = [value stringByReplacingOccurrencesOfString:@"'" withString:@""];
        
    } else if ([stringValue hasPrefix:@"rgb"] || [stringValue hasPrefix:@"hsl"] || [stringValue hasPrefix:@"rgba"] || [stringValue hasPrefix:@"hsla"] || [stringValue hasPrefix:@"#"]) {
        value = [UIColor colorWithCSS:stringValue];
        
    } else {
        
        NSArray *arguments = nil;
        
        @try {
            arguments = RFLK_getArgumentForValue(stringValue);
        }
        @catch (NSException *exception) {
            [NSException raise:[NSString stringWithFormat:@"Unable to parse right-hand side value: %@", stringValue] format:nil];
        }

        if ([stringValue hasPrefix:@"font"]) {
            RFLK_assertOnMalformedValue(arguments, 2, @"font", @"font('font postscript name', size)");
            value = [UIFont fontWithName:arguments[0] size:[arguments[1] floatValue]];
            (*option) = RFLK_checkForPresenceOfOptionInString(arguments[1], RFLKPropertyValueOptionPercentValue) ? RFLKPropertyValueOptionPercentValue : RFLKPropertyValueOptionNone;
            
        } else if ([stringValue hasPrefix:@"locale"]) {
            RFLK_assertOnMalformedValue(arguments, 1, @"locale", @"locale('KEY')");
            value = NSLocalizedString(arguments[0], nil);
            
        } else if ([stringValue hasPrefix:@"rect"]) {
            RFLK_assertOnMalformedValue(arguments, 4, @"rect", @"rect(x, y, width, height)");
            value = [NSValue valueWithCGRect:(CGRect){{[arguments[0] floatValue], [arguments[1] floatValue]}, {[arguments[2] floatValue], [arguments[3] floatValue]}}];
            
        } else if ([stringValue hasPrefix:@"point"]) {
            RFLK_assertOnMalformedValue(arguments, 2, @"point", @"point(x, y)");
            value = [NSValue valueWithCGPoint:(CGPoint){[arguments[0] floatValue], [arguments[1] floatValue]}];
            
        } else if ([stringValue hasPrefix:@"size"]) {
            RFLK_assertOnMalformedValue(arguments, 2, @"size", @"size(width, height)");
            value = [NSValue valueWithCGSize:(CGSize){[arguments[0] floatValue], [arguments[1] floatValue]}];
            
        } else if ([stringValue hasPrefix:@"affine-transform-scale"]) {
            RFLK_assertOnMalformedValue(arguments, 2, @"affine-transform-scale", @"affine-transform-scale(x, y)");
            value = [NSValue valueWithCGAffineTransform:CGAffineTransformMakeScale([arguments[0] floatValue], [arguments[1] floatValue])];
            
        } else if ([stringValue hasPrefix:@"affine-transform-rotation"]) {
            RFLK_assertOnMalformedValue(arguments, 1, @"affine-transform-rotation", @"affine-transform-rotation(angle)");
            value = [NSValue valueWithCGAffineTransform:CGAffineTransformMakeRotation([arguments[0] floatValue])];
            
        } else if ([stringValue hasPrefix:@"affine-transform-translation"]) {
            RFLK_assertOnMalformedValue(arguments, 2, @"affine-transform-translation", @"affine-transform-translation(x, y)");
            value = [NSValue valueWithCGAffineTransform:CGAffineTransformMakeTranslation([arguments[0] floatValue], [arguments[1] floatValue])];
            
        } else if ([stringValue hasPrefix:@"edge-insets"]) {
            RFLK_assertOnMalformedValue(arguments, 4, @"edge-insets", @"edge-insets(top, bottom, width, height)");
            value = [NSValue valueWithUIEdgeInsets:(UIEdgeInsets){[arguments[0] floatValue], [arguments[1] floatValue], [arguments[2] floatValue], [arguments[3] floatValue]}];
            
        } else if ([stringValue hasPrefix:@"vector"]) {
            
            NSMutableArray *array = @[].mutableCopy;
            for (NSString *c in arguments) {
                
                // rescursively parsing the vector component
                id cv;
                RFLK_parseRhsValue(c, &cv, option);
                [array addObject:cv];
            }
            
            value = array;
            
        } else  {
            RFLKLog(@"unsupported value: %@", stringValue);
            value = [NSNull null];
        }
    }
    
    (*returnValue) = value;
}


NSString *RFLK_uuid()
{
    // Returns a UUID
    static const NSString *letters = @"abcdefghijklmnopqrstuvwxyz";
    static const u_int32_t lenght = 16;

    NSMutableString *randomString = [NSMutableString stringWithCapacity:lenght];
    
    for (int i = 0; i < lenght; i++)
        [randomString appendFormat: @"%C", [letters characterAtIndex: arc4random_uniform([letters length])]];
    
    return randomString;
}

//TODO: Add these to the lexer
void RFLK_replaceSymbolsInStylesheet(NSString **stylesheet)
{
    NSString *s = (*stylesheet);
    
    s = [s stringByReplacingOccurrencesOfString:@"@" withString:RFLKTokenVariablePrefix];
    s = [s stringByReplacingOccurrencesOfString:@".?" withString:[NSString stringWithFormat:@".%@:%@", RFLKTokenConditionPrefix, RFLK_uuid()]];
    (*stylesheet) = s;
}


NSDictionary *RFLK_parseStylesheet(NSString *stylesheet)
{
    CSSParser *parser = [[CSSParser alloc] init];
    
    NSDictionary *dictionary;
    
    //
    // parse
    //
    {
        RFLK_replaceSymbolsInStylesheet(&stylesheet);
        dictionary = [parser parseText:stylesheet];
    }
    
    NSMutableDictionary *res = dictionary.mutableCopy;

    //
    // sanity check
    //
    {
        
        BOOL wellformed = YES;
        
        for (NSString *key in res.allKeys) {
            
            BOOL valid = YES;
            NSInteger constrainedToTrait = 0;
            for (NSString *selector in [key componentsSeparatedByString:RFLKTokenSelectorSeparator])
                valid &= RFLK_isValidSelector(selector, constrainedToTrait++);
            
            wellformed &= valid;
        }
       
        if (!wellformed)
            return nil;
    }
    
    //
    // flatten inheritance
    //
    {
        for (NSString *key in dictionary.allKeys) {
            RFLK_flattenInheritance(res, key);
        }
    }
    
    //
    // resolve variables in the dictionary
    //
    {
        NSMutableDictionary *variables = [[NSMutableDictionary alloc] init];
        
        // gets all the variables
        for (NSString *selector in res.allKeys) {
            
            if ([selector hasPrefix:RFLKTokenVariablePrefix])
                for (NSString *key in [res[selector] allKeys])
                    variables[key] = res[selector][key];
        }
        
        // resolve the variables
        for (NSString *selector in res.allKeys)
            for (NSString *key in [res[selector] allKeys]) {
                
                NSString *value = res[selector][key];
                
                if ([value hasPrefix:RFLKTokenVariablePrefix]) {
                    res[selector][key] = variables[value];
                }
            }
        
        // remove the variable prefix
        for (NSString *selector in res.allKeys) {
            
            if ([selector hasPrefix:RFLKTokenVariablePrefix])
                for (NSString *key in [res[selector] allKeys]) {
                    
                    NSString *strippedKey = [key stringByReplacingOccurrencesOfString:RFLKTokenVariablePrefix withString:@""];
                    
                    NSString *value = res[selector][key];
                    [res[selector] removeObjectForKey:key];
                    res[selector][strippedKey] = value;
                }
            
        }
    }

    //
    // create selectors
    //
    {
        NSMutableDictionary *newDictionaryWithSelectorsAsKeys = @{}.mutableCopy;
        
        for (NSString *selectorString in (res).allKeys) {
            RFLKSelector *selector = [[RFLKSelector alloc] initWithString:selectorString];
            
            //check if there's a associated condition
            NSString *condition = (res)[selectorString][RFLKTokenConditionPrefix];
            if (condition != nil)
                selector.condition = [[RFLKCondition alloc] initWithString:condition];
            
            newDictionaryWithSelectorsAsKeys[selector] = (res)[selectorString];
        }

        res = newDictionaryWithSelectorsAsKeys;
    }
    
    //
    // create rhs values
    //
    {
        for (NSString *selector in res.allKeys)
            for (NSString *key in [res[selector] allKeys]) {
                
                RFLKPropertyValue *value = [[RFLKPropertyValue alloc] initWithString:res[selector][key]];
                [res[selector] removeObjectForKey:key];
                res[selector][RFLK_stringToCamelCase(key)] = value;
            }
    }
    
    NSLog(@"%@", res);
    return res;
}