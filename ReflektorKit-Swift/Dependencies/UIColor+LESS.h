
@import UIKit;

/**
 * Extensions to read and write colors in the formats supported by RFLKLESS.
 * Emphasis has been given to parsing corrently formatted colors, rather
 * than rejecting technically invalid colors.
 */
@interface UIColor (HTMLColors)

+ (UIColor*)gradientFromColor:(UIColor*)color1 toColor:(UIColor*)color2 withSize:(CGSize)frame;

/**
 * Reads a color from a string containing hex, RGB, HSL or X11 named color.
 * Returns `nil` on failure.
 */
+ (UIColor *)LESS_colorWithCSSColor:(NSString *)cssColor;

/**
 * Reads a color from a string containing a hex color, of the form
 * "#FFFFFF" or "#FFF".
 * Returns `nil` on failure.
 */
+ (UIColor *)colorWithHexString:(NSString *)hexColor;

/**
 * Reads a color from a string containing an RGB color, of the form
 * "rgb(255, 255, 255)" or "rgba(255, 255, 255, 1.0)". Supports components
 * represented as percentages.
 * Returns `nil` on failure.
 */
+ (UIColor *)colorWithRGBString:(NSString *)rgbColor;

/**
 * Reads a color from a string containing an HSL color, of the form
 * "hsl(359, 100%, 100%)" or "hsla(359, 100%, 100%, 1.0)".
 * Returns `nil` on failure.
 */
+ (UIColor *)colorWithHSLString:(NSString *)hslColor;

/**
 * Reads a color from a string containing a W3C named color.
 * Returns `nil` on failure.
 */
+ (UIColor *)colorWithW3CNamedColor:(NSString *)namedColor;

/**
 * Returns a representation of this color as a hex string, of the form "#FFFFFF".
 * Alpha information is not represented.
 */
- (NSString *)hexStringValue;

/**
 * Returns a representation of this color as an RGB string, of the form
 * "rgb(255, 255, 255)" or "rgba(255, 255, 255, 1.0)".
 * Returns `nil` on failure.
 */
- (NSString *)rgbStringValue;

/**
 * Returns a representation of this color as an RGB string, of the form
 * "hsl(359, 100%, 100%)" or "hsla(359, 100%, 100%, 1.0)".
 * Returns `nil` on failure.
 */
- (NSString *)hslStringValue;

/**
 * FOR DEBUGGING - All the supported W3C color names.
 */
+ (NSArray *)W3CColorNames;

@end


/**
 * Extensions to scan colors in the formats supported by RFLKLESS.
 */
@interface NSScanner (HTMLColors)

/**
 * Scan a color hex, RGB, HSL or X11 named color.
 */
- (BOOL)scanRFLKLESSColor:(UIColor **)color;

/**
 * Scan an RGB color ("rgb(255, 255, 255)", "rgba(255, 255, 255, 1.0)").
 */
- (BOOL)scanRGBColor:(UIColor **)color;

/**
 * Scan an HSL color ("hsl(359, 100%, 100%)", "hsla(359, 100%, 100%, 1.0)").
 */
- (BOOL)scanHSLColor:(UIColor **)color;

/**
 * Scan a hex color ("#FFFFFF", "#FFF").
 */
- (BOOL)scanHexColor:(UIColor **)color;

/**
 * Scan a RFLKLESS3/SVG named color. These are similar to the X11 named colors.
 * See: http://www.w3.org/TR/css3-color/#svg-color
 */
- (BOOL)scanW3CNamedColor:(UIColor **)color;

@end

@interface UIEGradientColor : NSObject

- (instancetype)initWithColor1:(UIColor*)color1 color2:(UIColor*)color2;
- (UIColor*)gradientWithSize:(CGSize)size;

@end

@interface UIImage (RFLKAdditions)

+ (UIImage*)imageWithColor:(UIColor*)color;
+ (UIImage*)imageWithColor:(UIColor*)color size:(CGSize)size;

@end