# Touch Signal

A native UIKit iOS touch-gesture inspection tool with a dark diagnostics interface inspired by the supplied reference.

## What it does

- Draws live direct-touch paths on a calibrated grid.
- Shows every point, estimated touch radius, force, timing, and multi-touch count.
- Marks current touch endpoints with a crosshair and retains a short visual trail.
- Presents accessibility/controller signal status and a transparent, heuristic automation verdict.

## Run

Open `TouchSignal.xcodeproj` in Xcode 26 or later, choose an iPhone/iPad simulator or device, then run. The project targets iOS 17+ and needs no third-party dependencies.

> The automation panel is a visual diagnostic heuristic, not a security control. iOS intentionally limits apps’ ability to identify system-wide automation.
