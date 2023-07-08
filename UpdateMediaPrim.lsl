string chatGPTAvatar = "MyChatGPT";  // The name of your MyChatGPT avatar
key httpRequestID;
key mediaPrimID;  // UUID of the media prim

list parseJson(string jsonString)
{
    list jsonList;
    integer length = llStringLength(jsonString);
    string value = "";
    integer i;

    for (i = 0; i < length; i++)
    {
        string character = llGetSubString(jsonString, i, i);

        if (character == "{" || character == "[" || character == "\"" || character == ",")
        {
            if (value != "")
            {
                jsonList += value;
                value = "";
            }
        }
        else if (character == "}" || character == "]")
        {
            if (value != "")
            {
                jsonList += value;
                value = "";
            }

            jsonList += character;
        }
        else if (character != " " && character != "\n" && character != "\r" && character != "\t")
        {
            value += character;
        }
    }

    return jsonList;
}

default
{
    state_entry()
    {
        llListen(-5000, "", llGetOwner(), "");  // Listen on channel -5000
        mediaPrimID = llGetKey();
        llSetPrimMediaParams(mediaPrimID, [
            PRIM_MEDIA_CURRENT_URL, "http://ec2-34-238-124-82.compute-1.amazonaws.com:5000/",
            PRIM_MEDIA_AUTO_SCALE, TRUE,
            PRIM_MEDIA_AUTO_LOOP, FALSE,
            PRIM_MEDIA_AUTO_PLAY, TRUE
        ]);
    }

    listen(integer channel, string name, key id, string message)
    {
        if (message == "/mychatgpt")
        {
            llInstantMessage(id, "Type your message after '/mychatgpt' to interact with MyChatGPT.");
        }
        else if (llGetSubString(message, 0, 11) == "/mychatgpt ")
        {
            string userMessage = llGetSubString(message, 12, -1);  // Extract the user's message
            string url = "http://ec2-34-238-124-82.compute-1.amazonaws.com/chat";  // Update with the appropriate URL
            string postData = "message=" + llEscapeURL(userMessage) + "&user_id=" + (string)llGetOwner();

            httpRequestID = llHTTPRequest(url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/x-www-form-urlencoded"], postData);
        }
        else
        {
            llInstantMessage(id, "Unknown command. Use '/mychatgpt' to start a MyChatGPT conversation.");
        }
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        if (status == 200)
        {
            string contentType = "";
            integer count = llGetListLength(metadata);
            integer i;
            string headerKey;
            string value;

            for (i = 0; i < count; i += 2)
            {
                headerKey = llList2String(metadata, i);
                value = llList2String(metadata, i + 1);
                if (headerKey == "content-type")
                {
                    contentType = value;
                    break;
                }
            }

            if (contentType == "application/json")
            {
                list jsonList = parseJson(body);
                string aiResponse = llList2String(jsonList, 0);

                llInstantMessage(llGetOwner(), chatGPTAvatar + ": " + aiResponse);
                updateMediaPrim();
            }
        }
    }
    
    updateMediaPrim()
    {
        string url = "http://ec2-34-238-124-82.compute-1.amazonaws.com:5000/check?user_id=" + (string)llGetOwner();
        httpRequestID = llHTTPRequest(url, [HTTP_METHOD, "GET"]);
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        if (status == 200)
        {
            list jsonData = llJson2List(body);
            integer userMessageCount = llList2Integer(jsonData, 0);
            list messages = llList2List(jsonData, 1);
            
            // Construct the HTML content
            string htmlContent = "<html><body>";
            htmlContent += "<h1>Chat History</h1>";
            htmlContent += "<h2>User Message Count: " + (string)userMessageCount + "</h2>";
            htmlContent += "<ul>";
            integer i;
            integer numMessages = llGetListLength(messages);
            for (i = 0; i < numMessages; ++i)
            {
                string message = llList2String(messages, i);
                htmlContent += "<li>" + message + "</li>";
            }
            htmlContent += "</ul>";
            htmlContent += "</body></html>";
            
            // Update the media prim with the HTML content
            llSetPrimMediaParams(mediaPrimID, [
                PRIM_MEDIA_CURRENT_URL, "data:text/html;base64," + llBase64Encode(htmlContent),
                PRIM_MEDIA_AUTO_SCALE, TRUE,
                PRIM_MEDIA_AUTO_LOOP, FALSE,
                PRIM_MEDIA_AUTO_PLAY, TRUE
            ]);
        }
    }
}
