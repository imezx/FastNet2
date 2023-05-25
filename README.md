# FastNet2 - a Fastest & Powerful Networking Module
a Powerful & Fastest Networking module made for ROBLOX Platform

# Wally Support
> https://wally.run/package/imezx/fastnet2

# * FastNet2 - APIs

- :IsExist(remoteName: string): boolean
-> Check if the remote is exists
- :toBestFormNumber(num: number): number | string
- :Get(remoteName: string, waitFor: number): any
-> Receive/Get remote, waitFor is yielded
- :Create(remoteName: string, typeRemote: string): any
-> Create new remote, typeRemote: "Event"/"Events"
- .CreateUUID(): string
-> Generate Unique ID as string
- .randStr(length: number | undefined): string
-> alternative for using createUUID but faster version but its lite version of unique
- .up(): number
- .down(): number
- .Wait(): number
- .delta()

# * FastNet2 - RFunctions
- Remote:Disconenct(messageOutput: string): undefined
-> Disconenct currently connected remote, messageOutput print-out when disconnected

# * FastNet2 - REvents
- Remote:Listen(waitTill: boolean | any, callback: any): never
-> Connect/Listen to the remote connection receiver
- Remote:Disconnect(messageOutput: string): undefined
-> Disconnect currently connected remote, messageOutput print-out when disconnected
- Remote:Destroy()
-> Destroy & Disconnect the remote
- Remote:Wait(): number
-> Wait till next remote packet is going fire or fired

> Server
- Remote:Pull(player: Player, ...: any) -- RFunction
- Remote:Fire(player: Player, ...: any) -- REvents
Note: Server currently incompleted

> Client
- Remote:Pull(...: any) -- RFunction
- Remote:Fire(...: any) -- REvents
