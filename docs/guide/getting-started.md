# Getting Started

### Step 1:
First, you have to require the module

```lua
local FastNet2 = require('path.to.module');
```

### Step 2:
Then, to create a new event you have to use `.new` function

```lua
local Remote = FastNet2.new("EventName");
```

### Step 3:
Firing event everytime player join

```lua
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
    Remote:Fire(player, "Welcome!")
end)
```

::: tip
FastNet2 have built-in feature called `pre-process` that could wait until the player event is being connected, so you dont have worry about that!
:::