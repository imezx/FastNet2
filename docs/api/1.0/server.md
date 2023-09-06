# Server

A Server-sided Connection

## `.new`

Create new FastNet2 event

::: code-group
```lua [main]
(
	Identifier: string
)
```

```lua [Example]
local Remote = FastNet2.new("Remote")
```
:::

Identifier will converte/encode into hash identifier

## `:Connect` or `:Listen`

Listen an event from the client to receive, `:Connect` and `:Listen` is the same function.

::: code-group
```lua [main]
(
	player: Player,
	callback: (...any) -> ()
)
```

```lua [Example]
Remote:Connect(function(player, ...)
	print(...)
end)
```

```lua [Extra]
-- to know if the event is connected or not by doing `.Connected`
print(Remote.Connected)
```
:::

Each event only allowed have one callback.

## `:Once`

This function is same as `:Connect` but it disconnect the event once it fired.

::: code-group
```lua [main]
(
	player: Player,
	callback: (...any) -> ()
)
```

```lua [Example]
Remote:Once(function(player, ...)
	print(...)
end)
```
:::

## `:Disconnect`

Disconnect the event

```lua
Remote:Disconnect()
```

## `:Fire`

Fire the event to the spesific client with data.

::: code-group
```lua [main]
(
    player: Player,
	...: any
)
```

```lua [Example]
Remote:Fire(player, "Hello World!")
```
:::

## `:Fires` <Badge type="tip" text="Server Only" />

Fire the event to all clients with data.

::: code-group
```lua [main]
(
	...: any
)
```

```lua [Example]
Remote:Fires("Hello World!")
```
:::

## `:Pull`

Pull is a function that invoke to client.

::: code-group
```lua [main]
(
	timeout: number,
    player: Player,
	...: any
) -> (...any)
```

```lua [Example]
local Request = Remote:Pull(2, player, "Hello World!")
```
:::

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