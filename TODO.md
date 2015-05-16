##ReflektorKit TODOs

- `applies-to-subclasses` doesn't always seem to be working. For example the following style doesn't render to the expected result 

```css
UIView {
    applies-to-subclasses: true;
    border-color: @blue !important;
    border-width: 1px !important;
}
```

- add support for `image(name.extension)`
- add support for `image-from-color(color)`
- add support for `image-from-icon(font, icon-char)`
