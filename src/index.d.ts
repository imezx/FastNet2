interface FastNet2 {
    // Debug.luau
    set_debug(x: boolean): undefined
    __direct_debug(c: any, m: string, l: number, l2: number | undefined): boolean
    // init.luau
    IsExist(remoteName: string): boolean
    toBestFormNumber(num: number): number | string
    Get(remoteName: string, waitFor: number): any
    Create(remoteName: string, typeRemote: string): any
}

export default FastNet2