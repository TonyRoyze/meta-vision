# Meta Vision

Meta Vision is an iOS visual assistant designed to help blind and low-vision users understand scenes and read important text. The current version uses the iPhone camera; Meta Ray-Ban support remains planned.

The planned experience is:

`Capture with iPhone camera → check image → OCR supporting context → Gemma scene description → speak aloud`

## Current status

The first runnable vertical slice uses a one-tap, speed-prioritized iPhone camera capture, checks image quality, and sends the image directly to an imported on-device Gemma vision model through LiteRT-LM. Apple Vision OCR provides optional supporting context for signs and documents, but Gemma describes the complete scene—including relevant people, objects, actions, spatial relationships, obstacles, and visible text—before AVFoundation speaks it aloud. The UI also supports repeat, summarization, stop, adjustable speech speed, on-device description history, and a prototype Meta Ray-Bans connection flow.

The connection UI currently uses a development provider; production Meta Wearables SDK capture, iPhone Action button, Back Tap, Shortcuts/App Intents, richer image-quality guidance, and hands-free voice commands are still planned. All future capture triggers can route through the same quick-capture entry point.

## Planned MVP

- Describe complete scenes from the iPhone camera.
- Include relevant people, objects, actions, positions, obstacles, and visible text.
- Speak the result through the selected audio output.
- Support “describe this,” “repeat,” “summarize,” and “stop.”
- Provide clear feedback when an image is blurry, dark, or incomplete.
- Add follow-up questions about the captured image, then integrate Meta Ray-Ban glasses.

## Technology direction

- SwiftUI for the iOS interface.
- Meta Wearables Device Access Toolkit for glasses connectivity.
- Apple Vision/OCR for optional supporting context from signs, labels, and documents.
- Multimodal Gemma for scene understanding, descriptions, summaries, and future questions.
- AVFoundation and Speech for audio input/output.
- A mock glasses provider for development without physical hardware.

## Requirements

- macOS with Xcode.
- An iPhone running the project’s supported iOS version.
- Meta AI app and Developer Mode for physical glasses testing.
- A Meta developer account and access to the Wearables Device Access Toolkit.
- A compatible Gemma `.litertlm` model from [Google AI Edge](https://developers.google.com/edge/litert-lm/swift), downloaded under its applicable license.

## Getting started

1. Open `meta-vision.xcodeproj` in Xcode.
2. Select an iPhone simulator or connected iPhone.
3. Build and run the `meta-vision` target.
4. In Settings, download Gemma directly from the prefilled Hugging Face URL, paste another direct `.litertlm` link, or import an existing model file. For gated repositories, accept the model license first and use a Hugging Face read token.
5. Tap **Describe this**, capture a scene, and let the on-device pipeline describe and speak it.

## Accessibility and privacy goals

Accessibility is a core requirement, not a later enhancement. The app will use VoiceOver-friendly controls, high-contrast UI, adjustable speech speed, short spoken feedback, and explicit uncertainty handling.

Camera images are processed on-device and are not added to description history. If a backend is added later, any transfer must be encrypted and clearly disclosed to the user.

## Disclaimer

This project is an assistive technology prototype. It must not be treated as a replacement for professional medical, legal, financial, navigation, or other safety-critical guidance.
