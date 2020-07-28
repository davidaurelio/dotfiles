on run argv
	set theTheme to "Solarized " & item 1 of argv
	tell application "iTerm"
		repeat with theWindow in windows
			repeat with theTab in tabs in windows
				set color preset in current session in theTab to theTheme
			end repeat
		end repeat
	end tell
end run
