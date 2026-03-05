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

    -- Second fallback: check the local player's attributes or UI if needed (omitted for brevity)
    return 0
end

local automationEnabled = true

print("[Ronix] Full Automation Script Started.")
print("[Ronix] Loaded " .. #sortedAxes .. " purchasable axes.")

task.spawn(function()
    while automationEnabled do
        task.wait(0.1) -- small delay to prevent crashing the client

        local success, err = pcall(function()
            -- 1. Auto-Hit Trees (using the internal ByteNet packet)
            local trees = CollectionService:GetTagged("Tree")
            for _, tree in ipairs(trees) do
                -- Skip growing trees and check if the tree model has a seed
                if tree:GetAttribute("IsGrowing") ~= true then
                    local seed = tree:GetAttribute("Seed")
                    if seed then
                        -- The 'prog' value is usually perfect swing (100)
                        if Packets.axe_hit and Packets.axe_hit.send then
                            Packets.axe_hit.send({
                                ["seed"] = seed,
                                ["prog"] = 100
                            })
                        end
                    end
                end
            end

            -- 2. Auto-Collect All and Sell
            -- Call collect_all (the value is 'nothing', so empty args work)
            if Packets.collect_all and Packets.collect_all.send then
                Packets.collect_all.send()
            end

            -- Call sell (boolean value to sell or not, passing true)
            if Packets.sell and Packets.sell.send then
                Packets.sell.send(true)
            end

            -- 3. Auto-Buy Best Axe
            local currentBalance = getBalance()
            for i = #sortedAxes, 1, -1 do
                local axe = sortedAxes[i]
                -- If we have enough currency to afford the best possible axe
                if currentBalance >= axe.price then
                    -- ToolClassIndex 1 represents axes in market_buy
                    if Packets.market_buy and Packets.market_buy.send then
                        Packets.market_buy.send({
                            ["toolClassIndex"] = 1,
                            ["product"] = axe.id
                        })
                    end
                    -- Break out of the loop since we want to try buying the highest one we can afford
                    -- The game likely handles duplicate purchases or we just keep buying the best one
                    break
                end
            end
        end)

        if not success then
            warn("[Ronix] Automation Error: " .. tostring(err))
        end
    end
end)

-- Return string so executor can see it successfully loaded
return "[Ronix] Automation is running in the background."
