//
//  RFLKParser.m
//  ReflektorKit
//
//  Created by Alex Usbergo on 20/04/15.
//  Copyright (c) 2015 Alex Usbergo. All rights reserved.
//

#import "RFLKParser.h"
#import "RFLKLESSParser.h"
#import "RFLKMacros.h"
#import "UIColor+RFLKAddictions.h"
#import "RFLKParserItems.h"
#import "UIKit+RFLKAdditions.h"

void    rflk_flattenInheritance(NSMutableDictionary *dictionary, NSString *key);

NSString *const RFLKTokenVariablePrefix = @"-reflektor-variable-";
NSString *const RFLKTokenImportantModifierSuffix = @"-reflektor-important";
NSString *const RFLKTokenAppliesToSubclassesDirective = @"applies-to-subclasses";
NSString *const RFLKTokenSelectorSeparator = @":";
NSString *const RFLKTokenSeparator = @",";
NSString *const RFLKTokenConditionSeparator = @"and";
NSString *const RFLKTokenConditionPrefix = @"__where";

NSString *const RFLKTokenExpressionLessThan = @"<";
NSString *const RFLKTokenExpressionLessThanOrEqual = @"<=";
NSString *const RFLKTokenExpressionEqual = @"=";
NSString *const RFLKTokenExpressionGreaterThan = @">";
NSString *const RFLKTokenExpressionGreaterThanOrEqual = @">=";
NSString *const RFLKTokenExpressionNotEqual = @"!=";

NSString *const RFLKTokenInclude = @"include";

#pragma mark - Private functions


NSArray *rflk_getArgumentForValue(NSString* stringValue)
{
    NSCParameterAssert(stringValue);
    
    NSUInteger argsStartIndex = 0;
    for (argsStartIndex = 0; argsStartIndex < stringValue.length; argsStartIndex++)
        if ([stringValue characterAtIndex:argsStartIndex] == '(')
            break;
    
    NSCAssert([stringValue characterAtIndex:stringValue.length-1] == ')', nil);
    stringValue = [stringValue substringFromIndex:argsStartIndex+1];
    stringValue = [stringValue substringToIndex:stringValue.length-1];
    
    //or ([^,]+\(.+?\))|([^,]+)
    NSArray *matches = [stringValue componentsSeparatedByString:@","];
    NSMutableArray *arguments = @[].mutableCopy;
    
    //note: it doesn't support recursively nested functions (just depth 1)
    for (NSInteger i = 0; i < matches.count; i++) {
    
        NSMutableString *match = [matches[i] mutableCopy];

        //is a nested function value
        NSInteger j = i+1;
        if ([match containsString:@"("])
            for (;j < matches.count; j++) {
                
                [match appendString:@","];
                
                //append the nested match
                NSString *nestedMatch = matches[j];
                
                //end of nested fuction
                if ([nestedMatch containsString:@")"]) {
                    [match appendString:nestedMatch];
                    i = j;
                    break;
                }
                         
                [match appendString:nestedMatch];
            }
    
        [arguments addObject:match];
    }
    
    return arguments;
}

void rflk_assertOnMalformedValue(NSArray *arguments, NSInteger count, NSString *type, NSString *format)
{
    NSCAssert(arguments.count == count, @"Malformed %@ value. Expected format: %@", type, format);
}

void rflk_flattenInheritance(NSMutableDictionary *dictionary, NSString *key)
{
    NSCParameterAssert(dictionary);
    NSCParameterAssert(key);

    NSString *inherit = dictionary[key][RFLKTokenInclude];
    
    if (inherit == nil)
        return;
 
    NSArray *components = [inherit componentsSeparatedByString:RFLKTokenSeparator];
    
    for (NSString *inheritedKey in components)
        rflk_flattenInheritance(dictionary, inheritedKey);
    
    NSMutableDictionary *newValuesForSelector = [dictionary[key] mutableCopy];
    [newValuesForSelector removeObjectForKey:RFLKTokenInclude];
    
    for (NSString *inheritedKey in components)
        for (NSString *property in [dictionary[inheritedKey] allKeys])
            
            if (newValuesForSelector[property] == nil)
                newValuesForSelector[property] = dictionary[inheritedKey][property];
    
    dictionary[key] = newValuesForSelector;
}

NSString *rflk_stringToCamelCase(NSString *string)
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

NSString *rflk_bundlePath(NSString *file, NSString *extension)
{
    NSString *const resourcePath = @"Frameworks/ReflektorKit.framework/";
    NSString *path = [[NSBundle mainBundle] pathForResource:file ofType:extension];
    
    if (!path)
        path = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"%@%@", resourcePath, file] ofType:extension];
    
    return path;
}

BOOL rflk_checkForPresenceOfOptionInString(NSString *string, RFLKPropertyValueOption option)
{
    switch (option) {
        case RFLKPropertyValueOptionNone:
            return YES;
            break;
            
        case RFLKPropertyValueOptionPercentValue:
            return [string containsString:@"%"];
            
        case RFLKPropertyValueOptionLinearGradient:
            return NO;
            
        default:
            break;
    }
}

extern void rflk_parseRhsValue(NSString *stringValue, id *returnValue, NSInteger *option, BOOL *layoutTimeProperty)
{
    NSCParameterAssert(stringValue);
    NSCAssert(![stringValue hasPrefix:RFLKTokenConditionPrefix], @"This can't be a condition value.");
    
    // checks if it's marked with !layout
    (*layoutTimeProperty) = NO;
    if ([stringValue hasSuffix:RFLKTokenImportantModifierSuffix]) {
        stringValue = [stringValue substringToIndex:stringValue.length - RFLKTokenImportantModifierSuffix.length];
        (*layoutTimeProperty) = YES;
    }

    id value = stringValue;
    
    float numericValue;
    NSScanner *scan = [NSScanner scannerWithString:stringValue];
    
    if ([scan scanFloat:&numericValue]) {
        value = [NSNumber numberWithFloat:numericValue];
        (*option) = rflk_checkForPresenceOfOptionInString(stringValue, RFLKPropertyValueOptionPercentValue) ? RFLKPropertyValueOptionPercentValue : RFLKPropertyValueOptionNone;

    } else if ([stringValue isEqualToString:@"true"] || [stringValue isEqualToString:@"false"]) {
        value = [stringValue isEqualToString:@"true"] ? [NSNumber numberWithBool:YES] : [NSNumber numberWithBool:NO];
        
    } else if ([stringValue hasPrefix:@"'"] || [stringValue hasPrefix:@"\""]) {
        value = [stringValue stringByReplacingOccurrencesOfString:@"\"" withString:@""];
        value = [value stringByReplacingOccurrencesOfString:@"'" withString:@""];
        
    } else if ([stringValue hasPrefix:@"rgb"] || [stringValue hasPrefix:@"hsl"] || [stringValue hasPrefix:@"rgba"] || [stringValue hasPrefix:@"hsla"] || [stringValue hasPrefix:@"#"]) {
        value = [UIColor colorWithRFLKLESS:stringValue];
        
    } else {
        
        NSArray *arguments = nil;
        
        @try {
            arguments = rflk_getArgumentForValue(stringValue);
        }
        @catch (NSException *exception) {
            [NSException raise:[NSString stringWithFormat:@"Unable to parse right-hand side value: %@", stringValue] format:nil];
        }

        if ([stringValue hasPrefix:@"font"]) {
            rflk_assertOnMalformedValue(arguments, 2, @"font", @"font('font postscript name', size)");
            NSString *fontName = [[arguments[0] stringByReplacingOccurrencesOfString:@"'" withString:@""] stringByReplacingOccurrencesOfString:@"\"" withString:@""];
            value = [UIFont fontWithName:fontName size:[arguments[1] floatValue]];
            (*option) = rflk_checkForPresenceOfOptionInString(arguments[1], RFLKPropertyValueOptionPercentValue) ? RFLKPropertyValueOptionPercentValue : RFLKPropertyValueOptionNone;
            
        } else if ([stringValue hasPrefix:@"locale"]) {
            rflk_assertOnMalformedValue(arguments, 1, @"locale", @"locale('KEY')");
            value = NSLocalizedString(arguments[0], nil);
            
        } else if ([stringValue hasPrefix:@"rect"]) {
            rflk_assertOnMalformedValue(arguments, 4, @"rect", @"rect(x, y, width, height)");
            value = [NSValue valueWithCGRect:(CGRect){{[arguments[0] floatValue], [arguments[1] floatValue]}, {[arguments[2] floatValue], [arguments[3] floatValue]}}];
            
        } else if ([stringValue hasPrefix:@"point"]) {
            rflk_assertOnMalformedValue(arguments, 2, @"point", @"point(x, y)");
            value = [NSValue valueWithCGPoint:(CGPoint){[arguments[0] floatValue], [arguments[1] floatValue]}];
            
        } else if ([stringValue hasPrefix:@"size"]) {
            rflk_assertOnMalformedValue(arguments, 2, @"size", @"size(width, height)");
            value = [NSValue valueWithCGSize:(CGSize){[arguments[0] floatValue], [arguments[1] floatValue]}];
            
        } else if ([stringValue hasPrefix:@"transform-scale"]) {
            rflk_assertOnMalformedValue(arguments, 2, @"transform-scale", @"transform-scale(x, y)");
            value = [NSValue valueWithCGAffineTransform:CGAffineTransformMakeScale([arguments[0] floatValue], [arguments[1] floatValue])];
            
        } else if ([stringValue hasPrefix:@"transform-rotate"]) {
            rflk_assertOnMalformedValue(arguments, 1, @"transform-rotate", @"transform-rotate(angle)");
            value = [NSValue valueWithCGAffineTransform:CGAffineTransformMakeRotation([arguments[0] floatValue])];
            
        } else if ([stringValue hasPrefix:@"transform-translate"]) {
            rflk_assertOnMalformedValue(arguments, 2, @"transform-translate", @"transform-translate(x, y)");
            value = [NSValue valueWithCGAffineTransform:CGAffineTransformMakeTranslation([arguments[0] floatValue], [arguments[1] floatValue])];
            
        } else if ([stringValue hasPrefix:@"edge-insets"]) {
            rflk_assertOnMalformedValue(arguments, 4, @"edge-insets", @"edge-insets(top, bottom, width, height)");
            value = [NSValue valueWithUIEdgeInsets:(UIEdgeInsets){[arguments[0] floatValue], [arguments[1] floatValue], [arguments[2] floatValue], [arguments[3] floatValue]}];
            
        } else if ([stringValue hasPrefix:@"vector"] || [stringValue hasPrefix:@"linear-gradient"]) {
            
            if ([stringValue hasPrefix:@"linear-gradient"])
                (*option) = RFLKPropertyValueOptionLinearGradient;
            
            NSMutableArray *array = @[].mutableCopy;
            for (NSString *c in arguments) {
                
                // rescursively parsing the vector component
                id cv;
                BOOL layoutTimeProperty;
                rflk_parseRhsValue(c, &cv, option, &layoutTimeProperty);
                [array addObject:cv];
            }
            
            value = array;
            
        } else  {
            RFLKLog(@"unsupported value: %@", stringValue);
            value = [NSNull null];
        }
    }
    
    (*layoutTimeProperty) |= ((*option) == RFLKPropertyValueOptionLinearGradient || (*option) == RFLKPropertyValueOptionPercentValue);
    (*returnValue) = value;
}


NSString *rflk_uuid()
{
    // Returns a UUID
    static const NSString *letters = @"1234567890abcdef";
    static const u_int32_t lenght = 16;

    NSMutableString *randomString = [NSMutableString stringWithCapacity:lenght];
    
    for (int i = 0; i < lenght; i++)
        [randomString appendFormat: @"%C", [letters characterAtIndex:(NSUInteger)arc4random_uniform((u_int32_t)letters.length)]];
    
    return randomString;
}

//TODO: Add these to the lexer
void rflk_replaceSymbolsInStylesheet(NSString **stylesheet)
{
    NSString *s = (*stylesheet);
    
    //TODO: use regex - this is unsafe
    s = [s stringByReplacingOccurrencesOfString:@"@" withString:RFLKTokenVariablePrefix];
    s = [s stringByReplacingOccurrencesOfString:@"!important" withString:RFLKTokenImportantModifierSuffix];
    s = [s stringByReplacingOccurrencesOfString:@".?" withString:[NSString stringWithFormat:@"%@%@_%@", RFLKTokenSelectorSeparator, RFLKTokenConditionPrefix, rflk_uuid()]];
    (*stylesheet) = s;
}


NSDictionary *rflk_parseStylesheet(NSString *stylesheet)
{
    RFLKLESSParser *parser = [[RFLKLESSParser alloc] init];
    
    NSDictionary *dictionary;
    
    //
    // parse
    //
    {
        rflk_replaceSymbolsInStylesheet(&stylesheet);
        dictionary = [parser parseText:stylesheet];
    }
    
    NSMutableDictionary *res = dictionary.mutableCopy;

    //
    // flatten inheritance
    //
    {
        for (NSString *key in dictionary.allKeys) {
            rflk_flattenInheritance(res, key);
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
        
        // prefix keys
        NSMutableArray *vk = variables.allKeys.mutableCopy;
        for (NSInteger i = 0; i < vk.count; i++) {
            for (NSInteger j = 0; j < vk.count; j++) {
             
                // move the item that is prefix of another at the bottom
                if ([vk[i] hasPrefix:vk[j]]) {
                    NSString *v = vk[j];
                    [vk removeObjectAtIndex:j];
                    [vk insertObject:v atIndex:0];
                }
            }
        }
        
        
        // resolve the variables
        for (NSString *selector in res.allKeys)
            for (NSString *key in [res[selector] allKeys]) {
                NSString *value = res[selector][key];
                for (NSString *variable in vk) {
                    value = [value stringByReplacingOccurrencesOfString:variable withString:variables[variable]];
                    res[selector][key] = value;
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
            
            NSString *appliesToSubclasses = (res)[selectorString][RFLKTokenAppliesToSubclassesDirective];
            if (appliesToSubclasses != nil && [appliesToSubclasses isEqualToString:@"true"])
                selector.appliesToSubclasses = YES;
            
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
                res[selector][rflk_stringToCamelCase(key)] = value;
            }
    }
    
    return res;
}