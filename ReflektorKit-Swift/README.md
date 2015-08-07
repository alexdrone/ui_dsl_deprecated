<p align="center">
![GitHub Logo](logo.png)


**ReflektorKit** is a **lightweight** extensible native stylesheet engine for iOS written in *Swift* and compatible with *Objective-C* and *Swift* on *iOS8+* that allows you to style your application in a semantic and reusable fashion, even at runtime.
With ReflektorKit, you can replace many complicated lines of Objective-C or Swift with a few lines in the stylesheet, and be able to apply this changes real-time, without rebuilding the app.


The stylesheet language can be considered a *LESS/CSS* dialect, even though it's been designed specifically to map some UIKit patterns and behaviours, therefore — **it is not CSS**.

Infact many *CSS* concepts (such as *class* and *id*) are missing and replaced by other more UIKit-friendly constructs.

###Why ReflektorKit and not Pixate Freestyle or XYZ?

There are many libraries that offers a way to style native controls, but many times they have a completely different rendering pipeline that makes them incompatible with vanilla custom made uikit controls and they don't offer low level control over the styling of your components.

Moreover the aim of these libraries is to port *all of the CSS practices and concepts* to the iOS platform, and I believe this is often an overkill and not an optimal fit.

ReflektorKit was made with UIKit in mind: it takes full advantage of all the capabilities UIKit offers out-of-the-box (such as *size classes*, *appearance selectors* and more) and it doens't fight the platform.

With ReflektorKit you can have fine control over when a stylesheet property is computed and applied in the lifecycle of UIView.

Furthermore the properties defined in the scope a stylesheet selectors are purely *keyPaths*, making it straight-forward to style custom components or supply custom appearance selectors to a view. 

Additionaly ReflektorKit is **extensible** - it allows you to write plugin and extensions (for example to parse a custom kind of value, or define a custom condition for the rules to be computed) 

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
property `REFL_computedProperties` defined in ReflektorKit's UIView category.
e.g. `self.REFL_computedProperties["anyKey"].computeValue(self.traitCollection size:self.bounds)`

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

####External (or custom) conditions

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
	condition: '?alwaysFalse and ?alwaysTrue';
}
```

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

##Included UIKit's categories

TODO


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
	  property REFL_computedProperties defined in ReflektorKit's UIView category.
	  e.g. [self.REFL_computedProperties[@"anyCustomKey"] valueWithTraitCollection:self.traitCollection bounds:self.bounds]
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
}

```


##Attribuitions

The list of third-party libraries is following:

- https://github.com/jlawton/UIColor-HTMLColors
- https://github.com/tracy-e/ESCssParser
- https://github.com/steipete/REFLAspects
- *logo* from: https://dribbble.com/BSteely 

