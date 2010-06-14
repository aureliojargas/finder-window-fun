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
	
	
	-----------------------------------------------------------------------------
	-- Methods
	
	on _getAvailableScreenSize() -- see issue#4
		
		-- Choose the target screen (see issue#6)
		set _targetScreen to first item of NSScreen's screens() -- screen with dock/menu
		--set targetScreen to NSScreen's mainScreen() -- screen with keyboard focus
		
		-- Get full size and available size
		set _screenRect to _targetScreen's frame() -- with menu/dock
		set _availableScreenRect to _targetScreen's visibleFrame() -- without menu/dock
		set _availableScreenOrigin to _availableScreenRect's origin -- {x:0.0, y:4.0} (bottom/left)
		set _availableScreenSize to _availableScreenRect's |size| -- {width:1280.0, height:998.0}
		
		-- Set available size width/height
		set _width to |width| of _availableScreenSize
		set _height to height of _availableScreenSize
		
		-- Set the starting point: top/left coordinate (see issue#7)
		set _left to x of _availableScreenOrigin
		set _top to (height of |size| of _screenRect) - (height of _availableScreenSize) - (y of _availableScreenOrigin)
		
		return {_top:_top, _left:_left, _width:_width, _height:_height}
		
	end _getAvailableScreenSize
	
	on _getGridBounds(_rows, _cols, _innerMargin)
		
		set _screen to _getAvailableScreenSize()
		
		-- Calculate window size
		set _windowWidth to ((_screen's _width) - (_innerMargin * (_cols - 1))) / _cols
		set _windowHeight to ((_screen's _height) - (_innerMargin * (_rows - 1))) / _rows
		
		-- TopLeft positions to compose the grid
		set _positions to {}
		repeat with _row from 1 to _rows
			repeat with _col from 1 to _cols
				set the end of _positions to {¬
					(_screen's _left) + (_windowWidth + _innerMargin) * (_col - 1), ¬
					(_screen's _top) + (_windowHeight + _innerMargin) * (_row - 1) + titleBarHeight ¬
					} -- see issue#2
			end repeat
		end repeat
		
		-- Finder understands window "bounds" not "size"
		-- bounds = { topLeft_X, topLeft_Y, bottomRight_X, bottomRight_Y }
		-- Note: topLeft_X is BELOW window title bar (see issue#2)
		-- Note: See http://www.macosxhints.com/article.php?story=20100130231939451 for window resize with size not bounds, using System Events
		--
		set _bounds to {}
		repeat with i from 1 to (count _positions)
			set _bottomRight to {¬
				(item 1 of item i of _positions) + _windowWidth, ¬
				(item 2 of item i of _positions) + _windowHeight - titleBarHeight ¬
				} -- see issue#2
			copy (item i of _positions & _bottomRight) to the end of _bounds
		end repeat
		
		return _bounds
	end _getGridBounds
	
	on _snapToEdge(_edge)
		log (_edge)
		set _bounds to {}
		-- Use grid bounds to get window positioning: top/bottom 2x1, left/right 1x2, margin 0
		if _edge is "top" then
			set _bounds to item 1 of _getGridBounds(2, 1, 0)
		else if _edge is "bottom" then
			set _bounds to item 2 of _getGridBounds(2, 1, 0)
		else if _edge is "left" then
			set _bounds to item 1 of _getGridBounds(1, 2, 0)
		else if _edge is "right" then
			set _bounds to item 2 of _getGridBounds(1, 2, 0)
		end if
		_snapToGrid({_bounds}) -- the "grid" is made of just one position
	end _snapToEdge
	
	on _snapToGrid(_bounds)
		tell application "Finder"
			if activateFinder then activate
			
			set _slots to (count _bounds) -- number of grid slots
			set _slot to 1 -- index is 1 not 0
			
			repeat with i from 1 to (count windows)
				tell window i
					
					-- Detect info windows: normal and special
					set _isInfoWindow to (class is information window) or (floating is true)
					
					-- Maybe skip info windows?
					if not (my ignoreInfoWindow and _isInfoWindow) then
						
						-- Move and resize window
						set bounds to (item _slot of _bounds)
						
						-- Set next slot
						set _slot to _slot + 1
						if _slot is greater than _slots then set _slot to 1
					end if
				end tell
			end repeat
		end tell
	end _snapToGrid
	
	on _minimize(_bool)
		tell application "Finder"
			if activateFinder then activate
			set collapsed of every window to _bool
		end tell
	end _minimize
	
	on _zoom(_bool)
		tell application "Finder"
			if activateFinder then activate
			set zoomed of every window to _bool
		end tell
	end _zoom
	
	on _toolbar(_bool)
		tell application "Finder"
			if activateFinder then activate
			set toolbar visible of every window to _bool
		end tell
	end _toolbar
	
	on _sidebar(_bool)
		if _bool then
			_toolbar(true) -- Toolbar must be visible for the sidebar to be shown
			_setSidebarWidth(1) -- expands to minimum size
		else
			_setSidebarWidth(0) -- hides
		end if
	end _sidebar
	
	on _setSidebarWidth(n)
		tell application "Finder" -- never activate to allow "live" resizing
			set sidebar width of every window to n
		end tell
	end _setSidebarWidth
	
	on _setView(_name)
		tell application "Finder"
			if activateFinder then activate
			if _name is "icon" then
				set current view of every window to icon view
			else if _name is "list" then
				set current view of every window to list view
			else if _name is "column" then
				--TODO NOK set current view of (every window whose name is not "") to column view
				set current view of every window to column view -- see issue#1
			else if _name is "flow" then
				set current view of every window to flow view
			end if
		end tell
	end _setView
	
	
	-----------------------------------------------------------------------------
	-- UI action handlers
	
	on snapToGrid_(sender)
		_snapToGrid(_getGridBounds(my rows as integer, my cols as integer, my marginBetweenWindows as integer))
	end snapToGrid_
	
	on maximize_(sender)
		_snapToGrid(_getGridBounds(1, 1, 0)) -- Nice trick: set grid size to 1x1
	end maximize_
	
	on snapToEdge_(sender)
		_snapToEdge(title of sender as text)
	end snapToEdge_
	
	on setView_(sender)
		set i to (sender's selectedSegment()) + 1 -- segment is zero based
		set _name to item i of {"icon", "list", "column", "flow"}
		_setView(_name)
	end setView_
	
	on toggleToolbar_(sender)
		_toolbar((title of sender as text) is "Show")
	end toggleToolbar_
	
	on toggleSidebar_(sender)
		_sidebar((title of sender as text) is "Show")
	end toggleSidebar_
	
	-- slider changed
	on changeSidebarWidth_(sender)
		_setSidebarWidth(sidebarWidth as integer)
	end changeSidebarWidth_
	
	on toggle_(sender)
		set _senderName to (title of sender as text)
		set _onoff to _senderName does not start with "un" -- true/false
		if _senderName contains "minimize" then
			_minimize(_onoff)
		else if _senderName contains "zoom" then
			_zoom(_onoff)
		end if
	end toggle_
	
	
	-----------------------------------------------------------------------------
	-- Event handlers
	
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
	
	-- quit on window close
	on applicationShouldTerminateAfterLastWindowClosed_(sender)
		return true
	end applicationShouldTerminateAfterLastWindowClosed_
	
	on applicationShouldTerminate_(sender)
		-- Insert code here to do any housekeeping before your application quits 
		return current application's NSTerminateNow
	end applicationShouldTerminate_
	
end script
