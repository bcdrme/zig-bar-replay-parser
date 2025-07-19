const std = @import("std");
const bardemofile_parser = @import("barmatch_parser.zig");

const ParseMode = bardemofile_parser.ParseMode;
const BarDemofileParser = bardemofile_parser.BarDemofileParser;

var g_allocator: std.mem.Allocator = undefined;
var g_output_buffer: []u8 = undefined;
var g_initialized: bool = false;
var g_memory_buffer: [1024 * 1024 * 64]u8 = undefined;
var g_fba: std.heap.FixedBufferAllocator = undefined;

export fn _start() void {
    g_fba = std.heap.FixedBufferAllocator.init(&g_memory_buffer);
    g_allocator = g_fba.allocator();
    g_output_buffer = &[_]u8{};
    g_initialized = true;
}

export fn cleanup() void {
    if (g_initialized) {
        if (g_output_buffer.len > 0) {
            g_output_buffer = &[_]u8{};
        }
        g_fba.reset();
        g_initialized = false;
    }
}

export fn freeOutput() void {
    if (g_initialized and g_output_buffer.len > 0) {
        g_output_buffer = &[_]u8{};
    }
}

export fn getOutput() ?[*]const u8 {
    if (g_initialized and g_output_buffer.len > 0) {
        return g_output_buffer.ptr;
    }
    return null;
}

export fn alloc(len: usize) usize {
    if (!g_initialized) return 0;
    const slice = g_allocator.alloc(u8, len) catch return 0;
    return @intFromPtr(slice.ptr);
}

export fn free(ptr: usize, len: usize) void {
    if (ptr == 0 or !g_initialized) return;
    const slice: []u8 = @as([*]u8, @ptrFromInt(ptr))[0..len];
    g_allocator.free(slice);
}

export fn parseDemoFileFromMemory(file_data_ptr: usize, file_data_len: usize, mode: u8) usize {
    if (!g_initialized or file_data_ptr == 0 or file_data_len == 0) return 0;

    const parseMode = switch (mode) {
        0 => ParseMode.header_only,
        1 => ParseMode.metadata_only,
        2 => ParseMode.essential_only,
        3 => ParseMode.full,
        else => ParseMode.metadata_only,
    };

    freeOutput();

    const file_data_slice: [*]u8 = @ptrFromInt(file_data_ptr);
    const fileData = file_data_slice[0..file_data_len];

    var fixedBufferStream = std.io.fixedBufferStream(fileData);
    var gzipDecompressor = std.compress.gzip.decompressor(fixedBufferStream.reader());
    const reader = gzipDecompressor.reader();

    var parser = BarDemofileParser(@TypeOf(reader)).init(g_allocator, parseMode, reader);
    var match = parser.parse() catch return 0;
    g_output_buffer = match.toJson(g_allocator) catch return 0;

    return g_output_buffer.len;
}
