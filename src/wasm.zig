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

export fn _start() void {
    init();
}

// Initialize the allocator (call this once)
export fn init() void {
    g_gpa = std.heap.GeneralPurposeAllocator(.{}){};
    g_allocator = g_gpa.allocator();
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
        g_allocator.free(g_output_buffer);
        g_output_buffer = &[_]u8{};
    }
}

// Get the current output buffer
export fn getOutput() []const u8 {
    if (g_initialized and g_output_buffer.len > 0) {
        return g_output_buffer;
    }
    return &[_]u8{};
}

export fn parseDemoFile(file_path_ptr: [*]const u8, file_path_len: u32, mode: u8) usize {
    if (!g_initialized) {
        init();
    }

    // Free any existing output buffer
    freeOutput();

    // Convert C string to Zig slice
    const file_path = file_path_ptr[0..file_path_len];

    // Convert mode number to ParseMode
    const parse_mode = switch (mode) {
        0 => ParseMode.header_only,
        1 => ParseMode.metadata_only,
        2 => ParseMode.essential_only,
        3 => ParseMode.full,
        else => ParseMode.metadata_only,
    };

    // Parse the demo file
    var parser = BarDemofileParser.init(g_allocator, file_path, parse_mode) catch |err| {
        print("Error initializing parser: {}\n", .{err});
        return 0;
    };
    defer parser.deinit();

    var match = parser.parse() catch |err| {
        print("Error parsing demo file: {}\n", .{err});
        return 0;
    };
    defer match.deinit();

    g_output_buffer = match.toJson(g_allocator) catch |err| {
        print("Error converting match to JSON: {}\n", .{err});
        return 0;
    };

    return g_output_buffer.len;
}
