from flask import Flask, request, jsonify
import openai

# Your OpenAI API key
openai.organization = ''
openai.api_key = ''

app = Flask(__name__)

@app.route('/chat', methods=['POST'])
def chat():
    # Get the message from the LSL script
    message = request.json.get('message')
    user_id = request.json.get('user_id')
    npc_id = request.json.get('npc_id')

    # Generate a response using ChatGPT
    response = openai.ChatCompletion.create(
      model="gpt-3.5-turbo", 
      messages=[
            {
              "role": "system",
              "content": "You are a helpful assistant."
            },
            {
              "role": "user",
              "content": message
            }
        ]
    )

    # Get the assistant's reply
    assistant_reply = response['choices'][0]['message']['content']

    # Remove newline characters
    assistant_reply = assistant_reply.replace('\n', ' ')

    # Send the reply back to the LSL script
    return assistant_reply 

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=0)
