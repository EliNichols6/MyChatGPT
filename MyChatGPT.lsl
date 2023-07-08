string url = "http://localhost:5000/chat";  // Replace with the appropriate URL
string userId = "1";  // Set your user ID here

default
{
    state_entry()
    {
        llListen(0, "", NULL_KEY, "");
    }

    listen(integer channel, string name, key id, string message)
    {
        if (llGetSubString(message, 0, 9) == "/mychatgpt")
        {
            // Extract the actual message after "/mychatgpt "
            string actualMessage = llGetSubString(message, 11, -1);
            string body = "{\"message\": \"" + actualMessage + "\", \"user_id\": \"" + userId + "\"}";
            llHTTPRequest(url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json", HTTP_BODY_MAXLENGTH, 8192], body);
        }
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
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
