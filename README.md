# Touch Signal

Native iOS touch-gesture inspector with live trails and telemetry.

![Gesture diagnostics](assets/gestures.png)

## Features

- Live grid, path, contact-radius, and endpoint display
- Touch position, force, timing, and multi-touch telemetry
- WebDriverAgent gesture detection from sustained zero-force and synthetic radius patterns
- Clear diagnostics view for accessibility and automation signals

## Run

Open `TouchSignal.xcodeproj` in Xcode and run on iOS 17+.

The WDA verdict evaluates touch geometry throughout `began` and `moved`. Confirmation requires sustained zero force, zero radius tolerance, and either zero or unnaturally stable radius. Radius tolerance prevents zero-force devices from misclassifying physical fingers. The final `ended` sample is excluded, while the UI retains meaningful values and separately shows raw terminal values.
