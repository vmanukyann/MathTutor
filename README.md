# MathTutor

## Overview

**MathTutor** is a mobile application leveraging multimodal AI to provide **voice-guided tutoring** for middle school math students.

The goal is to move beyond simple calculators. MathTutor guides the student through the problem-solving process step-by-step using a friendly, encouraging voice, reinforcing core concepts and promoting genuine learning.

### Key Features (MVP Focus)

* **Photo-to-Problem Solver:** Instantly recognize math problems (handwritten or printed) via a smartphone camera.
* **Socratic Voice Guidance:** Delivers explanations that ask probing, helpful questions to ensure the student understands the *method* before seeing the *answer*.
* **Encouraging Tone:** Utilizes an AI persona tailored for middle school students to foster a positive learning experience.

---

## 💻 Tech Stack

| Category | Technology | Purpose |
| :--- | :--- | :--- |
| **Backend & AI Logic** | Python 3.11+ | Core application logic and API orchestration. |
| **Multimodal Vision** | OpenAI GPT-4o-mini API | Image recognition and step-by-step problem-solving. |
| **Voice Cloning (TTS)** | VoxCPM | Text-to-Speech generation for the voice-guided explanations. |
| **Dependencies** | `torch`, `Pillow`, `soundfile`, `dotenv` | Essential utilities for file handling and deep learning operations. |

