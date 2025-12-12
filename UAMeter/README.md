# UAMeter

UAMeter is an iOS application that automates reading electricity meter values using the iPhone camera and on-device Machine Learning.  
The project started as a simple idea — “what if I could just point my phone at the meter and get the numbers?” — and evolved into a full computer vision + OCR pipeline optimized for real-world conditions.

This README documents **what the app does**, **why it exists**, and **how it works internally**, including the ML and Vision pipeline we built step by step.

---

## 🧠 What is UAMeter?

UAMeter is an iOS app that reads values from **GAMA 100 electricity meters** using the camera.

It automatically detects:

- Total consumption (day + night)
- Night consumption
- Day consumption
- Date (optionally time)

The app works **without cloud services** — everything runs **on-device** using Apple Vision and Core ML.

---

## 🎯 Why this app exists

Electricity meters like **GAMA 100**:

- Cycle screens every few seconds
- Show values briefly
- Are often installed in dark, inconvenient places
- Require manual copying of numbers (easy to make mistakes)

UAMeter solves this by:

- Continuously scanning the meter screen
- Detecting when a relevant screen is visible
- Extracting only the required numeric values
- Showing a checklist UI until all required readings are captured
- Allowing one-tap copy of the final result

---

## 📱 User Experience (High-level)

1. User opens the app
2. Camera preview starts immediately
3. A visual frame highlights the meter screen
4. The app continuously analyzes the video stream
5. As soon as a valid screen is detected:
   - The corresponding value is filled in the list
6. When all required values are captured:
   - The flashlight button is replaced with a **Copy** button
7. User copies all readings at once

---

## 🧩 Architecture Overview

The app is built as a **real-time video processing pipeline**:

Camera → Video Frames → Screen Detection (ML)
→ Region Cropping
→ OCR (Vision)
→ Rule-based Parsing
→ UI State Update

Everything is designed to be:

- Deterministic
- Explainable
- Debuggable
- Offline-first

---

## 🤖 Machine Learning & Vision Pipeline

### 1️⃣ Camera & Video Stream

- Uses `AVCaptureSession`
- Streams frames via `AVCaptureVideoDataOutput`
- Torch (flashlight) support included
- Handles camera switching safely

---

### 2️⃣ Screen Detection (Core ML)

**Goal:** Find the exact meter display area on the image.

- A custom Core ML object detection model (`ScreenBoundaryML`)
- Trained on real photos of GAMA 100 meters
- Output: normalized bounding box of the meter screen

Key points:

- Model expects `.right` image orientation
- Bounding box size is accurate
- Horizontal positioning is reliable
- Vertical positioning requires coordinate correction

This step dramatically reduces noise by **ignoring all text outside the screen**.

---

### 3️⃣ Bounding Box Rendering

- The detected bounding box is drawn as an overlay
- Overlay uses a `CAShapeLayer`
- Bounding box is slightly expanded (+10 px) to avoid cutting digits
- Visual debugging was critical during development

---

### 4️⃣ OCR (Vision Text Recognition)

**Goal:** Read only what’s inside the detected screen.

- Uses `VNRecognizeTextRequest`
- Runs on a **cropped region of interest**
- Languages: `en-US`, `uk-UA`
- Uses `.accurate` recognition level
- No language correction (important for digits)

---

### 5️⃣ Rule-based Screen Classification

Instead of relying purely on ML for semantics, we use **explicit rules** for reliability.

We detect only 3 screen types:

- `15.8.0` → Total (day + night)
- `15.8.1` → Night
- `15.8.2` → Day

Rules:

- Dots may be missing (`1580`, `15.80`, etc.)
- We normalize strings (remove spaces & dots)
- We search for:
  - Screen code
  - A sequence of **8 digits**
- This drastically reduces false positives

This hybrid approach (ML + rules) proved much more reliable than OCR alone.

---

## 🧪 What we tried (and why it didn’t work)

During development we tested many ideas:

### ❌ Rectangle detection via Vision

- Detected random polygons and trapezoids
- Too unstable in real conditions

### ❌ Full-frame OCR

- Too much noise from meter casing text
- Confused labels with readings

### ❌ Pure OCR-based digit recognition

- Frequently confused:
  - `5 ↔ 2`
  - `7 ↔ 1`
  - `6 ↔ 5`
- Especially under poor lighting

### ❌ Create ML image classification

- Not precise enough for spatial tasks

Each failed attempt directly influenced the final architecture.

---

## ✅ What worked best

- **Custom ML model** for screen localization
- **Cropped OCR** instead of full-frame OCR
- **Strict rule-based parsing**
- **Continuous scanning** instead of single-shot capture
- **On-device only** processing

---

## 🧱 Core Components

- `CameraView` — Camera lifecycle & session
- `PreviewView` — Video preview + overlay rendering
- `MeterScreenDetector` — Core ML screen detection
- `MeterDigitsDetector` — OCR pipeline
- `MeterDetector` — Rule-based parsing logic
- `ContentView` — SwiftUI UI & state handling

---

## 🔐 Privacy

- No images are uploaded
- No network calls
- All processing happens locally
- Camera access is used only for meter reading

---

## 🚀 Current Status

- Screen detection works reliably
- OCR works well inside cropped region
- Remaining challenge: digit confusion under extreme lighting
- Next steps: digit-specific ML or post-OCR correction model

---

## 🧭 Future Improvements

- Digit-level ML refinement
- Confidence scoring per reading
- Support for more meter models
- Export formats (CSV / PDF)
- History & validation mode

---

## ✍️ Closing Notes

UAMeter is a practical example of how:

- ML is most effective when combined with deterministic logic
- Vision pipelines benefit from tight scope control
- Real-world CV problems require iterative experimentation

This project started as a small idea and became a deep exploration of **mobile computer vision in the wild**.

---

**Built with Swift, Vision, Core ML, and a lot of debugging.**
