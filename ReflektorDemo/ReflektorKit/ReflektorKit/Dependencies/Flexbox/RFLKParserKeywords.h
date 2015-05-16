//
//  FLEXBOXDirectives.h
//  ReflektorKit
//
//  Created by Alex Usbergo on 16/05/15.
//  Copyright (c) 2015 Alex Usbergo. All rights reserved.
//

@import UIKit;

#ifndef ReflektorKit_FLEXBOXDirectives_h
#define ReflektorKit_FLEXBOXDirectives_h

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
    NSArray *components = [cssValue componentsSeparatedByString:@","];
    
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


#endif
