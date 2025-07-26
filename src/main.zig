const std = @import("std");
const barmatch_parser = @import("barmatch_parser.zig");

const print = std.debug.print;
const ParseMode = barmatch_parser.ParseMode;

pub fn main() !void {
    var total_timer = std.time.Timer.start() catch unreachable;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    // defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        print("Usage: bar_demofile_parser <demofile_path> [mode]\n", .{});
        print("Modes: header, metadata, essential, full (default: header)\n", .{});
        return;
    }

    const filePath = args[1];
    const modeStr = if (args.len > 2) args[2] else "header";
    const mode = if (std.mem.eql(u8, modeStr, "header")) ParseMode.header_only else if (std.mem.eql(u8, modeStr, "metadata")) ParseMode.metadata_only else if (std.mem.eql(u8, modeStr, "essential")) ParseMode.essential_only else if (std.mem.eql(u8, modeStr, "full")) ParseMode.full else ParseMode.header_only;

    const file = try std.fs.cwd().openFile(filePath, .{});
    const fileData = try file.readToEndAlloc(allocator, 1024 * 1024 * 200);
    // defer allocator.free(fileData);

    var fixedBufferStream = std.io.fixedBufferStream(fileData);
    var gzipDecompressor = std.compress.gzip.decompressor(fixedBufferStream.reader());
    const reader = gzipDecompressor.reader();

    var match = try barmatch_parser.parse(allocator, mode, reader.any());
    defer match.deinit();

    // Convert to JSON and print
    const json = try match.toJson(allocator);
    // defer allocator.free(json);

    // Total time taken
    print("Total time taken: {}ms\n", .{total_timer.read() / std.time.ns_per_ms});

    // stdout json
    const stdout = std.io.getStdOut().writer();
    try stdout.writeAll(json);
}
