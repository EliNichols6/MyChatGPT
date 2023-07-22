from flask import Flask, request, jsonify, render_template
from langchain.chat_models import ChatOpenAI
from langchain.schema import (
    SystemMessage,
    HumanMessage,
    AIMessage
)
import os
import sqlite3
import pickle
from dotenv import load_dotenv

app = Flask(__name__)

DATA_FILE = 'data.pkl'
DB_FILE = 'conversations.db'

def save_data(user_messages, user_data):
    data = {
        'user_messages': user_messages,
        'user_data': user_data,
    }
    with open(DATA_FILE, 'wb') as f:
        pickle.dump(data, f)

def load_data():
    try:
        with open(DATA_FILE, 'rb') as f:
            data = pickle.load(f)
            return data.get('user_messages', {}), data.get('user_data', {})
    except FileNotFoundError:
        return {}, {}

def setup_db():
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute('''
        CREATE TABLE IF NOT EXISTS conversations (
            id INTEGER PRIMARY KEY,
            user_id TEXT,
            convo_id INTEGER,
            step_id INTEGER,
            system_message TEXT,
            user_message TEXT,
            ai_response TEXT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    conn.commit()
    conn.close()

setup_db()

load_dotenv()  # loads environment variables from '.env' file

# Get the OpenAI API key from the environment variable
openai_api_key = os.getenv('OPENAI_API_KEY')

# Initialize the ChatOpenAI object with the API key
chat = ChatOpenAI(api_key=openai_api_key, temperature=0)

# Initialize dictionaries to hold the messages for each user and the corresponding data
user_messages, user_data = load_data()

@app.route('/', methods=['GET'])
def index():
    return render_template('index.html', messages=user_messages.get('0', []))

@app.route('/chat', methods=['POST'])
def handle_chat():
    global user_messages, user_data
    # Get the message and user_id from the request
    user_input = request.json.get('message')
    user_id = request.json.get('user_id')

    # Initialize data for a new user
    if user_id not in user_messages:
        user_messages[user_id] = [SystemMessage(content="You are MyChatGPT, a helpful assistant dedicated to student's learning.")]
        user_data[user_id] = {
            0: {  # This is the initial conversation
                'system_message': user_messages[user_id][0],
                'steps': {}
            },
        }

    current_convo = max(user_data[user_id].keys())  # Gets the latest conversation ID
    current_step = max(user_data[user_id][current_convo]['steps'].keys()) if user_data[user_id][current_convo]['steps'] else 0  # Gets the latest step ID

    if user_input == "clear":
        # Reset convo_id, step_id, and messages
        user_messages[user_id] = [SystemMessage(content="You are MyChatGPT, a helpful assistant dedicated to student's learning.")]
        user_data[user_id][current_convo+1] = {
            'system_message': user_messages[user_id][0],
            'steps': {}
        }
        save_data(user_messages, user_data)
        return jsonify({"response": "Chat history cleared!"})

    # Create a new step with the user message
    user_messages[user_id].append(HumanMessage(content=user_input))
    user_data[user_id][current_convo]['steps'][current_step+1] = {
        'user_message': user_messages[user_id][-1],
        'ai_message': ""
    }

    # Generate a response using ChatGPT
    ai_response = chat(user_messages[user_id])
    user_messages[user_id].append(AIMessage(content=ai_response.content))

    # Update the AI message for the current step
    user_data[user_id][current_convo]['steps'][current_step+1]['ai_message'] = user_messages[user_id][-1]

    save_data(user_messages, user_data)  # Update pickle data file after every interaction

    # Save to SQLite database
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute('''
        INSERT INTO conversations (
            user_id,
            convo_id,
            step_id,
            system_message,
            user_message,
            ai_response
        ) VALUES (?, ?, ?, ?, ?, ?)
    ''', (user_id, current_convo, current_step+1, user_data[user_id][current_convo]['system_message'].content, user_input, ai_response.content))
    conn.commit()
    conn.close()

    # Remove newline characters
    ai_response = ai_response.content.replace('\n', ' ')

    # Send the reply back to the requester
    return jsonify({"response": ai_response})

@app.route('/check', methods=['GET'])
def check_user():
    # Get the user_id from the URL parameters
    user_id = request.args.get('user_id')

    # If the user_id does not exist, return an error message
    if user_id not in user_messages:
        return jsonify({"error": f"No data found for user_id: {user_id}"})

    # Get the user's messages
    messages = user_messages[user_id]

    # Format the chat history into an HTML representation
    formatted_history = ''
    for msg in messages:
        if isinstance(msg, HumanMessage):
            formatted_history += f'<div class="message user">{msg.content}</div>'
        elif isinstance(msg, AIMessage):
            formatted_history += f'<div class="message assistant">{msg.content}</div>'

    return render_template('chat_history.html', formatted_history=formatted_history)

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000)

