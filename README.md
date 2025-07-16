Build WASM

```
zig build-exe -target wasm32-wasi -O ReleaseSmall --export=init --export=cleanup --export=freeOutput --export=getOutput --export=parseDemoFile src/wasm.zig
```

Build Release

```
zig build -Doptimize=ReleaseFast
```

Scan the whole folder

```
time for file in *.sdfz; ./zig_parser "$file" metadata > (basename "$file" .sdfz).json & end; wait
```
