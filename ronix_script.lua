--[[
    Ronix Full Automation Script
    Target: The specific tree cutting game
    Features: Auto-Axe, Auto-Collect, Auto-Sell, Auto-Buy Best Axe
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Wait for necessary modules to load in case script executes early
repeat task.wait(0.5) until ReplicatedStorage:FindFirstChild("Lists") and ReplicatedStorage.Lists:FindFirstChild("Packets")

local Packets = require(ReplicatedStorage.Lists.Packets)
local AxesList = require(ReplicatedStorage.Lists.Axes)

-- Collect and sort all axes by price
local sortedAxes = {}
for id, axe in pairs(AxesList) do
    if type(axe) == "table" and axe.price and axe.price > 0 then
        table.insert(sortedAxes, {
            id = id,
            price = axe.price
        })
    end
end

-- Sort from lowest to highest price
table.sort(sortedAxes, function(a, b)
    return a.price < b.price
end)

-- Find the leaderstats to get currency/money
local function getBalance()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        for _, stat in ipairs(leaderstats:GetChildren()) do
            -- Look for currency names
            if stat:IsA("IntValue") or stat:IsA("NumberValue") then
                if stat.Name == "Coins" or stat.Name == "Money" or stat.Name == "Currency" or stat.Name == "Wood" or stat.Name == "Sheckles" then
                    return stat.Value
                end
            end
        end

        -- Fallback: return the first number value found in leaderstats
        for _, stat in ipairs(leaderstats:GetChildren()) do
            if stat:IsA("IntValue") or stat:IsA("NumberValue") then
                return stat.Value
            end
        end
    end

    return 0
end

local automationEnabled = true

print("[Ronix] Full Automation Script Started.")
print("[Ronix] Loaded " .. #sortedAxes .. " purchasable axes.")

local lastCollectTime = 0
local lastBuyAttempt = 0
local hitDelay = 1.0 -- SAFE Rate Limit: 1 hit per second max!

task.spawn(function()
    while automationEnabled do
        -- A safe interval to avoid abnormal packet frequency
        task.wait(hitDelay)

        local success, err = pcall(function()
            -- 1. Auto-Hit Trees (using the internal ByteNet packet)
            -- ONLY HIT ONE TREE PER INTERVAL
            local trees = CollectionService:GetTagged("Tree")

            for _, tree in ipairs(trees) do
                -- Skip growing trees
                if tree:GetAttribute("IsGrowing") ~= true then
                    local seed = tree:GetAttribute("Seed")
                    if seed then
                        if Packets.axe_hit and Packets.axe_hit.send then
                            Packets.axe_hit.send({
                                ["seed"] = seed,
                                ["prog"] = 100
                            })
                            -- Only send 1 packet per interval
                            break
                        end
                    end
                end
            end

            local now = os.clock()

            -- 2. Auto-Collect All and Sell
            -- Don't send this every hit! Only every 10 seconds.
            if now - lastCollectTime >= 10 then
                lastCollectTime = now
                if Packets.collect_all and Packets.collect_all.send then
                    Packets.collect_all.send()
                end

                if Packets.sell and Packets.sell.send then
                    -- wait slightly between packet sends to be extra safe
                    task.wait(0.2)
                    Packets.sell.send(true)
                end
            end

            -- 3. Auto-Buy Best Axe
            -- Check shop every 30 seconds to prevent market_buy packet spam
            if now - lastBuyAttempt >= 30 then
                lastBuyAttempt = now
                local currentBalance = getBalance()
                for i = #sortedAxes, 1, -1 do
                    local axe = sortedAxes[i]
                    if currentBalance >= axe.price then
                        -- ToolClassIndex 1 represents axes
                        if Packets.market_buy and Packets.market_buy.send then
                            Packets.market_buy.send({
                                ["toolClassIndex"] = 1,
                                ["product"] = axe.id
                            })
                        end
                        break
                    end
                end
            end
        end)

        if not success then
            warn("[Ronix] Automation Error: " .. tostring(err))
        end
    end
end)

return "[Ronix] Automation is running in the background with STRICT Rate-Limit protection."
