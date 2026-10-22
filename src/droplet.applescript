-- WebM to MP4
-- Drop .webm files (or any video) onto this app and an .mp4 appears next to each one.
-- Double-clicking the app instead opens a file picker.
--
-- The real work happens in Contents/Resources/convert.sh using the bundled ffmpeg.

on open theItems
	convertItems(theItems)
end open

on run
	set chosen to choose file with prompt "Choose the video files to convert to MP4:" with multiple selections allowed
	convertItems(chosen)
end run

on convertItems(theItems)
	set appPath to POSIX path of (path to me)
	set converter to quoted form of (appPath & "Contents/Resources/convert.sh")

	set fileArgs to ""
	repeat with anItem in theItems
		set fileArgs to fileArgs & " " & quoted form of (POSIX path of anItem)
	end repeat

	set fileCount to count of theItems
	display notification "Converting " & fileCount & " file" & pluralSuffix(fileCount) & "… this can take a while for long videos." with title "WebM to MP4"

	-- "; true" keeps do shell script from throwing on a non-zero exit; we read the OK/FAIL lines instead.
	with timeout of 86400 seconds
		set output to do shell script "/bin/bash " & converter & fileArgs & " 2>&1; true"
	end timeout

	set okCount to 0
	set failLines to {}
	set firstOutput to ""
	repeat with aLine in paragraphs of output
		set aLine to aLine as text
		if aLine starts with "OK: " then
			set okCount to okCount + 1
			if firstOutput is "" then set firstOutput to text 5 thru -1 of aLine
		else if aLine starts with "FAIL: " then
			set end of failLines to text 7 thru -1 of aLine
		end if
	end repeat

	if (count of failLines) is 0 then
		set msg to "Converted " & okCount & " file" & pluralSuffix(okCount) & ". The MP4" & pluralSuffix(okCount) & " sit next to the original" & pluralSuffix(okCount) & "."
		set answer to display dialog msg with title "WebM to MP4" buttons {"Show in Finder", "OK"} default button "OK" with icon note
		if button returned of answer is "Show in Finder" and firstOutput is not "" then
			tell application "Finder" to reveal (POSIX file firstOutput as alias)
			tell application "Finder" to activate
		end if
	else
		set AppleScript's text item delimiters to return
		set failText to failLines as text
		set AppleScript's text item delimiters to ""
		display dialog "Converted " & okCount & ", failed " & (count of failLines) & ":" & return & return & failText with title "WebM to MP4" buttons {"OK"} default button "OK" with icon stop
	end if
end convertItems

on pluralSuffix(n)
	if n is 1 then return ""
	return "s"
end pluralSuffix
