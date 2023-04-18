interface Debug {
    silentDebug(silent : boolean): void
    __direct_debug(c: any, m: string, l: number, l2: number | undefined): boolean
    get_log(sName: string?): any
}

interface FastNet2 {
    // Debug.luau
    _setdebug(x : boolean): void
    __direct_debug(c: any, m: string, l: number, l2: number | undefined): boolean
    // init.luau
    IsExist(remoteName: string): boolean
    toBestFormNumber(num: number): number | string
    Get(remoteName: string, waitFor: number): any
    Create(remoteName: string, typeRemote: string): any
    up(): number
    down(): number
    Wait(): number
    _setdebug(On: boolean)
    CreateUUID(): string
    randStr(length: number | undefined): string
    fps(): number
    Nearest(): any
    getdebugcaches(): any
}

export default FastNet2
