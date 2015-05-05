![GitHub Logo](logo.png)

**ReflektorKit** is a stylesheet engine for iOS compatible with *Objective-C* and *Swift* on *iOS8+* that allows you to style your application in a semantic and reusable fashion, even at runtime.


The stylesheet language can be considered a *LESS/CSS* dialect, even though it's been designed specifically to map some UIKit patterns and behaviours, therefore — **it is not CSS**.

Infact many *CSS* concepts (such as *class* and *id*) are missing and replaced by other more UIKit-friendly constructs.


##Getting started

- TODO


##Stylesheet

```css

/* Variable namespeace (must start with @). */
@global
{
	@blue = hsl(120, 100%, 75%);
}

/* 
	Selectors: 
	Only one selector per scope is allowed — so selector1, selector2 {} is valid in CSS, but not here.
	The valid selectors are:
	
	- ObjCClass (I)
	- trait (II)
	- ObjCClass:trait (III)
	- ObjCClass:__where (condition modifier on I)
	- trait:__where (condition modifier on II)
	- ObjCClass:trait:__where (condition modifier on III)

*/

/* trait selector (it is not possible to define more than one trait in a single selector). */
rounded
{	
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
UIView
{
	background-color: #ff0000;
}

/* class + trait selector (override, it is constrained to a single trait per selector). */
UIView:circularView
{
	/* The 'include' directive includes the definition of other traits or classes inside this selector scope */
	include: rounded, foo, UILabel;
	background-color: @blue;
}

/*
  Any of the previous declared selector can append the special :__where trait.
  If :__where is defined, the selector's properties are computed only if the condition string 
  defined in the 'condition' property is satisfied.
 */
UIView:__where
{
	condition: 'idiom = pad and width < 200 and vertical = regular';
	border-width: 2px;
	border-color: @blue;
}

/* Collection of valid right-hand side values */
foo
{
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
