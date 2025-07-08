import os
import google.generativeai as genai

# Step 1: Configure the Gemini API with your key
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

# Step 2: Create the model instance
model = genai.GenerativeModel("gemini-1.5-flash")

# Step 3: Start a chat session (context-aware!)
chat = model.start_chat(history=[])

# Step 4: Start the conversation loop
while True:
    user_input = input("You: ")
    if user_input.lower() in ["exit", "quit", "bye"]:
        print("🌙 Ending chat. Sweet dreams.")
        break

    response = chat.send_message(user_input)
    print("Gemini:", response.text)

