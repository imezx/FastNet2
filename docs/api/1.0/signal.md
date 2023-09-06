# Signal

Signal (an alternative for bindable events)

## `.Signal`

Create new Signal event

```lua
(
	Identifier: string
)
```

```lua
local Signal = FastNet2.Signal("TestSignal")
```

## `:Connect`

Listen an event to signal.

```lua
(
	callback: (...any) -> ()
)
```

Each signal event only allowed have one callback.

```lua
Remote:Connect(function(...)
	print(...)
end)
```

to know if the event is connected or not by doing `.Connected`

```lua
print(Remote.Connected)
```

## `:Once`

This function is same as `:Connect` but it disconnect the signal once it fired.

```lua
(
	callback: (...any) -> ()
)
```

```lua
Remote:Once(function(...)
	print(...)
end)
```

## `:Disconnect`

Disconnect the event

```lua
Remote:Disconnect()
```

## `:Fire`

Fire the event to the server with data.

```lua
(
	...: any
)
```

```lua
Remote:Fire("Hello World!")
```

::: warning
This function have rate limiting to prevent spamming
:::

## `:Invoke`

Invoke is a function that invoke to server.

```lua
(
	timeout: number,
	...: any
) -> (...any)
```

```lua
local Request = Remote:Pull(2, "Hello World!")
```

::: warning
This function is yielded, and this function still on beta
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