--
--  FinderWindowFunAppDelegate.applescript
--  FinderWindowFun
--
--  Created by Aurelio Jargas on 09/06/10.
--  License: MIT
--
-- 'Enable access for assistive devices' is not necessary because I'm not using System Events
--
-- Pictures of Aqua Window Controls (bullets) taken from http://developer.apple.com/mac/library/documentation/UserExperience/Conceptual/AppleHIGuidelines/XHIGWindows/XHIGWindows.html
--

property NSScreen : class "NSScreen"

script FinderWindowFunAppDelegate
	property parent : class "NSObject"
	
	-- IB outlets
	property myWindow : missing value
	
	-- bindings
	property rows : 2
	property cols : 2
	property marginBetweenWindows : 0
	property sidebarWidth : 120
	
	-- constants
	property menuBarHeight : 22 -- system's top menu bar
	property titleBarHeight : 22 -- or 16 for Special Info Window (see issue#3)
	
	-- preferences
	property ignoreInfoWindow : true
	property activateFinder : true
	property alwaysOnTop : true
	
	on setView_(sender)
		set viewMode to sender's selectedSegment()
		tell application "Finder"
			if activateFinder then activate
			if viewMode is 0 then
				set current view of every window to icon view
			else if viewMode is 1 then
				set current view of every window to list view
			else if viewMode is 2 then
				--TODO NOK set current view of (every window whose name is not "") to column view
				set current view of every window to column view -- see issue#1
			else if viewMode is 3 then
				set current view of every window to flow view
			end if
		end tell
	end setView_
	
	on set_toolbar_width(n)
		tell application "Finder"
			set sidebar width of every window to n
		end tell
	end set_toolbar_width
	
	-- slider changed
	on changeToolbarWidth_(sender)
		set_toolbar_width(sidebarWidth as integer)
	end changeToolbarWidth_
	
	on toggleSidebar_(sender)
		if (title of sender as text) is "Show" then
			
			-- Toolbar must be visible for the sidebar to be shown
			tell application "Finder" to set toolbar visible of every window to true
			
			set_toolbar_width(1) -- expands to min size
		else
			set_toolbar_width(0) -- hides
		end if
	end toggleSidebar_
	
	on toggleToolbar_(sender)
		tell application "Finder"
			if activateFinder then activate
			if (title of sender as text) is "Show" then
				set toolbar visible of every window to true
			else
				set toolbar visible of every window to false
			end if
		end tell
	end toggleToolbar_
	
	on toggle_(sender)
		set senderName to (title of sender as text)
		set onoff to senderName does not start with "un" -- true/false
		tell application "Finder"
			if activateFinder then activate
			if senderName contains "minimize" then
				set collapsed of every window to onoff
			else if senderName contains "zoom" then
				set zoomed of every window to onoff
				--
				--NOK			else if senderName contains "status" then
				--NOK				set statusbar visible of every window to onoff
			end if
		end tell
	end toggle_
	
	-- Nice trick to maximize: set grid size to 1x1
	on maximizeAll_(sender)
		set oldrows to my rows
		set oldcols to my cols
		set my rows to 1
		set my cols to 1
		resizeWindows_(1)
		set my rows to oldrows
		set my cols to oldcols
	end maximizeAll_
	
	on resizeWindows_(sender)
		
		-- make sure we got integers
		set rows to my rows as integer
		set cols to my cols as integer
		set marginBetweenWindows to my marginBetweenWindows as integer
		
		--
		-- Get dock/menu screen available size (see issue#4)
		--
		
		-- Choose the target screen for the snap (see issue#6)
		set targetScreen to first item of NSScreen's screens() -- screen with dock/menu
		--set targetScreen to NSScreen's mainScreen() -- screen with keyboard focus
		
		-- Get full size and available size
		set screenRect to targetScreen's frame() -- with menu/dock
		set availableScreenRect to targetScreen's visibleFrame() -- without menu/dock
		set availableScreenOrigin to availableScreenRect's origin -- {x:0.0, y:4.0} (bottom/left)
		set availableScreenSize to availableScreenRect's |size| -- {width:1280.0, height:998.0}
		
		-- Set available size width/height
		set screenWidth to |width| of availableScreenSize
		set screenHeight to height of availableScreenSize
		
		-- Set the starting point: top/left coordinate (see issue#7)
		set screenTopLeft to {x:x of availableScreenOrigin, y:(height of |size| of screenRect) - (height of availableScreenSize) - (y of availableScreenOrigin)}
		
		-- Calculate window size
		set windowWidth to (screenWidth - (marginBetweenWindows * (cols - 1))) / cols
		set windowHeight to (screenHeight - (marginBetweenWindows * (rows - 1))) / rows
		
		-- TopLeft positions to compose the grid
		set thePositions to {}
		repeat with row from 1 to rows
			repeat with col from 1 to cols
				set the end of thePositions to {¬
					(x of screenTopLeft) + (windowWidth + marginBetweenWindows) * (col - 1), ¬
					(y of screenTopLeft) + (windowHeight + marginBetweenWindows) * (row - 1) + titleBarHeight ¬
					} -- see issue#2
			end repeat
		end repeat
		
		-- Finder understands window "bounds" not "size"
		-- bounds = { topLeft_X, topLeft_Y, bottomRight_X, bottomRight_Y }
		-- Note: topLeft_X is BELOW window title bar (see issue#2)
		-- Note: See http://www.macosxhints.com/article.php?story=20100130231939451 for window resize with size not bounds, using System Events
		--
		set theBounds to {}
		repeat with i from 1 to (count thePositions)
			set bottomRight to {¬
				(item 1 of item i of thePositions) + windowWidth, ¬
				(item 2 of item i of thePositions) + windowHeight - titleBarHeight ¬
				} -- see issue#2
			copy (item i of thePositions & bottomRight) to the end of theBounds
		end repeat
		
		-- Snap windows to grid
		tell application "Finder"
			if activateFinder then activate
			set _slots to (count thePositions) -- number of grid slots
			set _slot to 1 -- index is 1 not 0
			
			repeat with i from 1 to (count windows)
				tell window i
					
					-- Detect info windows: normal and special
					set _isInfoWindow to (class is information window) or (floating is true)
					
					-- Maybe skip info windows?
					if not (my ignoreInfoWindow and _isInfoWindow) then
						
						-- Move and resize window
						set bounds to (item _slot of theBounds)
						
						-- Set next slot
						set _slot to _slot + 1
						if _slot is greater than _slots then set _slot to 1
						
					end if
				end tell
			end repeat
		end tell
	end resizeWindows_
	
	-- quit on window close
	on applicationShouldTerminateAfterLastWindowClosed_(sender)
		return true
	end applicationShouldTerminateAfterLastWindowClosed_
	
	on applicationWillFinishLaunching_(aNotification)
		-- Insert code here to initialize your application before any files are opened
		
		-- Make sure we're always on top of: normal, info and special info windows
		-- But below App switch and Finder menus
		if alwaysOnTop then
			myWindow's setLevel_(current application's NSModalPanelWindowLevel)
		end if
		
		if activateFinder then
			tell application "Finder" to activate
			tell me to activate
		end if
	end applicationWillFinishLaunching_
	
	on applicationShouldTerminate_(sender)
		-- Insert code here to do any housekeeping before your application quits 
		return current application's NSTerminateNow
	end applicationShouldTerminate_
	
end script
