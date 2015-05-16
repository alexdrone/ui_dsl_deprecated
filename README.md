<p align="center">
![GitHub Logo](logo.png)


**ReflektorKit** is a **lightweight** native stylesheet engine for iOS compatible with *Objective-C* and *Swift* on *iOS8+* that allows you to style your application in a semantic and reusable fashion, even at runtime.
With ReflektorKit, you can replace many complicated lines of Objective-C or Swift with a few lines in the stylesheet, and be able to apply this changes real-time, without rebuilding the app.


The stylesheet language can be considered a *LESS/CSS* dialect, even though it's been designed specifically to map some UIKit patterns and behaviours, therefore — **it is not CSS**.

Infact many *CSS* concepts (such as *class* and *id*) are missing and replaced by other more UIKit-friendly constructs.

###Why ReflektorKit and not Pixate Freestyle or XYZ?

There are many libraries that offers a way to style native controls, but many times they have a completely different rendering pipeline that makes them incompatible with vanilla custom made uikit controls and they don't offer low level control over the styling of your components.

Moreover the aim of these libraries is to port *all of the CSS practices and concepts* to the iOS platform, and I believe this is often an overkill and not an optimal fit.

ReflektorKit was made with UIKit in mind: it takes full advantage of all the capabilities UIKit offers out-of-the-box (such as *size classes*, *appearance selectors* and more) and it doens't fight the platform.

With ReflektorKit you can have fine control over when a stylesheet property is computed and applied in the lifecycle of UIView.

Furthermore the properties defined in the scope a stylesheet selectors are purely *keyPaths*, making it straight-forward to style custom components or supply custom appearance selectors to a view. 



##Getting started

- TODO

##Terminology

```css
SELECTOR {
	(scope)
	LEFT-HAND SIDE EXPR (property): RIGHT-HAND SIDE EXPR (value);
}
```

##Selectors

Only one selector per scope is allowed — so `selector1, selector2 {}` is valid in *CSS*, but not here.

The only valid selectors are the following:

- `ObjCClass {}` (I)
- `trait {}` (II, NB: Only one trait is allowed)
- `ObjCClass:trait {}` (III, NB: Only one trait is allowed)
- `ObjCClass:__where {}` (*condition modifier* on I, see the **Conditions** section to know more about the condition construct)
- `trait:__where {}` (*condition modifier* on II)
- `ObjCClass:trait:__where {}` (*condition modifier* on III)
- `@namespace {}` (variables namespace)

Example of valid selectors are the following

- `UILabel {}` (I)
- `redLabel {}` (II)
- `UILabel:redLabel {}` (III)
- `UIView:__where {}` (*condition modifier* on I)
- `rounded:__where {}` (*condition modifier* on II)
- `UIView:rounded:__where {}` (*condition modifier* on III)
- `@globals {}` (variables namespace)

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
	include: UIButton, rounded;
}
```

If `:__where` special trait is defined in the selector, the selector's properties are computed only if the condition string defined in the 'condition' property is satisfied.

e.g.

```css
UIView:__where {
	condition: 'idiom = pad and width < 200 and vertical = regular';
	border-width: 2px;
	border-color: @blue;
}
```

To know more about the conditions syntax and semantic, see the **Conditions** section.

##Left-Hand Side Values

The property name can be arbitrary, and the keys are translated from dash notation to camelCase notation at parse time.

If it matches a class `keyPath`, the value is evaluated and automatically set to any view that 
matches the current selector.

Otherwise the properties can be accessed from within the view's dictionary stored inside the 
property `rflk_computedProperties` defined in ReflektorKit's UIView category.
e.g. `[self.rflk_computedProperties[@"anyCustomKey"] valueWithTraitCollection:self.traitCollection bounds:self.bounds]`


##Right-Hand Side Values

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

### The `!important` modifier

**N.B. The meaning of `!important` is extremely different from CSS **

By default the style is applied after the view initialisation and when the view traits (@see `-[UIView rflk_traits]`) change.
You can alter this behaviour and have the views to compute and apply a specific rule by appending the `!important` modifier to it.

```css
UILabel {
	background-color: @red !important;
	border-color: @blue !important;
}
```

If the right-hand side value of a directive uses a `%` unit or is a `linear-gradient`, the `!important` modifier is automatically added to it.


##Special Directives


### The `condition`directive

If a selector is *conditional* is must be suffixed with the special trait `:__where` (e.g. `XYZButton:__where`).
Furthermore a `condition` directive should be defined within the scope of the conditional selector.

```css
SELECTOR:__where {
	condition: @condition;
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
	condition: 'idiom = pad and width < 200 and vertical = regular';
	border-width: 2px;
	border-color: @blue;
}
```

The properties are computed only if the view matches the condition expressed in the condition string.

### The `include`directive

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
	include: UIButton, rounded;
}
```

### The `applies-to-subclasses` directive

By default, in order to improve the performance to compute the style for a view, the class rule for the selector is matched only if the class specified in the selector is exactly the same as the target view.

If you wish to apply a style to all its subclasses (e.g. you specify some rules for UILabel and you want all the UILabel's subclasses to behave in the same way) you just have to define the `applies-to-subclasses` and set it to `true`

e.g.

```css

UILabel {
	applies-to-subclasses: true;
}
```

##Flexbox

ReflektorKit includes **Facebook**'s implementation of CSS'*Flexbox* and wraps all the flexbox directives in a UIView category.
To make a view a flexbox container (a view that lays out its children using flexbox directives) you simply have to set the UIView's category property `flexContainer` to `YES`.

e.g.

```css

UILabel {
	flex-container: true;
}
```
Once you've done that, you can define your layout logic using the following flexbox properties (see `UIView+FLEXBOX`)

```css

UILabel {
	/* The minumum size for this element */
	flex-minimum-size: size(...,...);
	
	/* The maximum size for this element */
	flex-maximum-size: size(...,...);
	
	/* if you wish to have a fixed size for this element */
	flex-fixed-size: size(...,...);
	
	/* It establishes the main-axis, thus defining the direction flex items are placed in the flex container. */
	flex-direction: row|column|row-reverse|colum-reverse;
	
	/* The margins for this flex item (default is 0) */
	flex-margin: edge-insets(...,...,...,...);
	
	/* The padding for this flex item (default is 0) */
	flex-padding: edge-insets(...,...,...,...);
	
	/* Make the flexible items wrap if necesarry (default is wrap)*/
	flex-wrap: wrap|nowrap;
	
	/* It defines the alignment along the main axis. It helps distribute extra free 
	space leftover when either all the flex items on a line are inflexible, or are 
	flexible but have reached their maximum size. It also exerts some control over 
	the alignment of items when they overflow the line (default is flex-start) */
	flex-justify-content: flex-start|flex-end|center|space-between|space-around;
	
	/* Center the alignments for one of the items inside a flexible element (default is auto) */
	flex-align-self: auto|stretch|center|flex-start|flex-end;
	
	/* Center the alignments for one of the items inside a flexible element (default is stretch) */
	flex-align-items: stretch|center|flex-start|flex-end;
	
	/* The flex property specifies the initial length of a flexible item */
	flex: 1;	
}
```


##Example of a stylesheet

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
	  e.g. [self.rflk_computedProperties[@"anyCustomKey"] valueWithTraitCollection:self.traitCollection bounds:self.bounds]
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
	include: rounded, foo, UILabel;
	background-color: @blue;
}

/*
  Any of the previous declared selector can append the special :__where trait.
  If :__where is defined, the selector's properties are computed only if the condition string 
  defined in the 'condition' property is satisfied.
 */
UIView:__where {
	condition: 'idiom = pad and width < 200 and vertical = regular';
	border-width: 2px;
	border-color: @blue;
}

UILabel:small {
	apply-to-subclasses: true; /*This means that all the subclasses of UILabel that also have a 'small' trait defined will apply this style*/
	font: font('Arial', 12pt) !important; /*!important means that this rule is going to be set at layout time -[layoutSubviews]*/
}

/* Collection of valid right-hand side values */
foo {
	include: rounded, UIView;
	condition: 'idiom = pad and width < 200 and vertical = regular';
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
	
	/* Flexbox directives*/
	flex-minimum-size: size(100px, 20px);
	flex-maximum-size: size(100px, 20px);
	flex-fixed-size: size(50px, 50px);
	flex-direction: row;
	flex-margin: edge-insets(8px,8px,8px,8px);
	flex-padding:  edge-insets(8px,8px,8px,8px);
	flex-wrap: wrap;
	flex-justify-content: center;
	flex-align-self: stretch;
	flex-align-items: center;
	flex: 1;	
}

```

##Attribuitions

The list of third-party libraries is following:

- https://github.com/jlawton/UIColor-HTMLColors
- https://github.com/tracy-e/ESCssParser
- https://github.com/steipete/RFLKAspects
- *logo* from: https://dribbble.com/BSteely 

