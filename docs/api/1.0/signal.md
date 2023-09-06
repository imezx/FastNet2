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
Signal:Connect(function(...)
	print(...)
end)
```

to know if the signal is connected or not by doing `.Connected`

```lua
print(Signal.Connected)
```

## `:Once`

This function is same as `:Connect` but it disconnect the signal once it fired.

```lua
(
	callback: (...any) -> ()
)
```

```lua
Signal:Once(function(...)
	print(...)
end)
```

## `:Disconnect`

Disconnect the signal

```lua
Signal:Disconnect()
```

## `:Fire`

Fire the signal with data.

```lua
(
	...: any
)
```

```lua
Signal:Fire("Hello World!")
```

::: warning
This function have rate limiting to prevent spamming
:::

## `:Invoke`

Invoke is a function that invoke to signal.

```lua
(
	timeout: number,
	...: any
) -> (...any)
```

```lua
local Request = Signal:Pull(2, "Hello World!")
```

::: warning
This function is yielded, and this function still on beta
:::

## `:Wait`

Wait the signal that triggered/pinged

```lua
Signal:Wait()
```

::: warning
This function is yielded
:::

## `:Destroy`

Disconnect the signal and remove the signal

```lua
Signal:Destroy()
```