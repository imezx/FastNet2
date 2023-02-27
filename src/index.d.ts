interface Debug {
    set_debug(x : boolean): void
    __direct_debug(c: any, m: string, l: number, l2: number | undefined): boolean
    get_debugs_inrange(range: number): any
}

interface FastNet2 {
    // Debug.luau
    set_debug(x : boolean): void
    __direct_debug(c: any, m: string, l: number, l2: number | undefined): boolean
    // init.luau
    IsExist(remoteName: string): boolean
    toBestFormNumber(num: number): number | string
    Get(remoteName: string, waitFor: number): any
    Create(remoteName: string, typeRemote: string): any
    up(): number
    down(): number
    Wait(): number
    getProvider(toBool: boolean | undefined): any
    _setdebug(On: boolean)
    CreateUUID(): string
    randStr(length: number | undefined): string
}

export default FastNet2