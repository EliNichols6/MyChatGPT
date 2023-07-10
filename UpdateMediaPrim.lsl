// Constants
string FLASK_SERVER_URL = "http://ec2-52-70-243-182.compute-1.amazonaws.com/";  // Replace with your Flask server URL

// Media texture UUID
key MEDIA_TEXTURE = "328a1c20-95a1-4bea-8f40-49043ef242ad";  // Replace with the UUID of your media texture

// Variables
key userUUID;  // User's UUID
string webURL;  // Web URL for displaying chat history

// Event handler for receiving nearby chat messages
default
{
    state_entry()
    {
        llListen(0, "", NULL_KEY, "");  // Listen to all channels and chat from any source
        
        // Get user's UUID
        userUUID = llGetOwner();
        
        // Set the initial web URL
        webURL = FLASK_SERVER_URL + "/check?user_id=" + (string)userUUID;
    }

    listen(integer channel, string name, key id, string message)
    {
        if (message == "/mychatgpt")
        {
            // Request chat history from Flask server
            llHTTPRequest(webURL, [HTTP_METHOD, "GET"], "");
        }
        else if (llGetSubString(message, 0, 9) == "/mychatgpt")
        {
            // Extract the actual message after "/mychatgpt "
            string actualMessage = llGetSubString(message, 11, -1);
            string url = FLASK_SERVER_URL + "/chat";
            string body = "{\"message\": \"" + actualMessage + "\", \"user_id\": \"" + (string)userUUID + "\"}";
            llHTTPRequest(url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json", HTTP_BODY_MAXLENGTH, 8192], body);
        }
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        if (status == 200)
        {
            // Split the chat history string into individual messages
            list split = llParseString2List(body, ["\n"], []);
            list messages = split;

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
                PRIM_MEDIA_CURRENT_URL, webURL,
                PRIM_MEDIA_AUTO_SCALE, TRUE,
                PRIM_MEDIA_AUTO_LOOP, FALSE,
                PRIM_MEDIA_AUTO_PLAY, FALSE,
                PRIM_MEDIA_WIDTH_PIXELS, 512,
                PRIM_MEDIA_HEIGHT_PIXELS, 512,
                PRIM_MEDIA_WHITELIST, ["http://*"]
            ]);

            // Show the chat history in local chat
            llSay(0, "Chat history loaded.");
        }
        else
        {
            llSay(0, "An error occurred while fetching the chat history.");
        }
    }
}
