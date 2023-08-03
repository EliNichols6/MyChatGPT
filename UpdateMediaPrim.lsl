// Constants
string FLASK_SERVER_URL = "http://ec2-3-94-90-79.compute-1.amazonaws.com";  // Replace with your Flask server URL (without trailing slash)

integer currentPage = 0; // This will keep track of the current page

// Media texture UUID
key MEDIA_TEXTURE = "2f87dc27-caea-4577-9b36-1d8b06ae3652";  // Replace with the UUID of your media texture
integer listenHandle;

// Variables
key userUUID;  // User's UUID
string webURL;  // Web URL for displaying chat history

// Event handler for receiving nearby chat messages
default
{
    state_entry()
    {
        llListen(0, "", NULL_KEY, "");  // Listen to all channels and chat from any source

    }

    listen(integer channel, string name, key id, string message)
    {
        // Get user's UUID
        userUUID = id;
        // Set the initial web URL
        webURL = FLASK_SERVER_URL + "/check?user_id=" + (string)userUUID;
        if (message == "/mychatgpt")
        {
            // Request chat history from Flask server
            llHTTPRequest(webURL, [HTTP_METHOD, "GET"], "");
        }
        else if (llGetSubString(message, 0, 8) == "/register")
        {
            // Extract the user's display name after "/register "
            string displayName = llGetSubString(message, 10, -1);

            // Register the user's UUID and display name with the Flask server
            string url = FLASK_SERVER_URL + "/register";
            string body = "{\"user_id\": \"" + (string)userUUID + "\", \"display_name\": \"" + displayName + "\"}";
            llHTTPRequest(url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json", HTTP_BODY_MAXLENGTH, 8192], body);
        }
        else if (llGetSubString(message, 0, 9) == "/mychatgpt")
        {
            // Extract the actual message after "/mychatgpt "
            string actualMessage = llGetSubString(message, 11, -1);
            string url = FLASK_SERVER_URL + "/chat";
            string body = "{\"message\": \"" + actualMessage + "\", \"user_id\": \"" + (string)userUUID + "\"}";
            llHTTPRequest(url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json", HTTP_BODY_MAXLENGTH, 8192], body);
            list data = llParseString2List(body, ["|"], []);
            string response = llList2String(data, 0);
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
            llSay(0, "Chat history loaded.");
            llSay(0, webURL);
            return;
        }

        // Split the chat history string into individual messages
        list split = llParseString2List(body, ["|"], []);
        string response = llList2String(split, 0);
        integer page = (integer)llList2String(split, 1);
        integer totalPages = (integer)llList2String(split, 2);
        list messages = llParseString2List(body, ["\n"], []);
        llSay(0, response); // Output the chatbot response in the chat
        if (page < totalPages) // If there are more pages
            {
            currentPage++;
            string pageUrl = FLASK_SERVER_URL + "/chat/page/" + (string)currentPage;
            string requestBody = "{\"user_id\": \"" + userUUID + "\"}";
            llHTTPRequest(pageUrl, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json", HTTP_BODY_MAXLENGTH, 8192], requestBody);
            }
        // Generate HTML content for the chat history
        string htmlContent = "<html><body><h1>Chat History</h1>";

        // Loop through each message and append it to the HTML content
        integer numMessages = llGetListLength(messages);
        integer i;
        for (i = 0; i < numMessages; ++i)
        {
            string message = llList2String(messages, i);
            htmlContent += "<p>" + message + "</p>";
        }

        htmlContent += "</body></html>";

        // Update the texture on the script's prim
        llSetTexture(MEDIA_TEXTURE, ALL_SIDES);

        // Display the chat history in the media prim
        llSetPrimMediaParams(LINK_THIS, [
            PRIM_MEDIA_CURRENT_URL, "text/html", webURL,
            PRIM_MEDIA_AUTO_SCALE, TRUE,
            PRIM_MEDIA_AUTO_LOOP, FALSE,
            PRIM_MEDIA_AUTO_PLAY, FALSE,
            PRIM_MEDIA_WIDTH_PIXELS, 512,
            PRIM_MEDIA_HEIGHT_PIXELS, 512,
            PRIM_MEDIA_WHITELIST, ["http://*"]
        ]);

        // This part is triggered if the HTTP request fails for any reason (e.g., the server is down, the URL is invalid, etc.)
        if (status >= 400)
        {
            llOwnerSay("HTTP request failed: " + (string)status + ", " + body); // Output an error message to the owner
        }

        // Show the chat history in local chat
        if (body == "{\"response\": \"Chat history cleared!\"}") {
        llSay(0, "Chat history cleared!");
        }
        if (page == totalPages) // Last page response
            {
            llSay(0, "Chat history loaded.");
            llSay(0, webURL);
            }
    }
}
