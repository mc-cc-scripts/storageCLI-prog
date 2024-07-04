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

function storageCLI:init()
    Config:init(defaultConfig)

    if args[1] == "config" then
        Config:command(args)
    else
        self.protocol = Config:get('protocol')
        self.serverName = Config:get('serverName')
        
        peripheral.find("modem", rednet.open)
        if rednet.isOpen() then
            self:run()
            rednet.unhost(self.protocol)
        else
            print("No open modem found.")
        end
    end
end

function storageCLI:run()
    while true do
        
    end
end

storageCLI:init()
