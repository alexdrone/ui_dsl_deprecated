# Reflektor

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Build](https://img.shields.io/badge/build-passing-green.svg?style=flat)](#)
[![Build](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)](https://opensource.org/licenses/MIT)


**Reflektor** is a **lightweight** extensible native stylesheet engine for iOS written in *Swift* and compatible with *Objective-C* and *Swift* on *iOS8+* that allows you to style your application in a semantic and reusable fashion, even at runtime.
With ReflektorKit, you can replace many tedious and redudant lines of Objective-C or Swift with a few lines in the stylesheet, and be able to apply this changes real-time, without rebuilding the app.


The stylesheet language can be considered a *LESS/CSS* dialect, even though it's been designed specifically to map some UIKit patterns and behaviours, therefore — **is not CSS**.

Infact many *CSS* concepts (such as *class* and *id*) are missing and replaced by other more UIKit-friendly constructs.

## Installation

### Carthage

To install Carthage, run (using Homebrew):

```bash
$ brew update
$ brew install carthage
```

Then add the following line to your `Cartfile`:

```
github "alexdrone/Reflektor" "master"    
```

### Reflektor Watchfile Server

Reflektor has live reload capabilities. That means that you can edit your stylesheet and see the results in your simulator right away.

In order to do so you need to install **refl**, the watchfile daemon.

Copy and paste this command in your terminal to obtain **refl**:

```
git clone https://github.com/alexdrone/Reflektor.git && cd Reflektor && cp refl /usr/local/bin/refl && chmod +x /usr/local/bin/refl
```

The usage of the watchfile is very simple
```
refl PROJECT_PATH
```

The daemon will look for changes in your *.refl.less* files and refresh the instance of your app in the simulator.

##Getting started

- Creates your stylesheet files (use .less as file extension if you want to have good higlighting support from most editors).
- Create a `main.less` stylesheet. From here you can import all the others stylesheets:

```css

@import url("master.less");
@import url("detail.less");

```
 
- Add this to your AppDelegate:

```swift

func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
       
	AppearanceManager.sharedManager.loadStylesheetFromFile("main", fileExtension: "less")
	
		//...
    }

```

## Terminology

```css
SELECTOR {
	(scope)
	LEFT-HAND SIDE EXPR (property): RIGHT-HAND SIDE EXPR (value);
}
```

## Selectors

Only one selector per scope is allowed — so `selector1, selector2 {}` is valid in *CSS*, but not here.

The only valid selectors are the following:

- `ObjClass {}` (I)
- `trait {}` (II, NB: Only one trait is allowed)
- `ObjClass:trait {}` (III, NB: Only one trait is allowed)
- `ObjClass:__where {}` (*condition modifier* on I, see the **Conditions** section to know more about the condition construct)
- `trait:__where {}` (*condition modifier* on II)
- `ObjClass:trait:__where {}` (*condition modifier* on III)
- `@namespace {}` (variables namespace)

Example of valid selectors are the following

- `UILabel {}` (I)
- `MyApp.FooLabel {}` (I)
- `redLabel {}` (II)
- `UILabel:redLabel {}` (III)
- `UIView:__where {}` (*condition modifier* on I)
- `rounded:__where {}` (*condition modifier* on II)
- `UIView:rounded:__where {}` (*condition modifier* on III)
- `@globals {}` (variables namespace)

N.B: In Swift the `ObjClass` should have the project namespace

You can use the `__include` directive to include the definitions from the scope of other selectors inside a selector.

e.g.

```css

UIButton {
	text-color: #ff00ff;
}

rounded {
	corner-radius: 50%;
}

UILabel {
	__include: UIButton, rounded;
}
```

If the `:__where` special trait is defined in the selector, the selector's properties are computed only if the condition string defined in the '__condition' property is satisfied.

e.g.

```css
UIView:__where {
	__condition: 'idiom = pad and width < 200 and vertical = regular';
	border-width: 2px;
	border-color: @blue;
}
```

To know more about the conditions syntax and semantic, see the **Conditions** section.

## Left-Hand Side Values

The property name is arbitrary, and the keys are translated from dash notation to camelCase notation at parse time.

If it matches a class `keyPath`, the value is evaluated and automatically set to any view that 
matches the current selector.

The `--` separator is converted to `.` in order to create more complex keypaths.
e.g. `avatar-view--background-color` is translated to `avatarView.backgroundColor`.

Otherwise the properties can be accessed from within the view's dictionary stored inside the 
property `rflk_computedProperties` defined in Reflektor's UIView category.
e.g. `self.rflk_computedProperties[@"anyCustomKey"].value(withTraitCollection:self.traitCollection, bounds:self.bounds)`


## Right-Hand Side Values

N.B. All the components inside this rhs functions can be variables (prefixed with `@`).

- `X` pixel unit
- `X px` pixel unit
- `X pt` point unit
- `X %` % unit, calculated on the bounds of the view *
- `'foo'` a string
- `true` or `false` for a boolean
- `#FFFFFF` hex color code)
- `rgb(red, green, blue)` RGB color
- `rgb(red, green, blue, alpha)` RGB color with alpha component
- `hsl(hue, saturation, lightness)` HSL color
- `hsla(hue, saturation, lightness, alpha)` HSL color with alpha component
- `linear-gradient(@color1, @color2)` linear gradient between 2 colors. The two colors can appear as any of the previous definition, or as a variable *
- `font('fontName', X pt)` font, the fontname and the point size
- `font('fontName', X %)` font, the fontname and the size is gonna be calculated at layout time as dependant from the view bounds *
- `rect(X px, Y px, WIDTH px, HEIGHT px)` a CGRect
- `point(X px, Y px)` a CGPoint
- `size(WIDTH px, HEIGHT px)` a CGSize
- `edge-insets(LEFT px, TOP px, RIGHT px, BOTTOM px)` a UIEdgeInsets
- `locale('KEY')` a NSLocalizedString
- `transform-scale(WIDHT, HEIGHT)` a CGAffineTransform
- `transform-rotate(Xrad)` a CGAffineTransform
- `transform-translate(X px, Y px)` a CGAffineTransform
- `vector(VAL, VAL, ...)` an NSArray whose components can be any of the previous definitions (or a variable) **but not** a nested vector.
- `image('imageName')` for an image.
- `image(COLOR)` for an image from a color (even a linear-gradient!).
- `flexible-height,flexible-width,flexible-left-margin,flexible-right-margin,flexible-top-margin,flexible-bottom-margin` as valid UIViewAutoresingMask values (the comma between the values is interpreted as an OR between the options).


### The `!important` modifier

**N.B. The meaning of `!important` is extremely different from CSS **

By default the style is applied after the view initialisation and when the view traits (@see `UIView.traits`) change.
You can alter this behaviour and have the views to compute and apply a specific rule by appending the `!important` modifier to it.

```css
UILabel {
	background-color: @red !important;
	border-color: @blue !important;
}
```

If the right-hand side value of a directive uses a `%` unit or is a `linear-gradient`, the `!important` modifier is automatically added to it.

### Plugins

You can write extension in order to define a new datatype for your rules.
To do so you simply have to write a class that conforms  the `PropertyValuePlugin` protocol and register an instance by calling `Configuration.sharedConfiguration.registerPropertyValuePlugin(plugin: PropertyValuePlugin)`

##Special Directives


### The `__condition`directive

If a selector is *conditional* is must be suffixed with the special trait `:__where` (e.g. `XYZButton:__where`).
Furthermore a `__condition` directive should be defined within the scope of the conditional selector.

```css
SELECTOR:__where {
	__condition: @condition;
}
```

The right-hand side of a 'condition' has the following syntax

```
	CONDITION := 'EXPR and EXPR and ...' //e.g. 'width < 200 and vertical = compact and idiom = phone'
	EXPR := SIZE_CLASS_EXPR | SIZE_EXPR | IDIOM_EXPR 
	SIZE_CLASS_EXPR := (horizontal|vertical)(=|!=)(regular|compact) // e.g. horizontal = regular
	SIZE_EXPR := (width|height)(<|<=|=|!=|>|>=)(SIZE_PX) //e.g. width > 320
	SIZE_PX := (0-9)+ //e.g. 42, a number
	IDIOM_EXPR := (idiom)(=|!=)(pad|phone) //e.g. idiom = pad

```

So an example of a conditional selector is the following

```css
UIView:__where {
	__condition: 'idiom = pad and width < 200 and vertical = regular';
	border-width: 2px;
	border-color: @blue;
}
```

The properties are computed only if the view matches the condition expressed in the condition string.

#### External (or custom) conditions

You can define some condition in code and bound them to a unique key that can be referenced inside the stylesheet. e.g. 

```swift
            Configuration.sharedConfiguration.registerExternalCondition("alwaysFalse", conditionClosure: { (view, traitCollection, size) -> Bool in
                return false
            })
            
            Configuration.sharedConfiguration.registerExternalCondition("alwaysTrue", conditionClosure: { (view, traitCollection, size) -> Bool in
                return true
            })
                        
```



You can reference these custom conditon by their key + `?` as prefix.


```css
UIView:__where {
	__condition: '?alwaysFalse and ?alwaysTrue';
}
```

### The `__include`directive

You can use the `include` directive to include the definitions from the scope of other selectors inside a selector.

e.g.

```css

UIButton {
	text-color: #ff00ff;
}

rounded {
	corner-radius: 50%;
}

UILabel {
	__include: UIButton, rounded;
}
```

## Included UIKit's categories

Included in Reflektor there are some handy categories to access some UIView's properties from the stylesheet:


```swift

UIView: 

///Redirects to 'layer.cornerRadius'
var cornerRadius: CGFloat

///Redirects to 'layer.borderWidth'
var borderWidth: CGFloat

///Redirects to 'layer.borderColor'
var borderColor: UIColor 

///Frame helper (self.frame.origin.x)
var x: CGFloat

///Frame helper (self.frame.origin.y)
var y: CGFloat

///Frame helper (self.frame.size.width)
var width: CGFloat

///Frame helper (self.frame.size.height)
var height: CGFloat

///The opacity of the shadow. Defaults to 0. Specifying a value outside the
var hadowOpacity: CGFloat

///The blur radius used to create the shadow. Defaults to 3.
var shadowRadius: CGFloat

///The shadow offset. Defaults to (0, -3)
var shadowOffset: CGSize

///The color of the shadow. Defaults to opaque black.
var shadowColor: UIColor


UIButton:

var text: String
var highlightedText: String
var selectedText: String
var disabledText: String

//Symeetrical to  -[UIButton titleColorForState:]
var textColor: UIColor
var highlightedTextColor: UIColor
var selectedTextColor: UIColor
var disabledTextColor: UIColor

//..and so on

```


## Example of a stylesheet

```css

/* Variable namespeace (must start with @). */
@global {
	@blue = hsl(120, 100%, 75%);
}

/* Selectors: */

/* trait selector (it is not possible to define more than one trait in a single selector). */
rounded {	
	/*
	  the property name can be arbitrary. 
	  Their names are translated from dash notation to camelCase at parse time
	  If it matches a class keyPath, the value is evaluated and automatically set to any view that 
	  matches the current selector.
	  Otherwise the properties can be accessed from within the view's dictionary stored inside the 
	  property rflk_computedProperties defined in ReflektorKit's UIView category.
	  */
	corner-radius: 50%;
	any-custom-key: 50px;
}

/* class selector (can be any valid Obj-C class that inherits from UIView). */
UIView {
	background-color: #ff0000;
}

/* class + trait selector (override, it is constrained to a single trait per selector). */
UIView:circularView {
	/* The 'include' directive includes the definition of other traits or classes inside this selector scope */
	__include: rounded, foo, UILabel;
	background-color: @blue;
}

/*
  Any of the previous declared selector can append the special :__where trait.
  If :__where is defined, the selector's properties are computed only if the condition string 
  defined in the 'condition' property is satisfied.
 */
UIView:__where {
	__condition: 'idiom = pad and width < 200 and vertical = regular';
	border-width: 2px;
	border-color: @blue;
}

UILabel:small {
	apply-to-subclasses: true; /*This means that all the subclasses of UILabel that also have a 'small' trait defined will apply this style*/
	font: font('Arial', 12pt) !important; /*!important means that this rule is going to be set at layout time layoutSubviews*/
}

/* Collection of valid right-hand side values */
foo {
	__include: rounded, UIView;
	__condition: 'idiom = pad and width < 200 and vertical = regular';
	color-one: #00ff00;
	color-two: rgb(255, 0, 0);
	color-three: rgba(255, 0, 0, 0.3);
	color-four: hsl(120, 100%, 75%);
	color-five: hsla(120, 60%, 70%, 0.3);
	gradient: linear-gradient(@blue, #00ff00);
	font: font('Arial', 16pt);
	font-two: font('Arial', 50%);
	number: 23.4px;
	percent: 50%;
	bool-one: true;
	bool-two: false;
	string: 'A string';
	rect: rect(0px, 0px, 100px, 200px);
	point: point(100px, 200px);
	size: size(123px, 456px);
	edge: edge-insets(1px, 2px, 3px, 4px);
	text: locale('KEY');
	vector: vector(2px, 23px, #bbbbbb, #cccccc);
	
	/* Most UIKit's enums and options have a reserved keyword in the stylesheet
	The ',' between the two is interpreted as an OR ( '|' ) */
	autoresizing-mask: flexible-height,flexible-width,flexible-left-margin,flexible-right-margin,flexible-top-margin,flexible-bottom-margin;
	 
	content-mode: mode-scale-to-fill;
}

```

## Selectors

- Add :__where clausole to traits as well


## Attribuitions

The list of third-party libraries used for this project is the following:

- https://github.com/jlawton/UIColor-HTMLColors
- https://github.com/tracy-e/ESCssParser
- *logo* from: https://dribbble.com/BSteely 

