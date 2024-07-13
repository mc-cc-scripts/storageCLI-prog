local storageCLI = {}
local scm = require("./scm")
local Config = scm:load("config")
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
}

storageCLI.commands = {
    ["extract"] = function (itemName, amount)
        
    end,
    ["put"] = function (itemName, amount)
        
    end,
    ["select"] = function (type, peripheral)
        
    end
}

storageCLI.aliases = {
    ["x"] = "extract",
    ["p"] = "put",
    ["f"] = "search",
    ["l"] = "list",
    ["i"] = "items",
    ["s"] = "select",
}

function storageCLI:init()
    Config:init(defaultConfig)

    if args[1] == "config" then
        Config:command(args)
    else
        self.protocol = Config:get('protocol')
        self.serverName = Config:get('serverName')
        self.inputChest = nil
        self.outputChest = nil
        self.storageChest = nil
        
        peripheral.find("modem", rednet.open)
        if rednet.isOpen() then
            self:prompt()
            print("Connected to " .. self.serverName .. " with protocol: " .. self.protocol)
            self:detectChests()
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
    while true do
        local id, prot
        id, msg, prot = rednet.receive(self.protocol)
        print(id, msg, prot)
        break
    end

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

            while true do
                local _, msg, _ = rednet.receive(self.protocol)
                return msg["items"]
            end
        end
    else
        -- source should contain an error message
        print(source)
    end

    return nil
end

function storageCLI:run()
    local command
    while true do
        command = read()
    end
end

storageCLI:init()
