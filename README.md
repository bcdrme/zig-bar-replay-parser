Build WASM

```
zig build-exe -target wasm32-wasi --export=parse_demo_file --export=get_json_buffer --export=get_error_buffer --export=get_erro
r_length src/main.zig
```
