# Example

Let's try and play something with FastNet2!

## Server-Side

```lua
local FastNet2 = require("path.to.module")

-- Events
local Example = FastNet2.new("Example")
local Ping = FastNet2.new("Ping")
local Pong = FastNet2.new("Pong")
local PingAll = FastNet2.new("PingAll")

Example:Connect(function(player, arg1, arg2)
    print(arg1, arg2)
    return "Whooo!"
end)

Ping:Connect(function(player, ping)
    if ping then
        print("PING!")
        Pong:Fire(player, true)
        PingAll:Fires(true)
    end
end)
```

## Client-Side

```lua
local Players = game:GetService("Players")
local FastNet2 = require("path.to.module")

-- Events
local Example = FastNet2.new("Example")
local Ping = FastNet2.new("Ping")
local Pong = FastNet2.new("Pong")
local PingAll = FastNet2.new("PingAll")

-- Connect the events
Pong:Connect(function(pong: boolean)
    if pong then
        print("PONG!")
    end
end)

PingAll:Connect(function(isPing: boolean)
    if isPing then
        print("I PINGED!")
    end
end)

-- Let's check if the events is being connected!
print(Pong.Connected)
print(PingAll.Connected)

-- Let's wait `Example` event being triggered!
task.spawn(function()
    print("Waiting for the event...")
    Example:Wait()
    print("Hey the event just triggered!")
end)

-- Try request a event from server!
print(Example:Pull("Hello", "this is from > "..Players.LocalPlayer.Name))
-- Do a ping & pong to server!
Ping:Fire(true)

task.wait(1) -- lets wait 1 seconds!

-- Disconnect the events
Pong:Disconnect()
PingAll:Disconnect()

-- Yay Done!
```