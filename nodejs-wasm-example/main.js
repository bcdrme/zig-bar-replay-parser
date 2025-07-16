import { readFile } from "fs/promises";
import { WASI } from "wasi";

async function runWithNodeWASI() {
  const wasi = new WASI({
    args: [],
    env: {},
    version: "preview1",
    preopens: {
      "/": "/home/benoit/temp",
    },
    stderr: process.stderr.fd,
    stdout: process.stdout.fd,
  });

  const importObject = { wasi_snapshot_preview1: wasi.wasiImport };
  const wasm = await WebAssembly.compile(await readFile("../wasm.wasm"));
  const instance = await WebAssembly.instantiate(wasm, importObject);
  wasi.start(instance);

  // Performance test - ensuring we can reuse the instance
  // and that the memory is correctly managed.
  for (let i = 0; i < 1024; i++) {
    const memory = instance.exports.memory;
    const filePath =
      "2025-07-02_22-18-20-632_All That Simmers v1.1_2025.04.08.sdfz";
    const filePathPtr = new Uint8Array(memory.buffer, 0, filePath.length);
    filePathPtr.set(new TextEncoder().encode(filePath));

    const outputLength = instance.exports.parseDemoFile(
      filePathPtr,
      filePath.length,
      1 // metadata_only mode
    );

    const outputBuffer = instance.exports.getOutput();
    const outputData = new Uint8Array(
      memory.buffer,
      outputBuffer,
      outputLength
    );
    const outputString = new TextDecoder().decode(outputData);
    const json = JSON.parse(outputString);
    console.log("Output JSON:", json.header.game_id);
  }
}

runWithNodeWASI();
