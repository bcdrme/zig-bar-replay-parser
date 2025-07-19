import { readFile, readdir } from "fs/promises";
import { env } from "process";
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

  const wasm = await WebAssembly.compile(await readFile("../wasm.wasm"));
  // const memory = new WebAssembly.Memory({ initial: 65536, maximum: 65536 });
  const importObject = {
    wasi_snapshot_preview1: wasi.wasiImport,
    // env: { memory },
  };
  const instance = await WebAssembly.instantiate(wasm, importObject);
  wasi.start(instance);

  const entries = await readdir("/home/benoit/temp", {
    withFileTypes: true,
  });

  const files = entries.filter(
    (dirent) => dirent.isFile() && dirent.name.endsWith(".sdfz")
  );

  console.log("Files to process:", files.length);
  console.time("Processing files");
  for (const file of files) {
    const memory = instance.exports.memory;
    const filePath = file.name;
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
  console.timeEnd("Processing files");
}

runWithNodeWASI();
