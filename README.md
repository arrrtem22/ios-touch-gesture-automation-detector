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

The WDA verdict evaluates touch geometry throughout `began` and `moved`. It recognizes both zero-radius injection and the constant synthetic radius seen in WDA swipes when force remains zero. The final `ended` sample is excluded from classification, and the UI retains the last meaningful radius and force while also showing the raw terminal values.
