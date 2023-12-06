# Signal

Signal (an alternative for bindable events)

## `.Signal`

Create new Signal event

::: code-group
```lua [main]
(
	Identifier: string
)
```

```lua [Example]
local Signal = FastNet2.Signal("TestSignal")
```
:::

## `:Connect`

Listen an event to signal.

::: code-group
```lua [main]
(
	callback: (...any) -> ()
)
```

```lua [Example]
Signal:Connect(function(...)
	print(...)
end)
```

```lua [Extra]
-- to know if the signal is connected or not by doing `.Connected`
print(Signal.Connected)
```
:::

Each signal event only allowed have one callback.

## `:Once`

This function is same as `:Connect` but it disconnect the signal once it fired.

::: code-group
```lua [main]
(
	callback: (...any) -> ()
)
```

```lua [Example]
Signal:Once(function(...)
	print(...)
end)
```
:::

## `:Disconnect`

Disconnect the signal

```lua
Signal:Disconnect()
```

## `:Fire`

Fire the signal with data.

::: code-group
```lua [main]
(
	...: any
)
```

```lua [Example]
Signal:Fire("Hello World!")
```
:::

## `:Invoke`

Invoke is a function that invoke to signal.

::: code-group
```lua [main]
(
	timeout: number,
	...: any
) -> (...any)
```

```lua [Example]
local Request = Signal:Invoke(2, "Hello World!")
```
:::

::: warning
This function is yielded
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