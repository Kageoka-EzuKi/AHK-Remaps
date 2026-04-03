⌨️ AHK v2 Key Remapper (Macro Tool)

A simple and flexible AutoHotkey v2 script that allows you to remap keys into powerful macros — from typing phrases to executing multi-step actions with delays.

Created by Kageoka-EzuKi

✨ Features
🔤 Replace single keys with custom text
Example: Press A → types "Hello World"
⚡ Trigger hotkeys with text output
Example: Ctrl + T → types "Lorem Ipsum"
🔁 Multi-step macros with delays
Example: Press J →
Ctrl + C
wait 0.5 seconds
Ctrl + V
🧩 Fully customizable remaps
📄 Simple configuration (easy to edit and expand)
🚀 Use Cases
Automate repetitive typing
Create shortcuts for common phrases
Speed up workflow in work or gaming
Clipboard automation
Custom keyboard behavior
🛠️ Requirements
AutoHotkey v2
 (IMPORTANT: This script uses v2 syntax)
📦 Installation
Install AutoHotkey v2

Download or clone this repository:

git clone https://github.com/your-username/your-repo-name.git
Run the .ahk script
⚙️ Example Remaps
; Simple text replacement
a::Send("Hello World")

; Hotkey with text output
^t::Send("Lorem Ipsum")

; Multi-step macro with delay
j::
{
    Send("^c")
    Sleep(500)
    Send("^v")
}
🧠 How It Works

This script listens for key presses and replaces them with:

Text output
Key combinations
Multi-step actions

You can easily extend it by adding your own remaps inside the script.

📌 Notes
Make sure you're using AutoHotkey v2, not v1
Some remaps may interfere with normal typing (adjust as needed)
Run as administrator if certain keys don’t work in specific apps
🤝 Contributing

This project is open to the public.

Suggestions are welcome
Feel free to fork, modify, and improve
Share your own macro ideas!
👤 Author

Kageoka-EzuKi
Creator of this AHK v2 Remapper

📜 License

Free to use for personal and public projects.
