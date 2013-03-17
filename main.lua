
io.output():setvbuf('no') 		-- **debug: disable output buffering for Xcode Console

local LinkedInManager = require( "LinkedIn" )
local widget = require( "widget" )


--------------------------------
-- Create Status Message area
--------------------------------
local function createStatusMessage( message, x, y )
	-- Show text, using default bold font of device (Helvetica on iPhone)
	local textObject = display.newText( message, 0, 0, native.systemFontBold, 24 )
	textObject:setTextColor( 255,255,255 )

	-- A trick to get text to be centered
	local group = display.newGroup()
	group.x = x
	group.y = y
	group:insert( textObject, true )

	-- Insert rounded rect behind textObject
	local r = 10
	local roundedRect = display.newRoundedRect( 0, 0, textObject.contentWidth + 2*r, textObject.contentHeight + 2*r, r )
	roundedRect:setFillColor( 55, 55, 55, 190 )
	group:insert( 1, roundedRect, true )

	group.textObject = textObject
	group.roundedRect = roundedRect
	return group
end



local statusMessage = createStatusMessage( "   Not connected  ", 0.5*display.contentWidth, 420 )


local function resizeStatusMessage(str)
	statusMessage.textObject.text = str
	statusMessage.roundedRect.height = statusMessage.textObject.contentHeight + 20
	statusMessage.roundedRect.width = statusMessage.textObject.contentWidth + 20
end


local callback = {}

-- Callbacks
function callback.LinkedInCancel()
	print( "LinkedIn Cancel" )
	resizeStatusMessage("LinkedIn Cancel")
end

-----------------------------------------------------------------
-- Successful LinkedIn Callback
--
-- Determine the request type and update the display
-----------------------------------------------------------------
--
function callback.LinkedInSuccess( response )
	
	print( "LinkedIn Success" )
	--[[for k, v in pairs(response) do
		print(k .."=".. v)
	end--]]

	resizeStatusMessage("Success: Created share")

end

function callback.LinkedInFailed()
	print( "Failed: Invalid Token" )
	resizeStatusMessage("Failed: Invalid Token")
end

--------------------------------
-- PostUpdate the message
--------------------------------
--
local function PostUpdateit( event )
	local time = os.date( "*t" )		-- Get time to append to our tweet
	local msg = "Posted from Corona SDK at www.coronalabs.com at " ..time.hour .. ":"
			.. time.min .. "." .. time.sec
	LinkedInManager.PostUpdate(callback, msg, "anyone", "http://www.coronalabs.com/blog/")
end



--------------------------------
-- Create "PostUpdate" Button
--------------------------------
--
LinkedInButton = widget.newButton
{
	left = 380,
	top = 300,
	width = 280,
	height = 50,
	id = "button1",
	defaultFile = "smallButton.png",
	overFile = "smallButtonOver.png",
	label = "PostUpdate",
	fontSize = 34,
	onRelease = PostUpdateit
}
LinkedInButton.x = display.contentWidth / 2



