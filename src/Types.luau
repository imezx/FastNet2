--!strict
export type callback = (...any) -> ()

export type ServerNet<T...> = {
	Identifier: string,
	func: callback,
	Connected: boolean,
	packets: {any},
	_ping: unknown?,
	single: {any},
	Connect: (self: ServerNet<T...>, callback: callback) -> (),
	Listen: (self: ServerNet<T...>, callback: callback) -> (),
	Once: (self: ServerNet<T...>, callback: callback) -> (),
	Wait: (self: ServerNet<T...>) -> number,
	Disconnect: (self: ServerNet<T...>) -> (),
	Destroy: (self: ServerNet<T...>) -> (),
	Fire: (self: ServerNet<T...>, player: Player, T...) -> (),
	Fires: (self: ServerNet<T...>, T...) -> (),
}

export type ClientNet<T...> = {
	Identifier: string,
	func: callback,
	Connected: boolean,
	packets: {any},
	_ping: unknown?,
	Connect: (self: ClientNet<T...>, callback: callback) -> (),
	Listen: (self: ClientNet<T...>, callback: callback) -> (),
	Once: (self: ClientNet<T...>, callback: callback) -> (),
	Wait: (self: ClientNet<T...>) -> number,
	Disconnect: (self: ClientNet<T...>) -> (),
	Destroy: (self: ClientNet<T...>) -> (),
	Fire: (self: ClientNet<T...>, T...) -> (),
}

return nil
