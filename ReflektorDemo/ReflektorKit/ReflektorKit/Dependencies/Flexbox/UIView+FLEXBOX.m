//
//  UIView+FLEXBOX.m
//  FlexboxKit
//
//  Created by Alex Usbergo on 09/05/15.
//  Copyright (c) 2015 Alex Usbergo. All rights reserved.
//

#import "UIView+FLEXBOX.h"
#import <objc/runtime.h>

const void *FLEXBOXNodeKey;
const void *FLEXBOXSizeKey;
const void *FLEXBOXFlexboxContainerKey;

@implementation UIView (FLEXBOX)

- (FLEXBOXNode*)flexNode
{
    FLEXBOXNode *node = objc_getAssociatedObject(self, &FLEXBOXNodeKey);
    
    if (node == nil) {
        node = [[FLEXBOXNode alloc] init];
        self.flexNode = node;
        
        __weak __typeof(self) weakSelf = self;
        
        self.flexNode.childrenAtIndexBlock = ^FLEXBOXNode*(NSUInteger i) {
            return [weakSelf.subviews[i] flexNode];
        };
        
        self.flexNode.childrenCountBlock = ^NSUInteger(void) {
            return weakSelf.subviews.count;
        };
        
        self.flexNode.measureBlock = ^CGSize(CGFloat width) {
            return [weakSelf flexComputeSize:(CGSize){width, NAN}];
        };
    }
    
    return node;
}

- (void)setFlexNode:(FLEXBOXNode*)flexNode
{
    objc_setAssociatedObject(self, &FLEXBOXNodeKey, flexNode, OBJC_ASSOCIATION_RETAIN);
}

- (CGSize)flexFixedSize
{
    NSValue *value = objc_getAssociatedObject(self, &FLEXBOXSizeKey);
    if (value != nil) {
        return [value CGSizeValue];
    } else {
        return CGSizeZero;
    }
}

- (CGSize)flexMinumumSize
{
    return self.flexNode.minDimensions;
}

- (void)setFlexMinumumSize:(CGSize)flexMinumumSize
{
    self.flexNode.minDimensions = flexMinumumSize;
}

- (CGSize)flexMaximumSize
{
    return self.flexNode.maxDimensions;
}

- (void)setFlexMaximumSize:(CGSize)flexMaximumSize
{
    self.flexNode.maxDimensions = flexMaximumSize;
}

- (void)setFlexFixedSize:(CGSize)flexFixedSize
{
    return objc_setAssociatedObject(self, &FLEXBOXSizeKey, [NSValue valueWithCGSize:flexFixedSize], OBJC_ASSOCIATION_RETAIN);
}

- (CGSize)flexComputeSize:(CGSize)bounds
{
    if (!CGSizeEqualToSize(self.flexFixedSize, CGSizeZero))
        return self.flexFixedSize;
    
    bounds.height = isnan(bounds.height) ? FLT_MAX : bounds.height;
    bounds.width = isnan(bounds.width) ? FLT_MAX : bounds.width;
    
    CGSize size = [self sizeThatFits:bounds];

    return size;
}


- (void)flexLayoutSubviews
{
    FLEXBOXNode *node = self.flexNode;
    node.dimensions = self.bounds.size;
    
    [node layoutConstrainedToMaximumWidth:self.bounds.size.width];
    
    for (NSUInteger i = 0; i < node.childrenCountBlock(); i++) {
        
        UIView *subview = self.subviews[i];
        FLEXBOXNode *subnode = node.childrenAtIndexBlock(i);
        subview.frame = CGRectIntegral(subnode.frame);
    }

    self.frame = (CGRect){self.frame.origin, node.frame.size};
}

#pragma mark - Properties

- (FLEXBOXFlexDirection)flexDirection
{
    return self.flexNode.flexDirection;
}

- (void)setFlexDirection:(FLEXBOXFlexDirection)flexDirection
{
    self.flexNode.flexDirection = flexDirection;
}

- (UIEdgeInsets)flexMargin
{
    return self.flexNode.margin;
}

- (void)setFlexMargin:(UIEdgeInsets)flexMargin
{
    self.flexNode.margin = flexMargin;
}

- (UIEdgeInsets)flexPadding
{
    return self.flexNode.padding;
}

- (void)setFlexPadding:(UIEdgeInsets)flexPadding
{
    self.flexNode.padding = flexPadding;
}

- (BOOL)flexWrap
{
    return self.flexNode.flexWrap;
}

- (void)setFlexWrap:(BOOL)flexWrap
{
    self.flexNode.flexWrap = flexWrap;
}

- (FLEXBOXJustification)flexJustifyContent
{
    return self.flexNode.justifyContent;
}

- (void)setFlexJustifyContent:(FLEXBOXJustification)flexJustifyContent
{
    self.flexNode.justifyContent = flexJustifyContent;
}

- (FLEXBOXAlignment)flexAlignSelf
{
    return self.flexNode.alignSelf;
}

- (void)setFlexAlignSelf:(FLEXBOXAlignment)flexAlignSelf
{
    self.flexNode.alignSelf = flexAlignSelf;
}

- (FLEXBOXAlignment)flexAlignItems
{
    return self.flexNode.alignItems;
}

- (void)setFlexAlignItems:(FLEXBOXAlignment)flexAlignItems
{
    self.flexNode.alignItems = flexAlignItems;
}

- (CGFloat)flex
{
    return self.flexNode.flex;
}

- (void)setFlex:(CGFloat)flex
{
    self.flexNode.flex = flex;
}

- (void)setContentDirection:(FLEXBOXContentDirection)contentDirection
{
    self.flexNode.contentDirection = contentDirection;
}

- (FLEXBOXContentDirection)contentDirection
{
    return self.flexNode.contentDirection;
}

- (void)setFlexContainer:(BOOL)flexContainer
{
    objc_setAssociatedObject(self, &FLEXBOXFlexboxContainerKey, @(flexContainer), OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)flexContainer
{
    return objc_getAssociatedObject(self, &FLEXBOXFlexboxContainerKey);
}

@end

#pragma mark - Node 

const CGFloat FLEXBOXUndefinedMaximumWidth = CSS_UNDEFINED;

static BOOL FLEXBOX_alwaysDirty(void *context)
{
    return YES;
}

static css_node_t *FLEXBOX_getChild(void *context, int i)
{
    FLEXBOXNode *_self = (__bridge FLEXBOXNode*)context;
    FLEXBOXNode *child = _self.childrenAtIndexBlock(i);
    return child.node;
}

static css_dim_t FLEXBOX_measureNode(void *context, float width)
{
    FLEXBOXNode *_self = (__bridge FLEXBOXNode*)context;
    CGSize size = _self.measureBlock(width);
    return (css_dim_t){ size.width, size.height };
}

@implementation FLEXBOXNode

#pragma mark - Lifecycle

- (instancetype)init
{
    if (self = [super init]) {
        
        //initialise the css_node_t
        _node = new_css_node();
        _node->context = (__bridge void *)self;
        _node->is_dirty = FLEXBOX_alwaysDirty;
        _node->measure = FLEXBOX_measureNode;
        _node->get_child = FLEXBOX_getChild;
        
        //defaults
        self.flexDirection = FLEXBOXFlexDirectionColumn;
        self.flexWrap = NO;
        self.alignItems = FLEXBOXAlignmentStretch;
        self.alignSelf = FLEXBOXAlignmentAuto;
        self.margin = UIEdgeInsetsZero;
        self.padding = UIEdgeInsetsZero;
        self.justifyContent = FLEXBOXJustificationFlexStart;
        self.flex = 0;
        self.contentDirection = FLEXBOXContentDirectionInherit;
    }
    
    return self;
}

- (void)dealloc
{
    free_css_node(_node);
}

#pragma mark - Layout and Internals

- (void)prepareForLayout
{
    if (self.childrenAtIndexBlock == nil)
        return;
    
    NSAssert(self.childrenCountBlock, nil);
    NSUInteger count = self.childrenCountBlock();
    
    // prepares the nodes for the layout recursively
    for (NSInteger i = 0; i < count; i++) {
        FLEXBOXNode *node = self.childrenAtIndexBlock(i);
        [node prepareForLayout];
    }
    
    // Apparently we need to reset these before laying out, otherwise the layout
    // has some weird additive effect.
    self.node->layout.position[CSS_LEFT] = 0;
    self.node->layout.position[CSS_TOP] = 0;
    self.node->layout.dimensions[CSS_WIDTH] = CSS_UNDEFINED;
    self.node->layout.dimensions[CSS_HEIGHT] = CSS_UNDEFINED;
}

- (void)layoutConstrainedToMaximumWidth:(CGFloat)maximumWidth
{
    _node->children_count = (int)self.childrenCountBlock();
    
    maximumWidth = fabs(maximumWidth - FLT_MAX) < FLT_EPSILON ? FLEXBOXUndefinedMaximumWidth : maximumWidth;
    [self prepareForLayout];
    layoutNode(_node, maximumWidth, _node->style.direction);
}

- (CGRect)frame
{
    return (CGRect) {
        .origin.x = self.node->layout.position[CSS_LEFT],
        .origin.y = self.node->layout.position[CSS_TOP],
        .size.width = self.node->layout.dimensions[CSS_WIDTH],
        .size.height = self.node->layout.dimensions[CSS_HEIGHT]
    };
}

#pragma mark - Style

- (void)setDimensions:(CGSize)size
{
    _dimensions = size;
    _node->style.dimensions[0] = size.width;
    _node->style.dimensions[1] = size.height;
}

- (void)setMinDimensions:(CGSize)size
{
    _dimensions = size;
    _node->style.minDimensions[0] = size.width;
    _node->style.minDimensions[1] = size.height;
}

- (void)setMaxDimensions:(CGSize)size
{
    _dimensions = size;
    _node->style.maxDimensions[0] = size.width;
    _node->style.maxDimensions[1] = size.height;
}

- (void)setFlexDirection:(FLEXBOXFlexDirection)flexDirection
{
    _flexDirection = flexDirection;
    _node->style.flex_direction = (int)flexDirection;
}

- (void)setMargin:(UIEdgeInsets)margin
{
    _margin = margin;
    _node->style.margin[0] = margin.left;
    _node->style.margin[1] = margin.top;
    _node->style.margin[2] = margin.right;
    _node->style.margin[3] = margin.bottom;
}

- (void)setPadding:(UIEdgeInsets)padding
{
    _padding = padding;
    _node->style.padding[0] = padding.left;
    _node->style.padding[1] = padding.top;
    _node->style.padding[2] = padding.right;
    _node->style.padding[3] = padding.bottom;
}

- (void)setFlex:(CGFloat)flex
{
    _flex = flex;
    _node->style.flex = flex;
}

- (void)setFlexWrap:(BOOL)flexWrap
{
    _flexWrap = flexWrap;
    _node->style.flex_wrap = flexWrap;
}

- (void)setJustifyContent:(FLEXBOXJustification)justifyContent
{
    _justifyContent = justifyContent;
    _node->style.justify_content = (int)justifyContent;
}

- (void)setAlignItems:(FLEXBOXAlignment)alignItems
{
    _alignItems = alignItems;
    _node->style.align_items = (int)alignItems;
}

- (void)setAlignSelf:(FLEXBOXAlignment)alignSelf
{
    _alignSelf = alignSelf;
    _node->style.align_self = (int)alignSelf;
}

- (void)setContentDirection:(FLEXBOXContentDirection)contentDirection
{
    _contentDirection = contentDirection;
    _node->style.direction = (int)contentDirection;
}

@end

#pragma mark - Parse CSS value

id FLEXBOX_parseCSSValue(NSString* cssValue)
{
    NSDictionary *mapping = @{
        
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
    
    return mapping[cssValue];
    
}



