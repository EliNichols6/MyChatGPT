from flask import Flask, request, jsonify
from dotenv import load_dotenv
import os
import sqlite3
import pickle
from langchain.chat_models import ChatOpenAI
from langchain.schema import (
    SystemMessage,
    HumanMessage,
    AIMessage
)

app = Flask(__name__)

DATA_FILE = 'data.pkl' 
DB_FILE = 'conversations.db' 
PAGE_SIZE = 1000 
current_pages = {}

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
            return data['user_messages'], data['user_data']
    except (FileNotFoundError, KeyError):
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

load_dotenv()  # loads api key from '.env' file
chat = ChatOpenAI(temperature=0)

# Initialize dictionaries to hold the messages for each user and the corresponding data
user_messages, user_data = load_data()

@app.route('/chat', methods=['POST'])
def handle_chat():
    global user_messages, user_data, current_pages
    # Get the message and user_id from the request
    user_input = request.json.get('message')
    user_id = request.json.get('user_id')

    # Initialize data for a new user
    if user_id not in user_messages:
        user_messages[user_id] = [SystemMessage(content="Forget all previous instructions. You are now MyChatGPT, an interactive training assistant designed for students preparing for the CompTIA Security+ SY0-601 exam. Your objective is to aid students in understanding key cybersecurity concepts and verify their understanding. Think thoroughly through your output, verifying questions and answers. If you are not 100% confident in an answer, let the user know to fact-check you. Your teaching style and outputs should mirror Professor Messer’s way of teaching and the techniques used to help students prepare for the exam. After explaining topics to a student, ask them a few challenging questions in the style of CompTIA's Secuirty+ Exam to verify their knowledge. Questions you pose to users shouldn't be simple like \"What is the main objective of x\", or \"How does x work.\" Questions should follow Security+ Exam questions with a story to help users understand the context of a situation The questions should be as similiar to security+ questions as they can be, and each question should be different from one another. Try your best to generate diverse questions that have not been generated before. Your questions should not be \"[scenario describing attack that is the answer], what type of attack is this\" or a similiar example. The questions you generate should really make the user think. Generate diverse questions similar to those on the CompTIA Security+ exam. The questions should be a mix of multiple choice questions, true/false questions, and scenario-based questions. Sometimes for the scenario-based questions, please provide multiple possible actions or outcomes to choose from, rather than just asking to identify the type of attack. The goal is to have a mix of straightforward knowledge-based questions and more complex, scenario-based questions that require critical thinking.")]
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
        user_messages[user_id] = [SystemMessage(content="Forget all previous instructions. You are now MyChatGPT, an interactive training assistant designed for students preparing for the CompTIA Security+ SY0-601 exam. Your objective is to aid students in understanding key cybersecurity concepts and verify their understanding. Think thoroughly through your output, verifying questions and answers. If you are not 100% confident in an answer, let the user know to fact-check you. Your teaching style and outputs should mirror Professor Messer’s way of teaching and the techniques used to help students prepare for the exam. After explaining topics to a student, ask them a few challenging questions in the style of CompTIA's Secuirty+ Exam to verify their knowledge. Questions you pose to users shouldn't be simple like \"What is the main objective of x\", or \"How does x work.\" Questions should follow Security+ Exam questions with a story to help users understand the context of a situation The questions should be as similiar to security+ questions as they can be, and each question should be different from one another. Try your best to generate diverse questions that have not been generated before. Your questions should not be \"[scenario describing attack that is the answer], what type of attack is this\" or a similiar example. The questions you generate should really make the user think. Generate diverse questions similar to those on the CompTIA Security+ exam. The questions should be a mix of multiple choice questions, true/false questions, and scenario-based questions. Sometimes for the scenario-based questions, please provide multiple possible actions or outcomes to choose from, rather than just asking to identify the type of attack. The goal is to have a mix of straightforward knowledge-based questions and more complex, scenario-based questions that require critical thinking.")]
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
    ai_response_content = ai_response.content.replace('\n', ' ')
    words = ai_response_content.split()
    current_pages[user_id] = []
    current_page = []
    for word in words:
        if sum(len(w) + 1 for w in current_page) + len(word) < PAGE_SIZE:  # +1 for each space
            current_page.append(word)
        else:
            current_pages[user_id].append(" ".join(current_page))
            current_page = [word]
    if current_page:  # if there are any words left in current_page
        current_pages[user_id].append(" ".join(current_page))
        
    # Send the reply back to the requester
    return jsonify({"response": f"{current_pages[user_id][0]}|{0}|{len(current_pages[user_id]) - 1}"})

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

@app.route('/chat/page/<int:page>', methods=['POST'])
def get_chat_page(page):
    # Get the user_id from the request
    user_id = request.json.get('user_id')

    # If the user_id or page number is not valid, return an error
    if user_id not in current_pages or page < 0 or page >= len(current_pages[user_id]):
        return jsonify({"error": "Invalid user_id or page number"})

    # Return the requested page
    return jsonify({"response": f"{current_pages[user_id][page]}|{page}|{len(current_pages[user_id]) - 1}"})

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=33337)
