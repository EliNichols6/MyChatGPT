string url = "http://ec2-18-205-23-17.compute-1.amazonaws.com:5000/chat"; // Replace with your Python server URL
string userId; // Set your user ID here
integer currentPage = 0; // This will keep track of the current page

default
{
    state_entry()
    {
        llListen(0, "", NULL_KEY, "");
    }

    listen(integer channel, string name, key id, string message)
    {
        userId = id;
        if (llGetSubString(message, 0, 9) == "/mychatgpt")
        {
            currentPage = 0; // Reset the current page to 0
            // Extract the actual message after "/chatgpt "
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

        // Parse the delimited data
        list data = llParseString2List(body, ["|"], []);
        string response = llList2String(data, 0);
        integer page = (integer)llList2String(data, 1);
        integer totalPages = (integer)llList2String(data, 2);

        llSay(0, response); // Output the chatbot response in the chat

        if (page < totalPages) // If there are more pages
        {
            currentPage++;
            string pageUrl = url + "/page/" + (string)currentPage;
            string requestBody = "{\"user_id\": \"" + userId + "\"}";
            llHTTPRequest(pageUrl, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json", HTTP_BODY_MAXLENGTH, 8192], requestBody);
        }

        // This part is triggered if the HTTP request fails for any reason (e.g., the server is down, the URL is invalid, etc.)
        if (status >= 400)
        {
            llOwnerSay("HTTP request failed: " + (string)status + ", " + body); // Output an error message to the owner
        }
    }
}
