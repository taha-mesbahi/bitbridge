#!/bin/sh
osascript -e 'display dialog "Administrator password needed by BitBridge to mount or unmount the BitLocker volume." default answer "" with hidden answer buttons {"OK"} default button "OK"' -e 'text returned of result'
