local modem = peripheral.find("modem") or error("modem not found!")
local player_detector = peripheral.find("player_detector") or error("player_detector not found!")
local hud_modem = peripheral.find("hud_glasses") or error("hud_glasses not found!") -- todo: add hud goggles interaction
local monitor = peripheral.find("monitor") or error("monitor not found!")
local redstoneBridge = peripheral.find("redstone_link_bridge") or error("redstone_link_bridge not found!")
local fuelTank = peripheral.find("createpropulsion:platinum_fluid_tank_block_entity") or error ("fluid_tank not found!")

modem.open(458)

-- Constants

local ENGINE_COUNT = 4 -- 4 engines -> 4 mB/t fuel usage

-- Local vars

local burnerThrottle = 0
local rotorThrottle = 0
local thrustLockToggle = false
local engineToggle = false
local fuelMax = 32000.0
local fuelFraction = 0.0

local eventFilter = {
    ["chat"] = true,
    ["monitor_touch"] = true,
    ["modem_message"] = true,
    ["hud_glasses_message"] = true,
    ["player_detector"] = true
}

print("Program is running...")
print("Listening on [458]")
print("Transmitting on [459]")
print("")
print("Hold Ctrl + T to exit program.")

term.redirect(monitor)
monitor.setTextScale(0.5)
monitor.clear()

local function airshipShutdown()
    redstoneBridge.sendLinkSignal(
        "minecraft:stone_slab",
        "minecraft:white_wool",
        15
    )
    redstoneBridge.sendLinkSignal(
        "minecraft:cobblestone_slab",
        "minecraft:white_wool",
        15
    )
    -- wait until engines are off
    sleep(5)
    -- disable signal
    redstoneBridge.sendLinkSignal(
        "minecraft:stone_slab",
        "minecraft:white_wool",
        0
    )
    redstoneBridge.sendLinkSignal(
        "minecraft:cobblestone_slab",
        "minecraft:white_wool",
        0
    )
end

local function monitorUpdate()
    while true do
        burnerThrottle = redstoneBridge.getLinkSignal(
            "minecraft:stone_stairs",
            "minecraft:white_wool"
        ) or 0
        rotorThrottle = redstoneBridge.getLinkSignal(
            "minecraft:cobblestone_stairs",
            "minecraft:white_wool"
        ) or 0
        engineToggle = redstoneBridge.getLinkSignal(
            "minecraft:red_wool",
            "minecraft:red_wool"
        ) == 0 or false

        fuelFraction = fuelTank.tanks()[1].amount / fuelMax
        local fuelColor =
            fuelFraction >= 0.5 and colors.green or
            fuelFraction > 0.15 and colors.yellow or
            fuelFraction > 0.05 and colors.orange or
            colors.red
        local fuelChars =
            fuelFraction > 0.0 and math.max(1, math.floor(fuelFraction * 10)) or 0
            or 0
        local fuelRemainingTime = 
            fuelTank.tanks()[1].amount / (ENGINE_COUNT*1.0) -- 4 engines - 4 mB per tick
        local fuelRemainingSec = math.floor(fuelRemainingTime % 60)
        local fuelRemainingMin = math.floor(fuelRemainingTime / 60)

        monitor.setCursorPos(1, 1)
        monitor.clear()
        monitor.setBackgroundColor(colors.black)
        monitor.setTextColor(colors.green)
        monitor.write("Airship Control")

        monitor.setTextColor(colors.white)
        monitor.setCursorPos(2, 3)
        local thrustColor = thrustLockToggle and colors.green or colors.red
        monitor.setBackgroundColor(thrustColor)
        monitor.write(" Thrust Lock ")
        monitor.setBackgroundColor(colors.black)

        monitor.setCursorPos(2, 5)
        local engineColor = engineToggle and colors.green or colors.red
        monitor.setBackgroundColor(engineColor)
        monitor.setTextColor(colors.white)
        monitor.write("Engine Toggle")
        monitor.setBackgroundColor(colors.black)


        monitor.setCursorPos(2, 7)
        monitor.setTextColor(colors.blue)
        monitor.write("Burner:")
        monitor.setCursorPos(2, 8)
        monitor.setTextColor(colors.white)
        monitor.write(string.format("%-2d/15", burnerThrottle))

        monitor.setCursorPos(2, 9)
        monitor.setTextColor(colors.blue)
        monitor.write("Rotor:")
        monitor.setCursorPos(2, 10)
        monitor.setTextColor(colors.white)
        monitor.write(string.format("%-2d/15", rotorThrottle))

        monitor.setCursorPos(2, 12)
        monitor.setTextColor(colors.blue)
        monitor.write("Fuel:")
        monitor.setCursorPos(2, 13)
        monitor.setTextColor(colors.white)
        monitor.write(string.format("%-5.1f%%", fuelFraction * 100))
        monitor.setCursorPos(2, 14)
        monitor.write("[")
        monitor.setBackgroundColor(fuelColor)
        monitor.write(string.rep(" ", fuelChars))
        monitor.setBackgroundColor(colors.white)
        monitor.write(string.rep(" ", 10 - fuelChars))
        monitor.setBackgroundColor(colors.black)
        monitor.write("]")

        monitor.setTextColor(colors.blue)
        monitor.setCursorPos(2, 16)
        monitor.write("Est. Remaining time:")
        monitor.setCursorPos(2, 17)
        monitor.setTextColor(colors.white)
        monitor.write(string.format("%02d min %02d sec", fuelRemainingMin, fuelRemainingSec))

        sleep(0.2)
    end
end

local function handleEvents()
    while true do
        local eventData = {os.pullEvent()} -- halts execution
        local eventType = eventData[1]

        if (eventFilter[eventType] == nil) then
            goto continue
        end

        if eventType == "modem_message"
            and eventData[3] == 458 then

            local message = eventData[5]

            if message == "airshipShutdown"
                and #player_detector.getPlayersInRange(10) == 0 then
                
                parallel.waitForAny(airshipShutdown)
            
            elseif (message == "reportStatus") then
                local currentPose = sublevel.getLogicalPose()
                local currentPosition = currentPose.position
                
                modem.transmit(459, 458, {
                    burnerThrottle = burnerThrottle,
                    rotorThrottle = rotorThrottle,
                    thrustLockToggle = thrustLockToggle,
                    fuelFraction = fuelFraction,
                    position = currentPosition
                })

            end

        elseif eventType == "monitor_touch" then
            -- local x = eventData[3]
            -- local y = eventData[4]
            thrustLockToggle = not thrustLockToggle

            redstoneBridge.sendLinkSignal(
                "minecraft:stone",
                "minecraft:red_wool",
                thrustLockToggle and 15 or 0
            )
        end

        ::continue::
    end
end

parallel.waitForAny(handleEvents, monitorUpdate)