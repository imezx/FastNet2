# Server

A Server-sided Connection

## `.new`

Create new FastNet2 event

```lua
(
	Identifier: string
)
```

Identifier will converte/encode into hash identifier

```lua
local Remote = FastNet2.new("Remote")
```

## `:Connect` or `:Listen`

Listen an event from the server to receive, `:Connect` and `:Listen` is the same function.

```lua
(
	player: Player,
	callback: (...any) -> ()
)
```

Each event only allowed have one callback.

```lua
Remote:Connect(function(player, ...)
	print(...)
end)
```

to know if the event is connected or not by doing `.Connected`

```lua
print(Remote.Connected)
```
## `:Once`

This function is same as `:Connect` but it disconnect the event once it fired.

```lua
(
	player: Player,
	callback: (...any) -> ()
)
```

```lua
Remote:Once(function(player, ...)
	print(...)
end)
```

## `:Disconnect`

Disconnect the event

```lua
Remote:Disconnect()
```

## `:Fire`

Fire the event to the spesific client with data.

```lua
(
    player: Player,
	...: any
)
```

```lua
Remote:Fire(player, "Hello World!")
```

::: warning
This function have rate limiting to prevent spamming
:::

## `:Fires`

Fire the event to all clients with data.

```lua
(
	...: any
)
```

```lua
Remote:Fires("Hello World!")
```

::: warning
This function have rate limiting to prevent spamming
:::

## `:Pull`

Pull is a function that invoke to server.

```lua
(
	timeout: number,
    player: Player,
	...: any
) -> (...any)
```

```lua
local Request = Remote:Pull(2, player, "Hello World!")
```

::: warning
This function is yielded, and the minimum for timeout is 2 (seconds)
:::

## `:Wait`

Wait the event that triggered/pinged

```lua
Remote:Wait()
```

::: warning
This function is yielded
:::

## `:Destroy`

Disconnect the event and Remove the event from FastNet2

```lua
Remote:Destroy()
```