![GitHub Logo](logo.png)

**ReflektorKit** is a stylesheet engine for iOS compatible with Objective-C and Swift on iOS8+.

##Getting started

- TODO


##Stylesheet

```css

/*Variable namespeace*/
@global
{
	@blue = hsl(120, 100%, 75%);
}

/*Selectors*/

/*trait (similar to a css' class)*/
trait:rounded
{
	corner-radius: 50%;
}

/*class selector (where class is an existing obj-c class)*/
class:UIView
{
	background-color: #ff0000;
	any-custom-key: 50px;
}

/*class + trait (override)*/
class:UIView.trait:focused
{
	!include: trait:rounded;
	background-color: #00ff00;
}

/*computed only if the condition is satisfied*/
class:UIView
{
	!condition: 'idiom = pad and width < 200 and vertical = regular';
	border-width: 2px;
	border-color: @blue;
}

/*Right-hand side supported values*/
trait:rhs
{
	!include: trait:otherTrait, class:aClass;
	!condition: 'idiom = pad and width < 200 and vertical = regular';
	color-one: #00ff00;
	color-two: rgb(255, 0, 0);
	color-three: rgba(255, 0, 0, 0.3);
	color-four: hsl(120, 100%, 75%);
	color-five: hsla(120, 60%, 70%, 0.3);
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
