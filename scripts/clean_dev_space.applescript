-- clean_dev_space.applescript
-- Frees up disk space consumed by Xcode, Flutter, and iOS Simulator caches.
-- Run via: osascript scripts/clean_dev_space.applescript

on run
	set freedItems to {}
	set errorItems to {}

	-- ── 1. Remove unavailable simulators ────────────────────────────────────
	try
		do shell script "xcrun simctl delete unavailable"
		set end of freedItems to "✓ Removed unavailable simulators"
	on error errMsg
		set end of errorItems to "✗ Simulators: " & errMsg
	end try

	-- ── 2. Clear Xcode IB Support cache (~3–4 GB) ───────────────────────────
	try
		do shell script "rm -rf ~/Library/Developer/Xcode/UserData/IB\\ Support"
		set end of freedItems to "✓ Cleared Xcode IB Support cache"
	on error errMsg
		set end of errorItems to "✗ IB Support: " & errMsg
	end try

	-- ── 3. Flutter clean (removes build/ and .dart_tool/) ───────────────────
	try
		-- Resolve the script's directory so flutter clean targets the right project
		set scriptPath to POSIX path of (path to me)
		set projectRoot to do shell script "dirname " & quoted form of scriptPath & " | xargs dirname"
		do shell script "cd " & quoted form of projectRoot & " && flutter clean"
		set end of freedItems to "✓ Flutter clean completed"
	on error errMsg
		set end of errorItems to "✗ Flutter clean: " & errMsg
	end try

	-- ── 4. Remove stale Flutter tool temp files ──────────────────────────────
	try
		do shell script "rm -rf /var/folders/*/*/T/flutter_tools*"
		set end of freedItems to "✓ Cleared Flutter tool temp files"
	on error errMsg
		-- Not a hard failure — files may already be gone
		set end of freedItems to "✓ Flutter temp files already clean"
	end try

	-- ── 5. Clear Flutter engine cache ───────────────────────────────────────
	try
		do shell script "rm -rf ~/Library/Caches/flutter_tools"
		set end of freedItems to "✓ Cleared Flutter engine cache"
	on error errMsg
		set end of errorItems to "✗ Flutter cache: " & errMsg
	end try

	-- ── 6. Report current free space ────────────────────────────────────────
	set freeSpace to do shell script "df -h / | awk 'NR==2 {print $4}'"

	-- ── Build summary ────────────────────────────────────────────────────────
	set summary to "🧹 Dev Space Cleanup Complete" & return & return

	if (count of freedItems) > 0 then
		set summary to summary & "Completed:" & return
		repeat with msg in freedItems
			set summary to summary & "  " & msg & return
		end repeat
	end if

	if (count of errorItems) > 0 then
		set summary to summary & return & "Warnings:" & return
		repeat with msg in errorItems
			set summary to summary & "  " & msg & return
		end repeat
	end if

	set summary to summary & return & "💾 Free space now: " & freeSpace

	display dialog summary buttons {"OK"} default button "OK" with title "Dev Space Cleanup" with icon note

end run
