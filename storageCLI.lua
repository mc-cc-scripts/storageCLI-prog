local storageCLI = {}
local scm = require("./scm")
local Config = scm:load("config")
local hFun = scm:load("helperFunctions")
local args = {...}

local defaultConfig = {
    ["protocol"] = {
        ["description"] = "Protocol used for rednet.",
        ["default"] = "storageManager#00",
        ["type"] = "string"
    },
    ["serverName"] = {
        ["description"] = "Name of the server used in rednet communication.",
        ["default"] = "storageManager",
        ["type"] = "string"
    },
    ["timeout"] = {
        ["description"] = "How many seconds to wait for a response",
        ["default"] = 5,
        ["type"] = "number"
    },
}

storageCLI.aliases = {
    ["x"] = "extract",
    ["p"] = "put",
    ["d"] = "dump",
    ["f"] = "find",
    ["n"] = "network",
    ["s"] = "select",
    ["?"] = "help",
}

storageCLI.helpCommands = {
    ["extract"] = "`x <item> <amount>`\nExtract an item with a specific amount from the storage chest into the output chest.",
    ["put"] = "`p <item> <amount>`\nPuts an item with a specific amount from the input chest into the storage.",
    ["dump"] = "`d`\nDumps all items of the input chest into the storage.",
    ["find"] = "`f <item> [<chest: input|output|storage (default)>]`\nSearches for substring. Chest is optional.",
    ["network"] = "`n`\nLists all network devices (connected peripherals)",
    ["select"] = "`s <chest: input|output|storage> <peripheral>`\nSelects a given peripheral as input, output or storage chest.",
    ["help"] = "`?\nShows this list of commands.`",
}

function storageCLI:init()
    Config:init(defaultConfig)

    if args[1] == "config" then
        Config:command(args)
    else
        self.protocol = Config:get('protocol')
        self.serverName = Config:get('serverName')
        self.timeout = Config:get('timeout')
        self.inputChest = nil
        self.outputChest = nil
        self.storageChest = nil
        
        peripheral.find("modem", rednet.open)
        if rednet.isOpen() then
            self.host = rednet.lookup(self.protocol, self.serverName)
            self:prompt()
            
            if not self.host then
                print("Could not connect to host: " .. self.serverName .. " with protocol: " .. self.protocol)
            else
                print("Connected to " .. self.serverName .. " with protocol: " .. self.protocol)
                self:detectChests()
            end

            self:run()
            rednet.unhost(self.protocol)
        else
            print("No open modem found.")
        end
    end
end

function storageCLI:prompt()
    print("Storage CLI")
end

function storageCLI:detectChests()
    local peripherals = self:listPeripherals()

    local controller
    local controller_count = 0
    local transfer_chest
    local chest_count = 0
    for i=1, #peripherals do
        if string.find(peripherals[i], "controller") then
            controller = peripherals[i]
            controller_count = controller_count + 1
        elseif string.find(peripherals[i], "chest") then
            transfer_chest = peripherals[i]
            chest_count = chest_count + 1
        end
    end

    if controller_count == 1 then
        self.storageChest = controller
        print("Found 1 controller and selected it as storage chest.")
    else
        print("Could not auto-detect storage chest.")
    end

    if chest_count == 1 then
        self.inputChest = transfer_chest
        self.outputChest = transfer_chest
        print("Found 1 chest and set it as in- and output chest.")
    else
        print("Could not auto-detect in- and output chest.")
    end
end

function storageCLI:listPeripherals()
    local message = {
        ["command"] = "peripherals"
    }

    rednet.send(self.host, message, self.protocol)

    local msg
    _, msg, _ = rednet.receive(self.protocol, self.timeout)

    local peripherals = msg['peripherals']
    return peripherals
end

---@param name string
---@return boolean, string | nil
function storageCLI:chestType(name)
    local types = {
        ["storage"] = self.storageChest,
        ["input"] = self.inputChest,
        ["output"] = self.outputChest
    }

    if not types[name] then
        return false, "´" .. name .. "` is not a valid chest type."
    end

    return true, types[name] or nil
end

---@param sourceName string | nil
---@return table | nil
function storageCLI:listItems(sourceName)
    local found, source
    if not sourceName then
        source = self.storageChest
        found = true
    else
        found, source = self:chestType(sourceName)
    end
    if found then
        if not source then
            print(sourceName .. " chest not set.")
        else
            local message = {
                ["command"] = "list",
                ["peripheral"] = source
            }

            rednet.send(self.host, message, self.protocol)

            local _, msg, _ = rednet.receive(self.protocol, self.timeout)
            return msg["items"]
        end
    else
        -- source should contain an error message
        print(source)
    end

    return nil
end

---@param name string
---@return number | nil, number | nil
function storageCLI:findItem(name, chestType)
    local items = self:listItems(chestType)
    if not items then return nil end

    for item, slots in pairs(items) do
        local _, itemName = item:match("([^:]+):([^:]+)")
        if name == itemName then
            local highestAmountSlot = -1
            local highestAmount = -1

            for slot, amount in pairs(slots) do
                if amount > highestAmount then
                    highestAmountSlot = slot
                    highestAmount = amount
                end
            end

            return highestAmountSlot, highestAmount
        end
    end

    return nil
end

-- extract item from storage chest to output chest
function storageCLI:cmdExtract(itemName, amount)
    local fromSlot, maxAmount = self:findItem(itemName)
    if not fromSlot then
        print("Item not found: " .. itemName)
        return
    end

    if maxAmount < amount then
        amount = maxAmount
    end

    local message = {
        ["command"] = "extract",
        ["from"] = self.storageChest,
        ["to"] = self.outputChest,
        ["fromSlot"] = fromSlot,
        ["count"] = amount,
        ["toSlot"] = nil
    }

    rednet.send(self.host, message, self.protocol)

    local _, resMessage = rednet.receive(self.protocol, self.timeout)
    if resMessage["success"] then
        print("Extracted " .. amount .. "x " .. itemName)
    end
end

-- put item from input chest to storage chest
function storageCLI:cmdPut(itemName, amount)
    local fromSlot, maxAmount = self:findItem(itemName, "input")
    if maxAmount < amount then
        amount = maxAmount
    end

    local message = {
        ["command"] = "put",
        ["from"] = self.inputChest,
        ["to"] = self.storageChest,
        ["fromSlot"] = tonumber(fromSlot),
        ["count"] = amount,
        ["toSlot"] = nil
    }

    rednet.send(self.host, message, self.protocol)

    local _, resMessage = rednet.receive(self.protocol, self.timeout)
    if resMessage["success"] then
        print("Put " .. amount .. "x " .. itemName .. " into the storage chest")
    end
end

-- select chest types
function storageCLI:cmdSelect(chestType, peripheral)
    local foundPeripheral = nil
    local peripherals = self:listPeripherals()

    for i=1, #peripherals do
        if string.find(peripherals[i], peripheral) then
            foundPeripheral = peripherals[i]
        end
    end

    if not foundPeripheral then
        print("Could not find peripheral: " .. peripheral)
        return
    end

    if chestType == "storage" then
        self.storageChest = peripheral
    elseif chestType == "input" then
        self.inputChest = peripheral
    elseif chestType == "output" then
        self.outputChest = peripheral
    else
        print("Wrong chest type: " .. chestType)
    end
end

-- find items either in storage chest or in given chest type
function storageCLI:cmdFind(itemName, chestType)
    local chest = chestType or "storage"
    local items = self:listItems(chest)

    if not items then
        print("0 results for " .. itemName)
        return
    end

    local found = false
    for item, slots in pairs(items) do
        local _, name = item:match("([^:]+):([^:]+)")
        if string.find(name, itemName) then
            found = true
            print(hFun.tablelength(slots) .. " result(s) for " .. name)
            for slot, amount in pairs(slots) do
                print("  " .. amount .. "  x in slot " .. slot)
            end
        end
    end

    if not found then
        print("0 results for " .. itemName)
    end
end

-- list network devices (peripherals)
function storageCLI:cmdNetwork()
    local peripherals = self:listPeripherals()

    for i=1, #peripherals do
        print(peripherals[i])
    end
end

function storageCLI:cmdDump()
    local items = self:listItems("input")
    local pack = {}
    
    if not items then
        print("Could not find any items in input chest.")
        return
    end

    for _, slots in pairs(items) do
        for slot, amount in pairs(slots) do
            table.insert(pack, {
                ["command"] = "put",
                ["from"] = self.inputChest,
                ["to"] = self.storageChest,
                ["fromSlot"] = tonumber(slot),
                ["count"] = amount,
                ["toSlot"] = nil,
            })
        end
    end

    local message = {
        ["command"] = "pack",
        ["pack"] = pack
    }

    rednet.send(self.host, message, self.protocol)

    local _, resMessage = rednet.receive(self.protocol, self.timeout)
    if resMessage and resMessage["success"] then
        print("Dumped all items into storage.")
    else
        print("Something went wrong. Too bad.")
    end
end

function storageCLI:cmdHelp()
    print("Commands:")
    for command, help in pairs(self.helpCommands) do
        print(command)
        print(help)
    end
end

function storageCLI:run()
    local command
    while true do
        local input = read()
        local inputTable = {}
        for word in string.gmatch(input, "%S+") do
            table.insert(inputTable, word)
        end
        command = inputTable[1]
        local arg1 = inputTable[2] or nil
        local arg2 = inputTable[3] or nil

        if command == "extract" or self.aliases[command] == "extract" then
            local amount = arg2 and tonumber(arg2) or 1
            self:cmdExtract(arg1, amount)
        elseif command == "put" or self.aliases[command] == "put" then
            local amount = arg2 and tonumber(arg2) or 1
            self:cmdPut(arg1, amount)
        elseif command == "dump" or self.aliases[command] == "dump" then
            self:cmdDump()
        elseif command == "select" or self.aliases[command] == "select" then
            self:cmdSelect(arg1, arg2)
        elseif command == "find" or self.aliases[command] == "find" then
            self:cmdFind(arg1, arg2)
        elseif command == "network" or self.aliases[command] == "network" then
            self:cmdNetwork()
        elseif command == "help" or self.aliases[command] == "help" then
            self:cmdHelp()
        else
            print("Invalid command.")
        end
    end
end

storageCLI:init()
