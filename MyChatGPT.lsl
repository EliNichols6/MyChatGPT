string url = "http://ec2-18-222-177-176.us-east-2.compute.amazonaws.com:5000/chat"; // Replace with your Python server URL

default
{
    state_entry()
    {
        llListen(0, "", NULL_KEY, "");
        llOwnerSay("Script started and listening...");
    }

    listen(integer channel, string name, key id, string message)
    {
        if (llGetSubString(message, 0, 7) == "/chatgpt")
        {
            llOwnerSay("Received chat command: " + message);
            // Extract the actual message after "/chatgpt "
            string actualMessage = llGetSubString(message, 9, -1);
            string body = "{\"message\": \"" + actualMessage + "\", \"user_id\": \"" + (string)id + "\", \"npc_id\": \"" + (string)llGetKey() + "\"}";

            llOwnerSay("Sending HTTP request: " + body);
            llHTTPRequest(url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json", HTTP_BODY_MAXLENGTH, 4096], body);
        }
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        llOwnerSay("Received HTTP response: " + (string)status + ", " + body);
        if (status != 200) // If the HTTP response status is not 200 (OK)
        {
            llOwnerSay("Error: " + (string)status); // Output the error status to the owner
            return;
        }

        if (body == "") // If the response body is empty
        {
            llOwnerSay("Error: Empty response"); // Output an error message to the owner
            return;
        }

        llSay(0, body); // Output the chatbot response in the chat

        // This part is triggered if the HTTP request fails for any reason (e.g., the server is down, the URL is invalid, etc.)
        if (status >= 400)
        {
            llOwnerSay("HTTP request failed: " + (string)status + ", " + body); // Output an error message to the owner
        }
    }
}
