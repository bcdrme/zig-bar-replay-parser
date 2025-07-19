# A Recoil Engine replay parser written in Zig

## Build Release

```
zig build -Doptimize=ReleaseFast
```

Scan the whole folder

```
time for file in *.sdfz; ./zig_parser "$file" metadata > (basename "$file" .sdfz).json & end; wait
```

## Build WASM

```
zig build-exe -target wasm32-wasi -O ReleaseSmall --export=init --export=cleanup --export=getOutput --export=alloc --export=parseDemoFileFromMemory src/wasm.zig
```

```
node nodejs-wasm-example/main.js
```
