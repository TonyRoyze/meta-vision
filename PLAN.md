# Meta Vision Assistant Plan

Meta Vision is an iOS assistant for blind and low-vision users. It connects to Meta Ray-Ban glasses, captures documents, uses OCR and Gemma for understanding, and reads the result aloud through the glasses.

## MVP goal

Say or press **Read this** → capture an image from the glasses → extract and verify the text → speak it through the glasses.

## Roadmap

### 1. Define the MVP

- Support standard Ray-Ban Meta glasses first.
- Use the iPhone for processing and connectivity.
- Start with English documents.
- Support: “read this,” “repeat,” “summarize,” and “stop.”

### 2. Build the iOS foundation

- Replace the default SwiftUI template.
- Create a high-contrast, VoiceOver-friendly interface.
- Add camera, microphone, Bluetooth, and speech permissions.
- Separate services for glasses, image capture, OCR, Gemma, and text-to-speech.

### 3. Integrate the glasses

- Add Meta’s Wearables Device Access Toolkit.
- Configure the Meta developer application.
- Implement connect/disconnect and image capture.
- Add a mock glasses provider for development without hardware.

### 4. Implement document reading

- Capture a document image.
- Detect boundaries and correct perspective.
- Improve contrast and sharpness.
- Run OCR and identify headings, paragraphs, tables, and lists.
- Split long documents into readable sections.

### 5. Integrate Gemma

Use Gemma to correct OCR errors, determine reading order, identify uncertain text, summarize pages, answer questions, and detect poor-quality images.

OCR and Gemma should be combined rather than relying on Gemma alone. The app must announce uncertainty instead of presenting guesses as facts.

### 6. Add hands-free interaction

- Add speech recognition for commands.
- Add spoken confirmations and retry guidance.
- Support pause, resume, repeat, and skip section.
- Add adjustable speech speed.

### 7. Privacy, safety, and reliability

- Speak or display confidence levels.
- Explain how to improve blurry, dark, or incomplete captures.
- Prefer on-device processing where practical.
- Encrypt images sent to a backend.
- Delete temporary document images automatically.
- Add an emergency stop command.

### 8. Test and release

Test books, receipts, medicine labels, menus, forms, handwritten notes, low-light images, angled documents, and multiple languages.

Measure OCR accuracy, latency, battery usage, connection reliability, speech clarity, and false-confidence rate. Then create a TestFlight build and test with blind or low-vision users.

## Definition of done for the first milestone

- The app connects to the glasses or a mock device.
- The user can capture a document.
- Text is extracted and spoken aloud.
- The user can repeat or stop the reading.
- Failures provide clear spoken guidance.
