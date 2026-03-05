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

local lastBuyAttempt = 0
local hitDelay = 0.5 -- How often to hit a tree (delay between hitting a single tree)

task.spawn(function()
    while automationEnabled do
        -- A longer wait interval (0.5 seconds) to avoid abnormal packet frequency errors
        task.wait(0.5)

        local success, err = pcall(function()
            -- 1. Auto-Hit Trees (using the internal ByteNet packet)
            -- To avoid rate limit / kick, we should only hit a few trees per tick or just one tree
            local trees = CollectionService:GetTagged("Tree")
            local hitCount = 0

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

                            hitCount = hitCount + 1
                            -- Hit max 2 trees per loop to avoid rate limit flags
                            if hitCount >= 2 then
                                break
                            end
                        end
                    end
                end
            end

            -- 2. Auto-Collect All and Sell
            -- Don't need to send this constantly. We'll only send sell/collect if we hit a tree.
            if Packets.collect_all and Packets.collect_all.send then
                Packets.collect_all.send()
            end

            if Packets.sell and Packets.sell.send then
                Packets.sell.send(true)
            end

            -- 3. Auto-Buy Best Axe
            -- We only want to check the shop periodically to prevent market_buy packet spam
            if os.clock() - lastBuyAttempt >= 5 then -- Check every 5 seconds
                lastBuyAttempt = os.clock()
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

return "[Ronix] Automation is running in the background with Rate-Limit protection."
