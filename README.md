# FastNet2 - a Incredible and Powerful Networking Module
Next-gen of FastNet & Networking Module

# Wally Support
https://wally.run/package/imezx/fastnet2

# * FastNet2 - APIs

- FastNet2:IsExist(remoteName: string): boolean
-> Check if the remote is exists
- FastNet2:toBestFormNumber(num: number): number | string
- FastNet2:Get(remoteName: string, waitFor: number): any
-> Receive/Get remote, waitFor is yielded
- FastNet2:Create(remoteName: string, typeRemote: string): any
-> Create new remote, typeRemote: "Event"/"Events"
- FastNet2.CreateUUID(): string
-> Generate Unique ID as string
- FastNet2.randStr(length: number | undefined): string
-> alternative for using createUUID but faster version but its lite version of unique
- FastNet2.up(): number
- FastNet2.down(): number
- FastNet2.Wait(): number
- FastNet2.delta()

# * FastNet2 - RFunctions
- FastNet2Remote:Disconenct(messageOutput: string): undefined
-> Disconenct currently connected remote, messageOutput print-out when disconnected

# * FastNet2 - REvents
- FastNet2Remote:Listen(waitTill: boolean | any, callback: any): never
-> Connect/Listen to the remote connection receiver
- FastNet2Remote:Disconnect(messageOutput: string): undefined
-> Disconnect currently connected remote, messageOutput print-out when disconnected
- FastNet2Remote:Destroy()
-> Destroy & Disconnect the remote
- FastNet2Remote:Wait(): number
-> Wait till next remote packet is going fire or fired

> Server
- FastNet2Remote:Pull(player: Player, ...: any) -- RFunction
- FastNet2Remote:Fire(player: Player, ...: any) -- REvents
Note: Server currently incompleted

> Client
- FastNet2Remote:Pull(...: any) -- RFunction
- FastNet2Remote:Fire(...: any) -- REvents
