if [ -f ~/Library/LaunchAgents/com.fred.mba.launchd.plist ]
then
  launchctl unload ~/Library/LaunchAgents/com.fred.mba.launchd.plist
fi
cp com.fred.mba.launchd.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.fred.mba.launchd.plist