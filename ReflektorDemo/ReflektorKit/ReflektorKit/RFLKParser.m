//
// RFLKParser.m
// ReflektorKit
//
// Created by Alex Usbergo on 20/04/15.
// Copyright (c) 2015 Alex Usbergo. All rights reserved.
//

#import "RFLKParser.h"
#import "RFLKLESSParser.h"
#import "RFLKMacros.h"
#import "UIColor+RFLKAddictions.h"
#import "RFLKParserItems.h"
#import "UIKit+RFLKAdditions.h"
#import "UIView+FLEXBOX.h"

NSString *const RFLKTokenVariablePrefix = @"-reflektor-variable-";
NSString *const RFLKTokenImportantModifierSuffix = @"-reflektor-important";
NSString *const RFLKTokenAppliesToSubclassesDirective = @"applies-to-subclasses";
NSString *const RFLKTokenConditionDirective = @"condition";
NSString *const RFLKTokenSelectorSeparator = @":";
NSString *const RFLKTokenSeparator = @",";
NSString *const RFLKTokenConditionSeparator = @"and";
NSString *const RFLKTokenConditionTraitSuffix = @"__where";
NSString *const RFLKTokenExpressionLessThan = @"<";
NSString *const RFLKTokenExpressionLessThanOrEqual = @"<=";
NSString *const RFLKTokenExpressionEqual = @"==";
NSString *const RFLKTokenExpressionGreaterThan = @">";
NSString *const RFLKTokenExpressionGreaterThanOrEqual = @">=";
NSString *const RFLKTokenExpressionNotEqual = @"!=";
NSString *const RFLKTokenInclude = @"include";

#pragma mark - Utilities

NSString *rflk_stripQuotesFromString(NSString *string)
{
    NSString *result = string;
 
    //If the strings is wrapped with ' or "...
    if ([string characterAtIndex:0] == '\'' || [string characterAtIndex:0] == '\"')
        result = [string substringFromIndex:1];
    
    if ([result characterAtIndex:result.length-1] == '\'' || [result characterAtIndex:result.length-1] == '\"')
        result = [result substringToIndex:result.length-1];
    
    //returns a string without quotation marks
    return result;
}

NSString *rflk_stringToCamelCase(NSString *string)
{
    //Transform a string in dash notation (e.g. property-foo) into camel case notation
    //(e.g. propertyFoo)
    
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

NSArray *rflk_getArgumentForValue(NSString* stringValue)
{
    NSCParameterAssert(stringValue);
    
    //Given a function-value string such as font('Arial', 12px) returns its
    //arguments (e.g. @['Arial', @12])
    
    NSUInteger argsStartIndex = 0;
    for (argsStartIndex = 0; argsStartIndex < stringValue.length; argsStartIndex++)
        if ([stringValue characterAtIndex:argsStartIndex] == '(')
            break;
    
    NSCAssert([stringValue characterAtIndex:stringValue.length-1] == ')', nil);
    stringValue = [stringValue substringFromIndex:argsStartIndex+1];
    stringValue = [stringValue substringToIndex:stringValue.length-1];
    
    //or ([^,]+\(.+?\))|([^,]+)
    NSArray *matches = [stringValue componentsSeparatedByString:RFLKTokenSeparator];
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

#pragma mark - Reserved Rhs values

NSDictionary *rflk_rhsKeywordsMap()
{
    static NSDictionary *__mapping;
    
    if (__mapping == nil) {
        __mapping = @{
                      
            //autoresizing masks
            @"none": @(0),
            @"flexible-left-margin": @(UIViewAutoresizingFlexibleLeftMargin),
            @"flexible-width": @(UIViewAutoresizingFlexibleWidth),
            @"flexible-right-margin": @(UIViewAutoresizingFlexibleRightMargin),
            @"flexible-top-margin": @(UIViewAutoresizingFlexibleTopMargin),
            @"flexible-height": @(UIViewAutoresizingFlexibleHeight),
            @"flexible-bottom-margin": @(UIViewAutoresizingFlexibleBottomMargin),

            //content mode
            @"mode-scale-to-fill": @(UIViewContentModeScaleToFill),
            @"mode-scale-aspect-fit": @(UIViewContentModeScaleAspectFit),
            @"mode-scale-aspect-fill": @(UIViewContentModeScaleAspectFill),
            @"mode-redraw": @(UIViewContentModeRedraw),
            @"mode-center": @(UIViewContentModeCenter),
            @"mode-top": @(UIViewContentModeTop),
            @"mode-bottom": @(UIViewContentModeBottom),
            @"mode-left": @(UIViewContentModeLeft),
            @"mode-right": @(UIViewContentModeRight),
            @"mode-top-left": @(UIViewContentModeTopLeft),
            @"mode-top-right": @(UIViewContentModeTopRight),
            @"mode-bottom-left": @(UIViewContentModeBottomLeft),
            @"mode-bottom-right": @(UIViewContentModeRight),

            //flexbox
            @"row": @(FLEXBOXFlexDirectionRow),
            @"row-reverse": @(FLEXBOXFlexDirectionRowReverse),
            @"column": @(FLEXBOXFlexDirectionColumn),
            @"column-reverse": @(FLEXBOXFlexDirectionColumnReverse),

            @"wrap": @(YES),
            @"nowrap": @(NO),

            @"flex-start": @(FLEXBOXJustificationFlexStart),
            @"center": @(FLEXBOXJustificationCenter),
            @"flex-end": @(FLEXBOXJustificationFlexEnd),
            @"space-between": @(FLEXBOXJustificationSpaceBetween),
            @"space-around": @(FLEXBOXJustificationSpaceAround),

            @"auto": @(FLEXBOXAlignmentAuto),
            @"stretch": @(FLEXBOXAlignmentStretch)
        };
    }
    
    return __mapping;
}

id rflk_parseKeyword(NSString *cssValue)
{
    //Called from rhs_parseRhsValue
    //If the Rhs value is a reserved keyword (or a combination of those) this function
    //returns the associated value right aways
    
    NSArray *components = [cssValue componentsSeparatedByString:RFLKTokenSeparator];
    
    BOOL keywords = YES;
    for (NSString *c in components)
        keywords &= rflk_rhsKeywordsMap()[c] != nil;
    
    if (!keywords)
        return nil;
    
    NSInteger value = 0;
    for (NSString *c in components) {
        value = value | [rflk_rhsKeywordsMap()[c] integerValue];
    }
    
    return @(value);
}


#pragma mark - Private functions

void rflk_assertOnMalformedValue(NSArray *arguments, NSInteger count, NSString *type, NSString *format)
{
    NSCAssert(arguments.count == count, @"Malformed %@ value. Expected format: %@", type, format);
}

void rflk_flattenInheritance(NSMutableDictionary *dictionary, NSString *key)
{
    NSCParameterAssert(dictionary);
    NSCParameterAssert(key);
    
    //Resolves all the include directives by recursively coping the included definitions

    key = rflk_stripQuotesFromString(key);
    NSString *inherit = dictionary[key][RFLKTokenInclude];
    
    if (inherit == nil)
        return;
 
    NSMutableArray *components = @[].mutableCopy;
    for (NSString *c in [inherit componentsSeparatedByString:RFLKTokenSeparator])
         [components addObject:rflk_stripQuotesFromString(c)];
    
    for (NSString *inheritedKey in components) {
        rflk_flattenInheritance(dictionary, inheritedKey);
    }
    
    NSMutableDictionary *newValuesForSelector = [dictionary[key] mutableCopy];
    [newValuesForSelector removeObjectForKey:RFLKTokenInclude];
    
    for (NSString *inheritedKey in components)
        for (NSString *property in [dictionary[inheritedKey] allKeys])
            
            if (newValuesForSelector[property] == nil)
                newValuesForSelector[property] = dictionary[inheritedKey][property];
    
    dictionary[key] = newValuesForSelector;
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
    if (option == RFLKPropertyValueOptionNone)
        return YES;
    
    else if (option == RFLKPropertyValueOptionPercentValue)
        return [string containsString:@"%"];
    else
        return NO;
}

BOOL rflk_stringHasPrefix(NSString *string, NSArray *prefixes)
{
    BOOL match = NO;
    for (NSString *s in prefixes)
        match |= [string hasPrefix:s];
    
    return match;
}

void rflk_parseRhsValue(NSString *stringValue, id *returnValue, NSInteger *option, BOOL *layoutTimeProperty)
{
    NSCParameterAssert(stringValue);
    
    //checks if it's marked with !layout
    (*layoutTimeProperty) = NO;
    if ([stringValue hasSuffix:RFLKTokenImportantModifierSuffix]) {
        stringValue = [stringValue substringToIndex:stringValue.length - RFLKTokenImportantModifierSuffix.length];
        (*layoutTimeProperty) = YES;
    }
    
    id value = stringValue;
    
    //check for flexbox values
    id keywordValue = rflk_parseKeyword(value);
    if (keywordValue != nil) {
        (*returnValue) = keywordValue;
        return;
    }
    
    float numericValue;
    NSScanner *scan = [NSScanner scannerWithString:stringValue];
    
    //plain number
    if ([scan scanFloat:&numericValue]) {
        value = [NSNumber numberWithFloat:numericValue];
        (*option) = rflk_checkForPresenceOfOptionInString(stringValue, RFLKPropertyValueOptionPercentValue) ? RFLKPropertyValueOptionPercentValue : RFLKPropertyValueOptionNone;

    //boolean value
    } else if (rflk_stringHasPrefix(stringValue, @[@"true", @"false"])) {
        value = [stringValue isEqualToString:@"true"] ? [NSNumber numberWithBool:YES] : [NSNumber numberWithBool:NO];
        
    //string (in quotes)
    } else if (rflk_stringHasPrefix(stringValue, @[@"\"", @"\'"])) {
        value = rflk_stripQuotesFromString(stringValue);
        
    //css color
    } else if (rflk_stringHasPrefix(stringValue, @[@"rgb", @"rgba", @"hsl", @"hsla", @"#"])) {
        value = [UIColor colorWithRFLKLESS:stringValue];
        
    } else {
        
        NSArray *arguments = nil;
        
        @try {
            arguments = rflk_getArgumentForValue(stringValue);
        }
        @catch (NSException *exception) {
            [NSException raise:[NSString stringWithFormat:@"Unable to parse right-hand side value: %@", stringValue] format:nil];
        }

        if (rflk_stringHasPrefix(stringValue, @[@"font"])) {
            rflk_assertOnMalformedValue(arguments, 2, @"font", @"font('font postscript name', size)");
            NSString *fontName = rflk_stripQuotesFromString(arguments[0]);
            value = [UIFont fontWithName:fontName size:[arguments[1] floatValue]];
            (*option) = rflk_checkForPresenceOfOptionInString(arguments[1], RFLKPropertyValueOptionPercentValue) ? RFLKPropertyValueOptionPercentValue : RFLKPropertyValueOptionNone;
            
        } else if (rflk_stringHasPrefix(stringValue, @[@"locale"])) {
            rflk_assertOnMalformedValue(arguments, 1, @"locale", @"locale('KEY')");
            value = NSLocalizedString(arguments[0], nil);
            
        } else if (rflk_stringHasPrefix(stringValue, @[@"rect"])) {
            rflk_assertOnMalformedValue(arguments, 4, @"rect", @"rect(x, y, width, height)");
            value = [NSValue valueWithCGRect:(CGRect){{[arguments[0] floatValue], [arguments[1] floatValue]}, {[arguments[2] floatValue], [arguments[3] floatValue]}}];
            
        } else if (rflk_stringHasPrefix(stringValue, @[@"point"])) {
            rflk_assertOnMalformedValue(arguments, 2, @"point", @"point(x, y)");
            value = [NSValue valueWithCGPoint:(CGPoint){[arguments[0] floatValue], [arguments[1] floatValue]}];
            
        } else if (rflk_stringHasPrefix(stringValue, @[@"size"])) {
            rflk_assertOnMalformedValue(arguments, 2, @"size", @"size(width, height)");
            value = [NSValue valueWithCGSize:(CGSize){[arguments[0] floatValue], [arguments[1] floatValue]}];
           
        } else if (rflk_stringHasPrefix(stringValue, @[@"image"])) {
            rflk_assertOnMalformedValue(arguments, 1, @"image", @"size(imagename)");
            rflk_parseRhsValue(arguments[0], &value, option, layoutTimeProperty);
            (*option) = RFLKPropertyValueOptionImage;
            
        } else if (rflk_stringHasPrefix(stringValue, @[@"transform-scale"])) {
            rflk_assertOnMalformedValue(arguments, 2, @"transform-scale", @"transform-scale(x, y)");
            value = [NSValue valueWithCGAffineTransform:CGAffineTransformMakeScale([arguments[0] floatValue], [arguments[1] floatValue])];
            
        } else if (rflk_stringHasPrefix(stringValue, @[@"transform-rotate"])) {
            rflk_assertOnMalformedValue(arguments, 1, @"transform-rotate", @"transform-rotate(angle)");
            value = [NSValue valueWithCGAffineTransform:CGAffineTransformMakeRotation([arguments[0] floatValue])];
            
        } else if (rflk_stringHasPrefix(stringValue, @[@"transform-translate"])) {
            rflk_assertOnMalformedValue(arguments, 2, @"transform-translate", @"transform-translate(x, y)");
            value = [NSValue valueWithCGAffineTransform:CGAffineTransformMakeTranslation([arguments[0] floatValue], [arguments[1] floatValue])];
            
        } else if (rflk_stringHasPrefix(stringValue, @[@"edge-insets"])) {
            rflk_assertOnMalformedValue(arguments, 4, @"edge-insets", @"edge-insets(top, bottom, width, height)");
            value = [NSValue valueWithUIEdgeInsets:(UIEdgeInsets){[arguments[0] floatValue], [arguments[1] floatValue], [arguments[2] floatValue], [arguments[3] floatValue]}];
            
        } else if (rflk_stringHasPrefix(stringValue, @[@"vector", @"linear-gradient"])) {
            
            if (rflk_stringHasPrefix(stringValue, @[@"linear-gradient"]))
                (*option) = RFLKPropertyValueOptionLinearGradient;
            
            NSMutableArray *array = @[].mutableCopy;
            for (NSString *c in arguments) {
                
                //rescursively parsing the vector component
                id cv;
                BOOL layoutTimeProperty;
                rflk_parseRhsValue(c, &cv, option, &layoutTimeProperty);
                [array addObject:cv];
            }
            
            value = array;
            
        } else if (rflk_stringHasPrefix(stringValue, @[@"vector"])) {
            
            RFLKLog(@"unsupported value: %@", stringValue);
            value = [NSNull null];
        }
    }
    
    (*layoutTimeProperty) |= ((*option) == RFLKPropertyValueOptionLinearGradient || (*option) == RFLKPropertyValueOptionPercentValue);
    (*returnValue) = value;
}


NSString *rflk_cssUuid()
{
    //Returns a UUID
    static const NSString *letters = @"1234567890abcdef";
    static const u_int32_t lenght = 16;

    NSMutableString *randomString = [NSMutableString stringWithCapacity:lenght];
    
    for (int i = 0; i < lenght; i++)
        [randomString appendFormat: @"%C", [letters characterAtIndex:(NSUInteger)arc4random_uniform((u_int32_t)letters.length)]];
    
    return randomString;
}

//TODO: Add these to the lexer
void rflk_preprocessStylesheet(NSString **stylesheet)
{
    NSString *s = (*stylesheet);
    
    s = [s stringByReplacingOccurrencesOfString:@"@" withString:RFLKTokenVariablePrefix];
    s = [s stringByReplacingOccurrencesOfString:@"!important" withString:RFLKTokenImportantModifierSuffix];
    
    //makes the condition traits unique
    s = [s stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@%@", RFLKTokenSelectorSeparator, RFLKTokenConditionTraitSuffix]
                                     withString:[NSString stringWithFormat:@"%@%@_%@", RFLKTokenSelectorSeparator, RFLKTokenConditionTraitSuffix, rflk_cssUuid()]];
    (*stylesheet) = s;
}


NSDictionary *rflk_parseStylesheet(NSString *stylesheet)
{
    RFLKLESSParser *parser = [[RFLKLESSParser alloc] init];
    
    NSDictionary *dictionary;
    
    //Preprocess and parse the LESS-compliant preprocessed stylesheet
    {
        rflk_preprocessStylesheet(&stylesheet);
        dictionary = [parser parseText:stylesheet];
    }
    
    NSMutableDictionary *res = dictionary.mutableCopy;

    //Flatten inheritance
    {
        for (NSString *key in dictionary.allKeys) {
            rflk_flattenInheritance(res, key);
        }
    }
    
    //Resolve variables in the dictionary
    {
        NSMutableDictionary *variables = [[NSMutableDictionary alloc] init];
        
        //gets all the variables
        for (NSString *selector in res.allKeys) {
            
            if (rflk_stringHasPrefix(selector, @[RFLKTokenVariablePrefix]))
                for (NSString *key in [res[selector] allKeys])
                    variables[key] = res[selector][key];
        }
        
        //prefix keys
        NSMutableArray *vk = variables.allKeys.mutableCopy;
        for (NSInteger i = 0; i < vk.count; i++) {
            for (NSInteger j = 0; j < vk.count; j++) {
             
                //move the item that is prefix of another at the bottom
                if (rflk_stringHasPrefix(vk[i], @[vk[j]])) {
                    NSString *v = vk[j];
                    [vk removeObjectAtIndex:j];
                    [vk insertObject:v atIndex:0];
                }
            }
        }
        
        //resolve the variables
        for (NSString *selector in res.allKeys)
            for (NSString *key in [res[selector] allKeys]) {
                NSString *value = res[selector][key];
                for (NSString *variable in vk) {
                    value = [value stringByReplacingOccurrencesOfString:variable withString:variables[variable]];
                    res[selector][key] = value;
                }
            }
        
        //remove the variable prefix
        for (NSString *selector in res.allKeys) {
            if (rflk_stringHasPrefix(selector, @[RFLKTokenVariablePrefix]))
                for (NSString *key in [res[selector] allKeys]) {
                    
                    NSString *strippedKey = [key stringByReplacingOccurrencesOfString:RFLKTokenVariablePrefix withString:@""];
                    
                    NSString *value = res[selector][key];
                    [res[selector] removeObjectForKey:key];
                    res[selector][strippedKey] = value;
                }
        }
    }

    //Create selector objects
    {
        NSMutableDictionary *newDictionaryWithSelectorsAsKeys = @{}.mutableCopy;
        
        for (NSString *selectorString in (res).allKeys) {
            RFLKSelector *selector = [[RFLKSelector alloc] initWithString:selectorString];
            
            //check if there's a associated condition
            NSString *condition = (res)[selectorString][RFLKTokenConditionDirective];
            if (condition != nil)
                selector.condition = [[RFLKCondition alloc] initWithString:condition];
            
            NSString *appliesToSubclasses = (res)[selectorString][RFLKTokenAppliesToSubclassesDirective];
            if (appliesToSubclasses != nil && [appliesToSubclasses isEqualToString:@"true"])
                selector.appliesToSubclasses = YES;
            
            newDictionaryWithSelectorsAsKeys[selector] = (res)[selectorString];
        }

        res = newDictionaryWithSelectorsAsKeys;
    }
    
    //Create rhs values
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