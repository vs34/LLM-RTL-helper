import os
import sys
import re
import json
import subprocess
import google.generativeai as genai

# === COLOR STYLES ===
class Color:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    GRAY = '\033[90m'

def c(msg, color):
    return f"{color}{msg}{Color.ENDC}"

# === INIT ===
ProjectDir = sys.argv[1]
BackUp = sys.argv[2]
ContextDir = os.path.join(BackUp, "contexts")
os.makedirs(ContextDir, exist_ok=True)

# === GEMINI ===
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
model = genai.GenerativeModel("gemini-1.5-flash")

# === HELP MENU ===
keywords = {
    "generate <module_name>": "Generate Verilog code and context",
    "list contexts": "List all saved chat contexts",
    "select <context_name>": "Chat using a saved context",
    "testbench <file_name>": "Generate a testbench for a Verilog module",
    "test <testbench_file>": "Run testbench and show simulation output",
    "help": "Show available commands",
    "exit": "Exit assistant"
}

def sanitize_name(name):
    return re.sub(r'\W+', '_', name.strip().lower())

def get_unique_filename(base_name, folder):
    filename = f"{base_name}.v"
    full_path = os.path.join(folder, filename)
    counter = 1
    while os.path.exists(full_path):
        filename = f"{base_name}_{counter}.v"
        full_path = os.path.join(folder, filename)
        counter += 1
    return full_path

def handle_generate(cmd):
    tokens = cmd.split(maxsplit=1)
    if len(tokens) != 2:
        print(c("Usage: generate <module_name>", Color.YELLOW))
        return

    raw_name = tokens[1]
    module_name = sanitize_name(raw_name)
    base_file_name = f"gen_{module_name}"
    file_path = get_unique_filename(base_file_name, ProjectDir)

    system_prompt = (
        f"give verilog code for {raw_name}. do not do anything else. "
        "No explanations, no formatting, no markdown."
    )

    response = model.generate_content(system_prompt)
    verilog_code = response.text.strip()

    with open(file_path, "w") as f:
        f.write(verilog_code)

    print(c(f"\nVerilog code saved to: {file_path}", Color.GREEN))
    print(c(f"Context initialized: {base_file_name}", Color.BLUE))

    context_path = os.path.join(ContextDir, base_file_name + ".jsonl")
    with open(context_path, "w") as f:
        f.write(json.dumps({"role": "user", "parts": [{"text": f"generate {raw_name}"}]}) + "\n")
        f.write(json.dumps({"role": "model", "parts": [{"text": verilog_code}]}) + "\n")

def list_contexts():
    print(c("\nSaved Contexts:", Color.CYAN))
    for file in os.listdir(ContextDir):
        if file.endswith(".jsonl"):
            print(" -", file.replace(".jsonl", ""))

def load_context(context_name):
    path = os.path.join(ContextDir, f"{context_name}.jsonl")
    if not os.path.exists(path):
        print(c("Context not found.", Color.RED))
        return

    print(c(f"\nLoaded context: {context_name}\n(type 'exit' to leave chat)\n", Color.BLUE))

    history = []
    with open(path, "r") as f:
        for line in f:
            try:
                entry = json.loads(line.strip())
                if "text" in entry:
                    entry = {"role": entry["role"], "parts": [{"text": entry["text"]}]}
                history.append(entry)
            except:
                continue

    chat = model.start_chat(history=history)

    while True:
        user_input = input("You: ").strip()
        if user_input.lower() in ["exit", "quit"]:
            print(c(f"Exiting context: {context_name}", Color.GRAY))
            break
        try:
            response = chat.send_message(user_input)
            print(c(f"Model {context_name}: ", Color.GREEN) + response.text.strip())
            with open(path, "a") as f:
                f.write(json.dumps({"role": "user", "parts": [{"text": user_input}]}) + "\n")
                f.write(json.dumps({"role": "model", "parts": [{"text": response.text.strip()}]}) + "\n")
        except Exception as e:
            print(c(f"Error: {e}", Color.RED))

def handle_testbench(cmd):
    tokens = cmd.split(maxsplit=1)
    if len(tokens) != 2:
        print(c("Usage: testbench <verilog_file>", Color.YELLOW))
        return

    file_name = tokens[1]
    file_path = os.path.join(ProjectDir, file_name)
    if not os.path.exists(file_path):
        print(c("File not found.", Color.RED))
        return

    with open(file_path, "r") as f:
        verilog_code = f.read()

    prompt = (
        "do what i say. give only code. Give testbench code for the given Verilog code. "
        "The testbench should initialize the top module of the code.\n\n" + verilog_code
    )

    response = model.generate_content(prompt)
    tb_code = response.text.strip()

    tb_file_name = f"test_{os.path.basename(file_name)}"
    tb_path = os.path.join(ProjectDir, tb_file_name)

    with open(tb_path, "w") as f:
        f.write(tb_code)

    print(c(f"\nTestbench saved as: {tb_path}", Color.GREEN))
    print(c("\nPreview:\n", Color.CYAN))
    print(tb_code)

def handle_test(cmd):
    tokens = cmd.split(maxsplit=1)
    if len(tokens) != 2:
        print(c("Usage: test <testbench_file>", Color.YELLOW))
        return

    file_name = tokens[1]
    file_path = os.path.join(ProjectDir, file_name)
    if not os.path.exists(file_path):
        print(c("File not found.", Color.RED))
        return

    script_path = os.path.join(os.path.dirname(__file__), "run_test.sh")
    try:
        result = subprocess.run([script_path, file_path], capture_output=True, text=True)
        print(c("\nTest Output:\n", Color.CYAN))
        print(result.stdout)
        if result.stderr:
            print(c("\nErrors:\n", Color.RED) + result.stderr)
    except Exception as e:
        print(c(f"Failed to run testbench: {e}", Color.RED))

def show_keywords():
    print(c("\nAvailable Commands:", Color.HEADER))
    for key, desc in keywords.items():
        print(f"  {key:30s} - {desc}")

# === MAIN LOOP ===
print(c("\nRTL Assistant [type 'help' for commands]\n", Color.CYAN))

while True:
    try:
        cmd = input(">>> ").strip().lower()

        if cmd == "": continue
        elif cmd == "help" or cmd == "h" or cmd == "?": show_keywords()
        elif cmd.startswith("generate "): handle_generate(cmd)
        elif cmd.startswith("select "): load_context(cmd.split(" ", 1)[1].strip())
        elif cmd == "list contexts" or cmd == "list" or cmd == "ls": list_contexts()
        elif cmd.startswith("testbench "): handle_testbench(cmd)
        elif cmd.startswith("test "): handle_test(cmd)
        elif cmd in ["exit", "quit"]:
            print(c("Exiting assistant.", Color.GRAY))
            break
        else:
            print(c(f"Unknown command: {cmd}. Type 'help' for list.", Color.YELLOW))

    except KeyboardInterrupt:
        print(c("\nGoodbye.", Color.GRAY))
        break
    except Exception as e:
        print(c(f"Error: {e}", Color.RED))

