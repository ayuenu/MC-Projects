-- vibecoded landing pad notifier

-- Configuration
local PLAYER_DETECTOR_SIDE = "bottom"
local CHAT_BOX_SIDE = "top"
local DETECTION_RADIUS = 100
local MIN_Y = 150
local COOLDOWN_TIME = 600 -- seconds
local TOAST_MESSAGE = "You are entering our airspace."
local MESSAGE = "Landing pad available below!"
local TITLE = "[Gang Valley Control Tower]"
local PREFIX = "&2&lAutomated"
local BRACKETS = "[]"
local BRACKETS_COLOR = "&f&l"

local TOAST_TABLE = {
    message = TOAST_MESSAGE,
    title = TITLE,
    player = "",
    prefix = PREFIX,
    brackets = BRACKETS,
    bracketsColor = BRACKETS_COLOR
}
local MESSAGE_TABLE = {
    message = MESSAGE,
    player = "",
    prefix = PREFIX,
    brackets = BRACKETS,
    bracketsColor = BRACKETS_COLOR
}

-- Find and connect to the Player Detector
local playerDetector = peripheral.wrap(PLAYER_DETECTOR_SIDE) or peripheral.find("player_detector")
    or error("player_detector peripheral not found!", 0)
local chatBox = peripheral.wrap(CHAT_BOX_SIDE) or peripheral.find("chat_box")
    or error("chat_box peripheral not found!", 0)

-- Tracks notification timestamps: { ["PlayerName"] = os.epoch("utc") }
local notifiedPlayers = {}

print("Scanning for mounted players above Y " .. MIN_Y .. " (Cooldown: " .. COOLDOWN_TIME .. " secs)...")

while true do
    local currentTime = os.epoch("local") / 1000 -- Current timestamp in seconds
    local success, players = pcall(playerDetector.getPlayersInRange, DETECTION_RADIUS)
    
    if success and players then
        for _, player in ipairs(players) do
            local pName = type(player) == "table" and player.name or player
            local pData = playerDetector.getPlayerPos(pName)
            
            if pData and pData.y then
                -- Check if player is above specified Y level
                if pData.y >= MIN_Y then
                    local lastNotified = notifiedPlayers[pName] or 0
                    
                    -- Only notify if the cooldown period has passed since their last notification
                    if (currentTime - lastNotified) >= COOLDOWN_TIME then

                        chatBox.sendToastToPlayer(
                            TOAST_TABLE.message,
                            TOAST_TABLE.title,
                            pName, -- player username
                            TOAST_TABLE.prefix,
                            TOAST_TABLE.brackets,
                            TOAST_TABLE.bracketsColor
                        )
                        sleep(1)
                        chatBox.sendMessageToPlayer(
                            MESSAGE_TABLE.message,
                            pName, -- player username
                            MESSAGE_TABLE.prefix,
                            MESSAGE_TABLE.brackets,
                            MESSAGE_TABLE.bracketsColor
                        )

                        notifiedPlayers[pName] = currentTime
                        print("Notified: " .. pName .. "  at Y:" .. math.floor(pData.y))
                    end
                end
            end
        end
    end

    -- Clean up expired tracking entries after 10 minutes
    for pName, lastNotified in pairs(notifiedPlayers) do
        if (currentTime - lastNotified) >= COOLDOWN_TIME then
            notifiedPlayers[pName] = nil
            print(COOLDOWN_TIME .. "-second cooldown expired for: " .. pName)
        end
    end

    sleep(2)
end