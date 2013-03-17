
module(..., package.seeall)

local oAuth = require "oAuth"
local json = require("json")

local api_key = ""			-- key string goes here
local secret_key = ""		-- secret string goes here
local LinkedIn_request_token_secret = nil

-- The web URL address below can be anything
-- LinkedIn sends the webaddress with the token back to your app and the code strips out the token to use to authorise it
local webURL = "http://www.google.com"

--LinkedIn "rw_nus" permission is needed in order to post network updates (i.e. to post a new share on user's stream)
--For a list of all permissions, go to https://developer.linkedin.com/documents/authentication#granting
local scope = "rw_nus"


-- Note: Once logged on, the access_token and access_token_secret should be saved so they can
--	    be used for the next session without the user having to log in again.
-- The following is returned after a successful authenications and log-in by the user
local access_token
local access_token_secret


-- Local variables used in the PostUpdate function
local postMessage, postVisibility, postLinkURL, postImageURL, postTitle
local delegate

-- Forward references
local doPostUpdate			-- function to send the actual PostUpdate


-- Display a message if there is no app keys set (App keys must be strings)
if not api_key or not secret_key then
	-- Handle the response from showAlert dialog boxbox
	local function onComplete( event )
		if event.index == 1 then
			system.openURL( "http://developer.linkedin.com/" )
		end
	end

	native.showAlert( "Error", "To develop for LinkedIn, you need to get an API key and application secret. This is available from LinkedIn's website.",
		{ "Learn More", "Cancel" }, onComplete )
end

-----------------------------------------------------------------------------------------
-- LinkedIn Authorization Listener (callback from step 2)
-- webPopup listener
-----------------------------------------------------------------------------------------
local function webListener(event)

	print("listener: ", event.url)
	local remain_open = true
	local url = event.url

	-- The URL that we are looking for contains "oauth_token" and our own URL
	-- It also has the "oauth_token_secret" and "oauth_verifier" strings
	if url:find("oauth_token") and url:find(webURL) then
	
		----------------------------------------------------
		-- Callback from getAccessToken
		----------------------------------------------------
		local function accessToken_ret( status, access_response )
					

			access_response = responseToTable( access_response, {"=", "&"} )
			access_token = access_response.oauth_token
			access_token_secret = access_response.oauth_token_secret
			
			if not access_token then
				return
			end
		
			print( "Posting Update" )
			print("FOO")
			doPostUpdate(postMessage, postVisibility, postLinkURL, postTitle, postImageURL)		-- send the actual PostUpdate

		end -- end of callback listener
		
		----------------------------------------------------
		-- Executes when Web Popup listener starts
		----------------------------------------------------
		url = url:sub(url:find("?") + 1, url:len())

		-- Get Request Token and Verifier
		local authorize_response = responseToTable(url, {"=", "&"})
		remain_open = false
		
		-- Step 3 Converting Request Token to Access Token		
		oAuth.getAccessToken(authorize_response.oauth_token,
			authorize_response.oauth_verifier, LinkedIn_request_token_secret, api_key, 
			 secret_key, "https://api.linkedin.com/uas/oauth/accessToken", accessToken_ret )



		
	elseif url:find(webURL) then
	
		-- Logon was canceled by user
		--
		remain_open = false
		delegate.LinkedInCancel()
		
	end

	return remain_open
end

-----------------------------------------------------------------------------------------
-- RESPONSE TO TABLE
--
-- Strips the token from the web address returned
-----------------------------------------------------------------------------------------
function responseToTable(str, delimeters)

	local obj = {}

	while str:find(delimeters[1]) ~= nil do
		if #delimeters > 1 then
			local key_index = 1
			local val_index = str:find(delimeters[1])
			local key = str:sub(key_index, val_index - 1)
	
			str = str:sub((val_index + delimeters[1]:len()))
	
			local end_index
			local value
	
			if str:find(delimeters[2]) == nil then
				end_index = str:len()
				value = str
			else
				end_index = str:find(delimeters[2])
				value = str:sub(1, (end_index - 1))
				str = str:sub((end_index + delimeters[2]:len()), str:len())
			end
			obj[key] = value
			--print(key .. ":" .. value)		-- **debug
		else
	
			local val_index = str:find(delimeters[1])
			str = str:sub((val_index + delimeters[1]:len()))
	
			local end_index
			local value
	
			if str:find(delimeters[1]) == nil then
				end_index = str:len()
				value = str
			else
				end_index = str:find(delimeters[1])
				value = str:sub(1, (end_index - 1))
				str = str:sub(end_index, str:len())
			end
			
			obj[#obj + 1] = value

		end
	end
	
	return obj
end


-----------------------------------------------------------------------------------------
-- PostUpdate
--
-- Sends the PostUpdate or request. Authorizes if no access token
-----------------------------------------------------------------------------------------
function PostUpdate(del, msg, vis, linkURL, title, imageURL)

	delegate = del

	postMessage = msg
	postVisibility = vis
	postTitle = title
	postLinkURL = linkURL
	postImageURL = imageURL

	
	
	-- Check to see if we are authorized to PostUpdate
	if not access_token then
		
		----------------------------------------------------
		-- Callback from getRequestToken
		----------------------------------------------------
		function PostUpdateAuth_ret( status, result )
		        
			local LinkedIn_request_token = result:match('oauth_token=([^&]+)')
			LinkedIn_request_token_secret = result:match('oauth_token_secret=([^&]+)')
					
			if not LinkedIn_request_token then
				print( ">> No valid token received!")	-- **debug
				
				-- No valid token received. Abort
				delegate.LinkedInFailed()
				return
			end
		
			-- Request the authorization (step 2)
			-- Displays a webpopup to access the LinkedIn site so user can sign in
			native.showWebPopup(0, 0, display.contentWidth, display.contentHeight, "https://www.linkedin.com/uas/oauth/authenticate?oauth_token="
				.. LinkedIn_request_token, {urlRequest = webListener})


		end --  end of PostUpdateAuth_ret callback

		----------------------------------------------------
		-- Executes first to authorize account
		----------------------------------------------------
		
		if not api_key or not secret_key then
			-- Exit if no API keys set (avoids crashing app)
			delegate.LinkedInFailed()
			return
		end
	
		-- Get temporary token (step 1)		
		-- Call the routine and wait for a response callback (PostUpdate_ret)
		local LinkedIn_request = (oAuth.getRequestToken(api_key, webURL,
			"https://api.linkedin.com/uas/oauth/requestToken", secret_key, scope, PostUpdateAuth_ret))


				
	else
		----------------------------------------------------
		-- Account is already authorized, just PostUpdate
		----------------------------------------------------

		print( "Posting Update" )

		doPostUpdate(postMessage, postVisibility, postLinkURL, postTitle, postImageURL)
		
	end
end

-----------------------------------------------------------------------------------------
-- printTable (**debug)
--
-- This function is useful for display json information returned from LinkedIn api.
-----------------------------------------------------------------------------------------
--
local function printTable( t, label, level )
	if label then print( label ) end
	level = level or 1

	if t then
		for k,v in pairs( t ) do
			local prefix = ""
			for i=1,level do
				prefix = prefix .. "\t"
			end

			print( prefix .. "[" .. tostring(k) .. "] = " .. tostring(v) )
			if type( v ) == "table" then
				print( prefix .. "{" )
				printTable( v, nil, level + 1 )
				print( prefix .. "}" )
			end
		end
	end
end

-----------------------------------------------------------------------------------------
-- PostUpdate
--
-- Sends actual PostUpdate or request to LinkedIn
-----------------------------------------------------------------------------------------

function doPostUpdate(str, vis, linkURL, title, imageURL)

	
	----------------------------------------------------
	-- Callback from makeRequest
	----------------------------------------------------
	function doMessageCallback( status, result )
		
		local response = json.decode( result )
		delegate.LinkedInSuccess( response )

	end

	
	--postMessage, message to send
	local share_object = {
							visibility = {code = "anyone"}, 
							comment = str,
						}

	if vis then
		share_object.visibility.code = vis
	end

	if linkURL or title or imageURL then
		share_object.content = {}

		if linkURL then
			share_object.content.submitted_url = linkURL
		end
		if title then
			share_object.content.title = title
		end	
		if imageURL then
			share_object.content.submitted_image_url = imageURL
		end
	end	
					

	share_object = json.encode(share_object)



	oAuth.makeRequest("http://api.linkedin.com/v1/people/~/shares", share_object, 
		api_key, access_token, secret_key, access_token_secret, 
		"POST", doMessageCallback)--]]
			
		
end
