# Meta Vision

Meta Vision is an iOS assistant designed to help blind and low-vision users read documents quickly and accurately through Meta Ray-Ban glasses.

The planned experience is:

`Capture with glasses → enhance image → OCR → Gemma verification → speak aloud`

## Current status

This repository contains the initial SwiftUI iOS project foundation and the product roadmap. The glasses integration, OCR pipeline, Gemma integration, and hands-free controls are planned next.

## Planned MVP

- Connect to standard Meta Ray-Ban glasses.
- Capture a document from the glasses camera.
- Extract and verify text with OCR and Gemma.
- Read the result through the glasses’ open-ear speakers.
- Support “read this,” “repeat,” “summarize,” and “stop.”
- Provide clear feedback when an image is blurry, dark, or incomplete.

## Technology direction

- SwiftUI for the iOS interface.
- Meta Wearables Device Access Toolkit for glasses connectivity.
- Apple Vision/OCR and image preprocessing for document capture.
- Gemma for OCR correction, reading order, summaries, and questions.
- AVFoundation and Speech for audio input/output.
- A mock glasses provider for development without physical hardware.

## Requirements

- macOS with Xcode.
- An iPhone running the project’s supported iOS version.
- Meta AI app and Developer Mode for physical glasses testing.
- A Meta developer account and access to the Wearables Device Access Toolkit.

## Getting started

1. Open `meta-vision.xcodeproj` in Xcode.
2. Select an iPhone simulator or connected iPhone.
3. Build and run the `meta-vision` target.
4. Follow [PLAN.md](PLAN.md) for the next implementation milestone.

## Accessibility and privacy goals

Accessibility is a core requirement, not a later enhancement. The app will use VoiceOver-friendly controls, high-contrast UI, adjustable speech speed, short spoken feedback, and explicit uncertainty handling.

Document images should be processed on-device where practical. Temporary images should be deleted automatically, and any backend transfer must be encrypted and clearly disclosed to the user.

## Disclaimer

This project is an assistive technology prototype. It must not be treated as a replacement for professional medical, legal, financial, or safety-critical document interpretation.
