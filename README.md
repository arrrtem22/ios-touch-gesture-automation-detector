# Touch Signal

Native iOS touch-gesture inspector with live trails and telemetry.

![Gesture diagnostics](assets/gestures.png)

## Features

- Live grid, path, contact-radius, and endpoint display
- Touch position, force, timing, and multi-touch telemetry
- Active WebDriverAgent detection through its on-device HTTP and MJPEG services
- Clear diagnostics view for accessibility and automation signals

## Run

Open `TouchSignal.xcodeproj` in Xcode and run on iOS 17+.

The WDA verdict is based on its standard on-device services (HTTP port `8100` and optional MJPEG port `9100`). UIKit touch geometry is not used as proof because a completed finger touch may also report zero radius or force.
