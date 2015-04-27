//
//  RFLKAppearance.h
//  ReflektorKit
//
//  Created by Alex Usbergo on 22/04/15.
//  Copyright (c) 2015 Alex Usbergo. All rights reserved.
//

@import UIKit;

extern NSString *RFLKApperanceStylesheetDidChangeNotification;

@interface UIView (RFLKAppearance)

/// All the computed properties for this view
@property (nonatomic, strong) NSDictionary *RFLK_computedProperties;

/// The current set of traits that belong to this view
@property (nonatomic, readonly) NSSet *RFLK_traits;

/// Add a trait to this view
/// @note Call 'setNeedsLayout' to re-apply the correct style for this view
- (void)RFLK_addTrait:(NSString*)traitName;

/// Remove an existing trait to this view
/// @note Call 'setNeedsLayout' to re-apply the correct style for this view
- (void)RFLK_removeTrait:(NSString*)traitName;

/// Default getter for a computed property.
/// Uses the main screen bounds and its traitCollection
- (id)RFLK_property:(NSString*)propertyName;

/// Getter for a computed property
- (id)RFLK_property:(NSString*)propertyName withTraitCollection:(UITraitCollection*)traitCollection andBounds:(CGSize)size;

/// Called when the stylesheet changes.
- (void)RFLK_stylesheetDidChangeNotification:(id)notification;

@end


@interface RFLKAppearance : NSObject

/// The map for all stylesheet selectors
@property (nonatomic, readonly) NSDictionary *propertyMap;

/// Return the shared instance for the main appearance proxy
+ (instancetype)sharedAppearance;

/// Initialise the appearance with the given stylesheet data
- (void)parseStylesheetData:(NSString*)stylesheet;

/// Apply the style from the stylesheet
- (NSDictionary*)computeStyleForView:(UIView*)view;

@end
