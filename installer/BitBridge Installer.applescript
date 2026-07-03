on run
	set appPath to POSIX path of (path to me)
	set resourceDir to appPath & "Contents/Resources/bitbridge/"
	set listScript to resourceDir & "list-candidates.sh"
	set installScript to resourceDir & "install-runtime.sh"
	
	display dialog "BitBridge installs a read-only automount helper for a BitLocker-encrypted external Windows SSD. Your recovery key is stored in the macOS login Keychain." buttons {"Cancel", "Continue"} default button "Continue" cancel button "Cancel" with title "BitBridge"
	
	if (do shell script "uname -m") is not "arm64" then
		display alert "BitBridge" message "This installer is built for Apple Silicon Macs."
		return
	end if
	
	try
		do shell script "test -x /opt/homebrew/bin/anylinuxfs"
	on error
		display alert "BitBridge needs anylinuxfs" message "Install anylinuxfs for Apple Silicon first, then run BitBridge Installer again. Expected path: /opt/homebrew/bin/anylinuxfs"
		return
	end try
	
	set candidatesText to do shell script quoted form of listScript
	if candidatesText is "" then
		display alert "No external Microsoft partition found" message "Plug in the BitLocker SSD and run BitBridge Installer again."
		return
	end if
	
	set candidateList to paragraphs of candidatesText
	set chosenPartition to choose from list candidateList with title "BitBridge" with prompt "Choose the BitLocker partition to automount." OK button name "Use This Partition" cancel button name "Cancel"
	if chosenPartition is false then return
	
	set selectedLine to item 1 of chosenPartition
	set oldDelimiters to AppleScript's text item delimiters
	set AppleScript's text item delimiters to " | "
	set targetUUID to text item 2 of selectedLine
	set AppleScript's text item delimiters to oldDelimiters
	
	set nameDialog to display dialog "Choose the Finder volume name BitBridge should use." default answer "BitBridge-Windows" buttons {"Cancel", "Install"} default button "Install" cancel button "Cancel" with title "BitBridge"
	set mountName to text returned of nameDialog
	
	do shell script "BITBRIDGE_RESOURCE_DIR=" & quoted form of resourceDir & " " & quoted form of installScript & " " & quoted form of targetUUID & " " & quoted form of mountName
	
	display dialog "BitBridge is installed. When the selected SSD is plugged in, it will mount read-only after login." buttons {"Done"} default button "Done" with title "BitBridge"
end run
