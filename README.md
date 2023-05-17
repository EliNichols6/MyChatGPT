# MyChatGPT

MyChatGPT is a repository that contains a Second Life LSL script and a Python server to integrate ChatGPT into the Second Life virtual world.

## Files

### MyChatGPT.lsl

This LSL script listens for chat commands starting with `/chatgpt` and sends the message following the command to the Python server for processing.

### lslserver.py

This Python server uses Flask to receive HTTP requests from the LSL script and utilizes OpenAI's ChatGPT API to generate responses.

## Setup

1. Install required Python packages:
<br>```pip install Flask openai```
2. Set up an OpenAI account and obtain your API key.
3. Replace the placeholders in `lslserver.py` with your OpenAI API key and organization ID.
5. Run the Python server:
<br>```python lslserver.py```
6. Replace the URL in `MyChatGPT.lsl` with your Python server's URL.
7. Upload the `MyChatGPT.lsl` script to Second Life and attach it to an object.
8. Start a conversation with the ChatGPT-powered NPC by typing `/chatgpt` followed by your message in the local chat.

## Usage

In Second Life, type a message in the local chat near the object with the LSL script starting with `/chatgpt`, followed by your question or statement. The ChatGPT-powered NPC will respond accordingly.
