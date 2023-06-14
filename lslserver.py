from flask import Flask, request, jsonify
from dotenv import load_dotenv
import pickle
import openai
import os
from langchain.chat_models import ChatOpenAI
from langchain.schema import (
    SystemMessage,
    HumanMessage,
    AIMessage
)

app = Flask(__name__)

DATA_FILE = 'data.pkl'

def save_data(data):
    with open(DATA_FILE, 'wb') as f:
        pickle.dump(data, f)

def load_data():
    try:
        with open(DATA_FILE, 'rb') as f:
            return pickle.load(f)
    except FileNotFoundError:
        return {}


load_dotenv()  # loads api key from '.env' file
chat = ChatOpenAI(temperature=0)

# Initialize a dictionary to hold the messages for each user
user_messages = load_data()

@app.route('/chat', methods=['POST'])
def handle_chat():
    global user_messages
    # Get the message and user_id from the request
    user_input = request.json.get('message')
    user_id = request.json.get('user_id')

    # If this is a new user, initialize their message list
    if user_id not in user_messages:
        user_messages[user_id] = [SystemMessage(content="You are MyChatGPT, a helpful assistant dedicated to student's learning.")]

    messages = user_messages[user_id]

    if user_input == "clear":
        messages.clear()
        messages.append(SystemMessage(content="You are MyChatGPT, a helpful assistant dedicated to student's learning."))
        user_messages[user_id] = messages
        save_data(user_messages)
        return jsonify({"response": "Chat history cleared!"})

    # Append the user message to the messages
    messages.append(HumanMessage(content=user_input))

    # Generate a response using ChatGPT
    ai_response = chat(messages)  

    # Append the AI message to the messages
    messages.append(AIMessage(content=ai_response.content))
    
    # Explicitly update the message list in the dictionary
    user_messages[user_id] = messages
    save_data(user_messages)

    # Get the assistant's reply
    assistant_reply = ai_response.content

    # Remove newline characters
    assistant_reply = assistant_reply.replace('\n', ' ')

    # Count the number of user messages
    user_message_count = sum(isinstance(msg, HumanMessage) for msg in messages)


    print(user_messages[user_id])

    # Send the reply back to the requester
    return jsonify({"response": assistant_reply, "user_message_count": user_message_count})
   
@app.route('/check', methods=['GET'])
def check_user():
    # Get the user_id from the request
    user_id = request.args.get('user_id')

    # If the user_id does not exist, return an error message
    if user_id not in user_messages:
        return jsonify({"error": f"No data found for user_id: {user_id}"})

    # Get the user's messages
    messages = user_messages[user_id]

    # Count the number of user messages
    user_message_count = sum(isinstance(msg, HumanMessage) for msg in messages)

    # Create a list to hold the message contents
    message_contents = [msg.content for msg in messages]

    # Return the user's message count and all messages
    return jsonify({
        "user_message_count": user_message_count,
        "messages": message_contents
    })


if __name__ == "__main__":
    print(user_messages)
    app.run(host='0.0.0.0', port=0)
