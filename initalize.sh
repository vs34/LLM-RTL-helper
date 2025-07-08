#!/bin/bash

# === 📍 Get current dir as ProjectDir ===
ProjectDir="$(pwd)"

# === 🗂️ Create assistant/ folder if not exists ===
mkdir -p "$ProjectDir/assistant"

# === 💾 Set path as BackUp ===
BackUp="$ProjectDir/assistant"

# === 🧠 Call the Python script with both paths ===
python3 ~/assitent/assistant.py "$ProjectDir" "$BackUp"

