const std = @import("std");
const bardemofile_parser = @import("barmatch_parser.zig");

const print = std.debug.print;
const ParseMode = bardemofile_parser.ParseMode;
const BarDemofileParser = bardemofile_parser.BarDemofileParser;

// WASM handles
var g_allocator: std.mem.Allocator = undefined;
var g_gpa: std.heap.GeneralPurposeAllocator(.{}) = undefined;
var g_output_buffer: []u8 = undefined;
var g_initialized: bool = false;

var stdout = std.io.getStdOut().writer();
var stderr = std.io.getStdErr().writer();

export fn _start() void {
    init();
}

// Initialize the allocator (call this once)
export fn init() void {
    stdout.print("Allocator initialized\n", .{}) catch {};
    g_allocator = std.heap.wasm_allocator;
    g_initialized = true;
}

// Clean up resources (call this when done)
export fn cleanup() void {
    if (g_initialized) {
        if (g_output_buffer.len > 0) {
            g_allocator.free(g_output_buffer);
            g_output_buffer = undefined;
        }
        _ = g_gpa.deinit();
        g_initialized = false;
    }
}

// Free the current output buffer
export fn freeOutput() void {
    if (g_initialized and g_output_buffer.len > 0) {
        stdout.print("Freeing output buffer of size: {}\n", .{g_output_buffer.len}) catch {};
        g_allocator.free(g_output_buffer);
        g_output_buffer = &[_]u8{};
    }
}

// Get the current output buffer
export fn getOutput() ?[*]const u8 {
    if (g_initialized and g_output_buffer.len > 0) {
        return g_output_buffer.ptr;
    }
    return null;
}

export fn alloc(len: usize) usize {
    if (!g_initialized) {
        stderr.print("Allocator not initialized\n", .{}) catch {};
        return 0;
    }
    const slice = g_allocator.alloc(u8, len) catch |err| {
        stderr.print("Allocation error: {}\n", .{err}) catch {};
        return 0;
    };
    return @intFromPtr(slice.ptr);
}

export fn free(ptr: usize, len: usize) void {
    if (ptr == 0) {
        stderr.print("Attempted to free null pointer\n", .{}) catch {};
        return;
    }
    if (!g_initialized) {
        stderr.print("Allocator not initialized\n", .{}) catch {};
        return;
    }
    const slice: []u8 = @as([*]u8, @ptrFromInt(ptr))[0..len];
    g_allocator.free(slice);
}

export fn parseDemoFile(file_path_ptr: usize, file_path_len: usize, mode: u8) usize {
    const file_path_slice: [*]u8 = @ptrFromInt(file_path_ptr);
    const filePath = file_path_slice[0..file_path_len];

    const parseMode = switch (mode) {
        0 => ParseMode.header_only,
        1 => ParseMode.metadata_only,
        2 => ParseMode.essential_only,
        3 => ParseMode.full,
        else => ParseMode.metadata_only,
    };
    stdout.print("parseDemoFile() called with path: {s}, mode: {}\n", .{ filePath, parseMode }) catch {};

    if (!g_initialized) {
        init();
    }

    // Check if the file exists
    const fs = std.fs.cwd();
    const file = fs.openFile(filePath, .{}) catch |err| {
        stderr.print("Error opening file '{s}': {}\n", .{ filePath, err }) catch {};
        return 0;
    };
    defer file.close();
    stdout.print("File '{s}' opened successfully\n", .{filePath}) catch {};

    // Free any existing output buffer
    // freeOutput();

    const maxFileSize: usize = 1024 * 1024 * 100; // 100 MB
    const fileData = file.readToEndAlloc(g_allocator, maxFileSize) catch |err| {
        stderr.print("Error reading file '{s}': {}\n", .{ filePath, err }) catch {};
        return 0;
    };
    defer g_allocator.free(fileData);

    var fixedBufferStream = std.io.fixedBufferStream(fileData);
    var gzipDecompressor = std.compress.gzip.decompressor(fixedBufferStream.reader());
    const reader = gzipDecompressor.reader();

    // // Parse the demo file
    var parser = BarDemofileParser(@TypeOf(reader)).init(g_allocator, parseMode, reader);
    stdout.print("Parser initialized successfully\n", .{}) catch {};
    var match = parser.parse() catch |err| {
        stderr.print("Error parsing demo file: {}\n", .{err}) catch {};
        return 0;
    };
    stdout.print("Demo file parsed successfully, game_id={x}\n", .{match.header.game_id}) catch {};

    g_output_buffer = match.toJson(g_allocator) catch |err| {
        stderr.print("Error converting match to JSON: {}\n", .{err}) catch {};
        return 0;
    };

    return g_output_buffer.len;
}
