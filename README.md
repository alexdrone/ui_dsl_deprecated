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

##Left Hand-side Values

The property name can be arbitrary, and the keys are translated from dash notation to camelCase notation at parse time.

If it matches a class `keyPath`, the value is evaluated and automatically set to any view that 
matches the current selector.

Otherwise the properties can be accessed from within the view's dictionary stored inside the 
property `rflk_computedProperties` defined in ReflektorKit's UIView category.
e.g. `[self.rflk_computedProperties[@"anyCustomKey"] valueWithTraitCollection:self.traitCollection bounds:self.bounds]`



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
}


```

##Attribuitions

The list of third-party libraries is following:

- https://github.com/jlawton/UIColor-HTMLColors
- https://github.com/tracy-e/ESCssParser
- https://github.com/steipete/RFLKAspects

- *logo* from: https://dribbble.com/BSteely 

