import { readFile, readdir } from "fs/promises";
import { WASI } from "wasi";
import { join } from "path";

async function runWithNodeWASI() {
  const wasi = new WASI({
    args: [],
    env: {},
    version: "preview1",
    preopens: { "/": "/home/benoit/temp" },
    stderr: process.stderr.fd,
    stdout: process.stdout.fd,
  });

  const wasm = await WebAssembly.compile(await readFile("wasm.wasm"));
  const memory = new WebAssembly.Memory({
    initial: 256,
    maximum: 2048,
    shared: false,
  });

  const importObject = {
    wasi_snapshot_preview1: wasi.wasiImport,
    env: { memory },
  };

  const instance = await WebAssembly.instantiate(wasm, importObject);
  wasi.start(instance);

  const entries = await readdir("/home/benoit/temp", { withFileTypes: true });
  const files = entries.filter((d) => d.isFile() && d.name.endsWith(".sdfz"));

  console.log("Files to process:", files.length);
  console.time("Processing files");

  for (const file of files) {
    console.log(`\nProcessing: ${file.name}`);

    const filePath = join("/home/benoit/temp", file.name);
    const fileBuffer = await readFile(filePath);
    console.log(
      `File read: ${(fileBuffer.length / (1024 * 1024)).toFixed(1)}MB`
    );

    const fileDataPtr = instance.exports.alloc(fileBuffer.length);
    if (fileDataPtr === 0) {
      console.error("Failed to allocate memory");
      continue;
    }

    const fileDataView = new Uint8Array(
      instance.exports.memory.buffer,
      fileDataPtr,
      fileBuffer.length
    );
    fileDataView.set(fileBuffer);

    try {
      const outputLength = instance.exports.parseDemoFileFromMemory(
        fileDataPtr,
        fileBuffer.length,
        3
      );

      if (outputLength === 0) {
        console.error(`Failed to parse: ${file.name}`);
        continue;
      }

      const outputPtr = instance.exports.getOutput();
      if (outputPtr === 0) {
        console.error("Failed to get output");
        continue;
      }

      const outputData = new Uint8Array(
        instance.exports.memory.buffer,
        outputPtr,
        outputLength
      );
      const outputString = new TextDecoder().decode(outputData);

      const json = JSON.parse(outputString);
      console.log(`✅ Game ID: ${json.header?.game_id}`);
    } catch (error) {
      console.error("Error:", error);
    } finally {
      // Reset allocator after each file to avoid fragmentation
      instance.exports.cleanup();
      instance.exports.init();
    }
  }

  console.timeEnd("Processing files");
}

runWithNodeWASI().catch(console.error);
