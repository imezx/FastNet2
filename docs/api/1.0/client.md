# Client

A Client-sided Connection

## `.new`

Create new FastNet2 event

::: code-group
```lua [main]
(
	Identifier: string,
	reliable: boolean
)
```

```lua [Example]
local Remote = FastNet2.new("Remote", false) -- is unreliable event
local Remote2 = FastNet2.new("Remote", true) -- is reliable event
local Remote3 = FastNet2.new("Remote") -- is also reliable event
```
:::

Identifier will converte/encode into hash identifier

## `:Connect` or `:Listen`

Listen an event from the server to receive, `:Connect` and `:Listen` is the same function.

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

Fire the event to the spesific server with data.

::: code-group
```lua [main]
(
	...: any
)
```

```lua [Example]
Remote:Fire("Hello World!")
```
:::

::: warning
This function have rate limiting to prevent spamming
:::

## `:Invoke`

Semiliar with :InvokeServer, its for doing Invoke to a Server.

::: code-group
```lua [main]
(
	timeout: number,
	...: any
) -> (...any)
```

```lua [Example]
local Request = Remote:Invoke(2, "Hello World!")
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