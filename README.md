##nimm: Command-line module lookup tool for Nimrod

I'm a fan of Python REPL where I can use `dir(<module>)`, `print <symbol>.__doc__` to get module/function info with ease. This utility lets you do the same (sort of) for Nimrod language. Easiest way to look up documentation without having to browse manual pages on the Web.

##How to use

Define an environment variable `NIMDOC` pointing to the Nimrod package doc directory where you have a bunch of HTML documents. Putting it in an .rc file would be a good idea. Simply run nimm, and type any symbol to get the associated documentation:

    nimm> inittable
    ==== tables ====================
    proc initTable[A, B](initialSize = 64): TTable[A, B]


    creates a new hash table that is empty.

    initialSize needs to be a power of two. If you need to accept runtime
    values for this you could use the nextPowerOfTwo proc from the math module.

It displays the description of proc initTable from module tables. It even suggests available symbols with similar name if no match is found:

    nimm> initable
    No match found. Suggestion: inittable

Simply type 'm' to get the list of all the available modules:

    nimm> m
    Available modules:
    actors, algorithm, asyncio, base64, browsers, c2nim, cgi, channels, colors,....


`m` followed by `<module>` shows all the exported symbols of the module:

    nimm> m zipfiles
    ==== Imports====

    ==== Types====
    TZipArchive = object of TObject
      mode: TFileMode
      w: Pzip

    PZipFileStream = ref TZipFileStream

    ==== Procs====
    proc open(z: var TZipArchive; filename: string; mode: TFileMode = fmRead): bool {.
        raises: [EOS], tags: [FReadDir, FWriteDir].}
    proc close(z: var TZipArchive) {.raises: [], tags: [].}
    proc createDir(z: var TZipArchive; dir: string) {.raises: [], tags: [].}
    proc addFile(z: var TZipArchive; dest, src: string) {.raises: [EIO], tags: [].}
    proc addFile(z: var TZipArchive; file: string) {.raises: [EIO], tags: [].}
    proc addFile(z: var TZipArchive; dest: string; src: PStream) {.
        raises: [E_Base, EIO], tags: [FReadIO, FTime].}
    proc getStream(z: var TZipArchive; filename: string): PZipFileStream {.
        raises: [], tags: [].}
    proc extractFile(z: var TZipArchive; srcFile: string; dest: PStream) {.
        raises: [E_Base], tags: [FWriteIO, FReadIO].}
    proc extractFile(z: var TZipArchive; srcFile: string; dest: string) {.
        raises: [EOutOfMemory, E_Base], tags: [FWriteIO, FReadIO].}
    proc extractAll(z: var TZipArchive; dest: string) {.
        raises: [EOutOfMemory, E_Base], tags: [FWriteIO, FReadIO].}

    ==== Iterators====
    iterator walkFiles(z: var TZipArchive): string {.raises: [], tags: [].}

Happy Nimroding!

