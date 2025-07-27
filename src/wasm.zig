const std = @import("std");
const barmatch_parser = @import("barmatch_parser.zig");

const ParseMode = barmatch_parser.ParseMode;

var g_allocator: std.mem.Allocator = undefined;
var g_output_buffer: []u8 = undefined;
var g_memory_buffer: [1024 * 1024 * 64]u8 = undefined;
var g_fba: std.heap.FixedBufferAllocator = undefined;

export fn _start() void {
    init();
}

export fn init() void {
    g_fba = std.heap.FixedBufferAllocator.init(&g_memory_buffer);
    g_allocator = g_fba.allocator();
    g_output_buffer = &[_]u8{};
}

export fn cleanup() void {
    g_output_buffer = &[_]u8{};
    g_fba.reset();
}

export fn getOutput() ?[*]const u8 {
    if (g_output_buffer.len > 0) {
        return g_output_buffer.ptr;
    }
    return null;
}

export fn alloc(len: usize) usize {
    const slice = g_allocator.alloc(u8, len) catch return 0;
    return @intFromPtr(slice.ptr);
}

export fn parseDemoFileFromMemory(file_data_ptr: usize, file_data_len: usize, mode: u8) usize {
    if (file_data_ptr == 0 or file_data_len == 0) return 0;

    const parseMode = switch (mode) {
        0 => ParseMode.header_only,
        1 => ParseMode.metadata_only,
        2 => ParseMode.essential_only,
        3 => ParseMode.full,
        else => ParseMode.metadata_only,
    };

    g_output_buffer = &[_]u8{};

    const fileData = @as([*]u8, @ptrFromInt(file_data_ptr))[0..file_data_len];

    var stream = std.io.fixedBufferStream(fileData);
    var decompressor = std.compress.gzip.decompressor(stream.reader());
    var match = barmatch_parser.parse(g_allocator, parseMode, decompressor.reader().any()) catch return 0;
    g_output_buffer = match.toJson(g_allocator) catch return 0;

    return g_output_buffer.len;
}
