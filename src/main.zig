const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const HashMap = std.HashMap;
const print = std.debug.print;

// Error types
const ParseError = error{
    InvalidMagic,
    InvalidGameId,
    DecompressionTooLarge,
    UnexpectedReaderPosition,
    OutOfMemory,
    EndOfStream,
    InvalidHeader,
};

// Packet types (equivalent to BarPacketType)
const PacketType = struct {
    const CHAT: u8 = 20;
    const GAME_ID: u8 = 2;
    const START_POS: u8 = 60;
    const LUA_MSG: u8 = 50;
    const KEYFRAME: u8 = 1;
    const NEW_FRAME: u8 = 4;
    const GAME_OVER: u8 = 10;
    const TEAM_MSG: u8 = 13;
    const QUIT: u8 = 3;
};

// Vector3 equivalent
const Vector3 = struct {
    x: f32,
    y: f32,
    z: f32,
};

// Player structures
const BarMatchPlayer = struct {
    team_id: i32,
    game_id: []const u8,
    ally_team_id: i32,
    player_id: i32,
    user_id: i64,
    name: []const u8,
    handicap: f64 = 0.0,
    faction: []const u8,
    skill_uncertainty: f64,
    skill: f64,
    starting_position: ?Vector3 = null,
    color: u32 = 0,
};

const BarMatchChatMessage = struct {
    size: u8,
    from_id: u8,
    to_id: u8,
    message: []const u8,
    game_id: []const u8,
    game_timestamp: f32,
};

const BarMatchTeamDeath = struct {
    game_id: []const u8,
    team_id: u8,
    reason: u8,
    game_time: f32,
};

// Gamemode enum
const BarGamemode = enum {
    DUEL,
    SMALL_TEAM,
    LARGE_TEAM,
    FFA,
    TEAM_FFA,
    UNKNOWN,
};

// Main match structure
const BarMatch = struct {
    header: DemofileHeader,
    file_name: []const u8,
    mod_config: []const u8,
    duration_frame_count: i32 = 0,
    packet_offset: usize = 0,
    stat_offset: usize = 0,
    winning_ally_teams: ArrayList(u8),
    gamemode: BarGamemode = .UNKNOWN,
    players: ArrayList(BarMatchPlayer),
    chat_messages: ArrayList(BarMatchChatMessage),
    team_deaths: ArrayList(BarMatchTeamDeath),
    allocator: Allocator,

    pub fn init(allocator: Allocator) BarMatch {
        return BarMatch{
            .header = DemofileHeader.init(allocator),
            .file_name = "",
            .mod_config = "",
            .winning_ally_teams = ArrayList(u8).init(allocator),
            .players = ArrayList(BarMatchPlayer).init(allocator),
            .chat_messages = ArrayList(BarMatchChatMessage).init(allocator),
            .team_deaths = ArrayList(BarMatchTeamDeath).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BarMatch) void {
        self.header.deinit();
        if (self.file_name.len > 0) self.allocator.free(self.file_name);
        if (self.mod_config.len > 0) self.allocator.free(self.mod_config);
        self.winning_ally_teams.deinit();

        for (self.players.items) |player| {
            if (player.game_id.len > 0) self.allocator.free(player.game_id);
            if (player.name.len > 0) self.allocator.free(player.name);
            if (player.faction.len > 0) self.allocator.free(player.faction);
        }
        self.players.deinit();

        for (self.chat_messages.items) |msg| {
            if (msg.message.len > 0) self.allocator.free(msg.message);
            if (msg.game_id.len > 0) self.allocator.free(msg.game_id);
        }
        self.chat_messages.deinit();

        for (self.team_deaths.items) |death| {
            if (death.game_id.len > 0) self.allocator.free(death.game_id);
        }
        self.team_deaths.deinit();
    }
};

// Header structure
const DemofileHeader = struct {
    magic: []const u8,
    header_version: i32,
    header_size: i32,
    game_version: []const u8,
    game_id: []const u8,
    start_time: i64,
    script_size: i32,
    demo_stream_size: i32,
    game_time: i32,
    wall_clock_time: i32,
    player_count: i32,
    player_stat_size: i32,
    player_stat_elem_size: i32,
    team_count: i32,
    team_stat_size: i32,
    team_stat_elem_size: i32,
    team_stat_period: i32,
    winning_ally_teams_size: i32,
    allocator: Allocator,

    pub fn init(allocator: Allocator) DemofileHeader {
        return DemofileHeader{
            .magic = "",
            .header_version = 0,
            .header_size = 0,
            .game_version = "",
            .game_id = "",
            .start_time = 0,
            .script_size = 0,
            .demo_stream_size = 0,
            .game_time = 0,
            .wall_clock_time = 0,
            .player_count = 0,
            .player_stat_size = 0,
            .player_stat_elem_size = 0,
            .team_count = 0,
            .team_stat_size = 0,
            .team_stat_elem_size = 0,
            .team_stat_period = 0,
            .winning_ally_teams_size = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DemofileHeader) void {
        if (self.magic.len > 0) self.allocator.free(self.magic);
        if (self.game_version.len > 0) self.allocator.free(self.game_version);
        if (self.game_id.len > 0) self.allocator.free(self.game_id);
    }
};

// Streaming byte reader for incremental decompression
const StreamingByteReader = struct {
    gzip_stream: std.compress.gzip.Decompressor(std.io.FixedBufferStream([]const u8).Reader),
    buffer: []u8,
    buffer_pos: usize,
    buffer_len: usize,
    total_read: usize,
    allocator: Allocator,
    max_size: usize,

    pub fn init(allocator: Allocator, compressed_data: []const u8, max_size: usize) !StreamingByteReader {
        var stream = std.io.fixedBufferStream(compressed_data);
        const gzip_stream = std.compress.gzip.decompressor(stream.reader());

        // Use a reasonable buffer size (64KB)
        const buffer = try allocator.alloc(u8, 65536);

        return StreamingByteReader{
            .gzip_stream = gzip_stream,
            .buffer = buffer,
            .buffer_pos = 0,
            .buffer_len = 0,
            .total_read = 0,
            .allocator = allocator,
            .max_size = max_size,
        };
    }

    pub fn deinit(self: *StreamingByteReader) void {
        self.allocator.free(self.buffer);
    }

    fn fillBuffer(self: *StreamingByteReader) !void {
        if (self.buffer_pos < self.buffer_len) return; // Buffer still has data

        self.buffer_pos = 0;
        self.buffer_len = self.gzip_stream.read(self.buffer) catch |err| switch (err) {
            error.EndOfStream => 0,
            else => return err,
        };

        self.total_read += self.buffer_len;

        // Anti-zip-bomb protection
        if (self.total_read > self.max_size) {
            return ParseError.DecompressionTooLarge;
        }
    }

    pub fn readU8(self: *StreamingByteReader) !u8 {
        try self.fillBuffer();
        if (self.buffer_pos >= self.buffer_len) return ParseError.EndOfStream;

        const result = self.buffer[self.buffer_pos];
        self.buffer_pos += 1;
        return result;
    }

    pub fn readI32LE(self: *StreamingByteReader) !i32 {
        var bytes: [4]u8 = undefined;
        for (&bytes) |*byte| {
            byte.* = try self.readU8();
        }
        return std.mem.readInt(i32, &bytes, .little);
    }

    pub fn readU32LE(self: *StreamingByteReader) !u32 {
        var bytes: [4]u8 = undefined;
        for (&bytes) |*byte| {
            byte.* = try self.readU8();
        }
        return std.mem.readInt(u32, &bytes, .little);
    }

    pub fn readI64LE(self: *StreamingByteReader) !i64 {
        var bytes: [8]u8 = undefined;
        for (&bytes) |*byte| {
            byte.* = try self.readU8();
        }
        return std.mem.readInt(i64, &bytes, .little);
    }

    pub fn readF32LE(self: *StreamingByteReader) !f32 {
        const int_val = try self.readU32LE();
        return @as(f32, @bitCast(int_val));
    }

    pub fn readBytes(self: *StreamingByteReader, len: usize) ![]u8 {
        const result = try self.allocator.alloc(u8, len);
        for (result) |*byte| {
            byte.* = try self.readU8();
        }
        return result;
    }

    pub fn readAsciiString(self: *StreamingByteReader, len: usize) ![]u8 {
        return self.readBytes(len);
    }

    pub fn readAsciiStringNullTerminated(self: *StreamingByteReader, max_len: usize) ![]u8 {
        var result = try self.allocator.alloc(u8, max_len);
        var actual_len: usize = 0;

        for (0..max_len) |i| {
            result[i] = try self.readU8();
            if (result[i] == 0) {
                actual_len = i;
                break;
            }
        }

        // Resize to actual length
        if (actual_len < max_len) {
            const trimmed = try self.allocator.realloc(result, actual_len);
            return trimmed;
        }

        return result;
    }

    pub fn skipBytes(self: *StreamingByteReader, len: usize) !void {
        for (0..len) |_| {
            _ = try self.readU8();
        }
    }

    pub fn readUntilNull(self: *StreamingByteReader) ![]u8 {
        var result = ArrayList(u8).init(self.allocator);
        defer result.deinit();

        while (true) {
            const byte = try self.readU8();
            if (byte == 0) break;
            try result.append(byte);
        }

        return result.toOwnedSlice();
    }
};

// Parse mode enum for controlling what gets parsed
const ParseMode = enum {
    HEADER_ONLY, // Only parse header (fastest)
    METADATA_ONLY, // Parse header + basic metadata
    ESSENTIAL_ONLY, // Parse header + essential packets (chat, game events)
    FULL, // Parse everything (slowest)
};

// Main parser
const BarDemofileParser = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) BarDemofileParser {
        return BarDemofileParser{
            .allocator = allocator,
        };
    }

    pub fn parseWithMode(self: *BarDemofileParser, filename: []const u8, demofile: []const u8, mode: ParseMode) !BarMatch {
        var timer = std.time.Timer.start() catch unreachable;

        // Use streaming reader with size limit based on mode
        const max_size: usize = switch (mode) {
            .HEADER_ONLY => 1024 * 1024, // 1MB max for header only
            .METADATA_ONLY => 5 * 1024 * 1024, // 5MB max for metadata
            .ESSENTIAL_ONLY => 50 * 1024 * 1024, // 50MB max for essential
            .FULL => 256 * 1024 * 1024, // 256MB max for full parse
        };

        var reader = try StreamingByteReader.init(self.allocator, demofile, max_size);
        defer reader.deinit();

        const elapsed = timer.read() / std.time.ns_per_ms;
        print("initialized streaming reader [duration={}ms] [input size={}]\n", .{ elapsed, demofile.len });

        return try self.readBytesStreaming(filename, &reader, mode);
    }

    pub fn parse(self: *BarDemofileParser, filename: []const u8, demofile: []const u8) !BarMatch {
        return self.parseWithMode(filename, demofile, .FULL);
    }

    pub fn parseHeaderOnly(self: *BarDemofileParser, filename: []const u8, demofile: []const u8) !BarMatch {
        return self.parseWithMode(filename, demofile, .HEADER_ONLY);
    }

    pub fn parseMetadataOnly(self: *BarDemofileParser, filename: []const u8, demofile: []const u8) !BarMatch {
        return self.parseWithMode(filename, demofile, .METADATA_ONLY);
    }

    fn readBytesStreaming(self: *BarDemofileParser, filename: []const u8, reader: *StreamingByteReader, mode: ParseMode) !BarMatch {
        var match = BarMatch.init(self.allocator);
        errdefer match.deinit();

        // Copy filename
        match.file_name = try self.allocator.dupe(u8, filename);

        // Read header
        const magic = try reader.readAsciiStringNullTerminated(16);
        match.header.magic = magic;

        if (!std.mem.eql(u8, match.header.magic, "spring demofile")) {
            return ParseError.InvalidMagic;
        }

        match.header.header_version = try reader.readI32LE();
        match.header.header_size = try reader.readI32LE();

        const game_version = try reader.readAsciiString(256);
        match.header.game_version = game_version;

        const game_id_bytes = try reader.readBytes(16);
        defer self.allocator.free(game_id_bytes);
        var game_id_buf: [32]u8 = undefined;
        const game_id = std.fmt.bufPrint(&game_id_buf, "{}", .{std.fmt.fmtSliceHexLower(game_id_bytes)}) catch unreachable;
        match.header.game_id = try self.allocator.dupe(u8, game_id);

        match.header.start_time = try reader.readI64LE();
        match.header.script_size = try reader.readI32LE();
        match.header.demo_stream_size = try reader.readI32LE();
        match.header.game_time = try reader.readI32LE();
        match.header.wall_clock_time = try reader.readI32LE();
        match.header.player_count = try reader.readI32LE();
        match.header.player_stat_size = try reader.readI32LE();
        match.header.player_stat_elem_size = try reader.readI32LE();
        match.header.team_count = try reader.readI32LE();
        match.header.team_stat_size = try reader.readI32LE();
        match.header.team_stat_elem_size = try reader.readI32LE();
        match.header.team_stat_period = try reader.readI32LE();
        match.header.winning_ally_teams_size = try reader.readI32LE();

        // Early exit for header-only mode
        if (mode == .HEADER_ONLY) {
            match.mod_config = try self.allocator.dupe(u8, "");
            return match;
        }

        // Read mod config
        if (match.header.script_size > 0) {
            if (mode == .METADATA_ONLY and match.header.script_size > 100 * 1024) {
                // Skip large mod configs in metadata-only mode
                try reader.skipBytes(@intCast(match.header.script_size));
                match.mod_config = try self.allocator.dupe(u8, "[skipped - too large]");
            } else {
                const mod_config = try reader.readAsciiString(@intCast(match.header.script_size));
                match.mod_config = mod_config;
            }
        } else {
            match.mod_config = try self.allocator.dupe(u8, "");
        }

        // Early exit for metadata-only mode
        if (mode == .METADATA_ONLY) {
            return match;
        }

        // Parse packets (only for ESSENTIAL_ONLY and FULL modes)
        const packet_count = try self.parsePacketsStreaming(reader, &match, mode);

        print("packets parsed [gameID={s}] [packet count={}]\n", .{ match.header.game_id, packet_count });

        return match;
    }

    fn parsePacketsStreaming(self: *BarDemofileParser, reader: *StreamingByteReader, match: *BarMatch, mode: ParseMode) !i32 {
        var packet_count: i32 = 0;
        var max_frame: i32 = 0;
        var frame_count: i32 = 0;

        // Limit packet parsing based on mode
        const max_packets: usize = switch (mode) {
            .ESSENTIAL_ONLY => 10000, // Only parse first 10k packets
            .FULL => std.math.maxInt(i32),
            else => 0,
        };

        while (packet_count < max_packets) {
            const game_time = reader.readF32LE() catch break;
            const length = reader.readU32LE() catch break;
            const packet_type = reader.readU8() catch break;

            if (length == 0) break;

            const packet_data = reader.readBytes(length - 1) catch break;
            defer self.allocator.free(packet_data);

            packet_count += 1;

            // Only process essential packets in ESSENTIAL_ONLY mode
            const should_process = switch (mode) {
                .ESSENTIAL_ONLY => packet_type == PacketType.CHAT or
                    packet_type == PacketType.GAME_OVER or
                    packet_type == PacketType.TEAM_MSG or
                    packet_type == PacketType.QUIT,
                .FULL => true,
                else => false,
            };

            if (should_process) {
                try self.processPacketStreaming(packet_type, packet_data, game_time, match, &max_frame, &frame_count);
            }

            if (packet_type == PacketType.QUIT) {
                print("found quit packet, breaking [packet count={}]\n", .{packet_count});
                break;
            }
        }

        match.duration_frame_count = max_frame;
        return packet_count;
    }

    fn processPacketStreaming(self: *BarDemofileParser, packet_type: u8, packet_data: []const u8, game_time: f32, match: *BarMatch, max_frame: *i32, frame_count: *i32) !void {
        var packet_reader = StreamingByteReader.init(self.allocator, packet_data, packet_data.len) catch return;
        defer packet_reader.deinit();

        switch (packet_type) {
            PacketType.CHAT => {
                const size = packet_reader.readU8() catch return;
                const from_id = packet_reader.readU8() catch return;
                const to_id = packet_reader.readU8() catch return;
                const message = packet_reader.readUntilNull() catch return;

                const msg = BarMatchChatMessage{
                    .size = size,
                    .from_id = from_id,
                    .to_id = to_id,
                    .message = message,
                    .game_id = try self.allocator.dupe(u8, match.header.game_id),
                    .game_timestamp = game_time,
                };

                try match.chat_messages.append(msg);
            },

            PacketType.KEYFRAME => {
                const frame = packet_reader.readI32LE() catch return;
                max_frame.* = @max(max_frame.*, frame);
            },

            PacketType.NEW_FRAME => {
                frame_count.* += 1;
            },

            PacketType.GAME_OVER => {
                const size = packet_reader.readU8() catch return;
                const player_num = packet_reader.readU8() catch return;
                _ = size;
                _ = player_num;

                // Read winning teams
                while (true) {
                    const team_id = packet_reader.readU8() catch break;
                    try match.winning_ally_teams.append(team_id);
                }
            },

            PacketType.TEAM_MSG => {
                const player_num = packet_reader.readU8() catch return;
                const action = packet_reader.readU8() catch return;
                const param1 = packet_reader.readU8() catch return;

                if (action == 2 or action == 4) { // resigned or team died
                    const team_id = if (action == 2) player_num else param1;

                    const death = BarMatchTeamDeath{
                        .game_id = try self.allocator.dupe(u8, match.header.game_id),
                        .team_id = team_id,
                        .reason = action,
                        .game_time = game_time,
                    };

                    try match.team_deaths.append(death);
                }
            },

            else => {
                // Skip unknown packet types
            },
        }
    }

    fn determineGamemode(self: *BarDemofileParser, match: *BarMatch) BarGamemode {
        _ = self;
        _ = match;
        // Simplified gamemode detection
        return .UNKNOWN;
    }
};

// Usage example
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = BarDemofileParser.init(allocator);
    print("Ultra-Fast BAR Demofile Parser initialized\n", .{});

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        print("Usage: bar_demofile_parser <demofile_path> [mode]\n", .{});
        print("Modes: header, metadata, essential, full (default: header)\n", .{});
        return;
    }

    const file_path = args[1];
    const mode_str = if (args.len > 2) args[2] else "header";

    const mode = if (std.mem.eql(u8, mode_str, "header")) ParseMode.HEADER_ONLY else if (std.mem.eql(u8, mode_str, "metadata")) ParseMode.METADATA_ONLY else if (std.mem.eql(u8, mode_str, "essential")) ParseMode.ESSENTIAL_ONLY else if (std.mem.eql(u8, mode_str, "full")) ParseMode.FULL else ParseMode.HEADER_ONLY;

    const file_data = try std.fs.cwd().readFileAlloc(allocator, file_path, 1024 * 1024 * 500); // 500MB max
    defer allocator.free(file_data);

    print("Parsing demofile: {s} [mode: {}]\n", .{ file_path, mode });

    var total_timer = std.time.Timer.start() catch unreachable;
    const file_name = std.fs.path.basename(file_path);
    var match = try parser.parseWithMode(file_name, file_data, mode);
    defer match.deinit();
    const total_elapsed = total_timer.read() / std.time.ns_per_ms;

    // Print match details
    print("\n=== PARSE RESULTS ===\n", .{});
    print("Total Parse Time: {}ms\n", .{total_elapsed});
    print("Match ID: {s}\n", .{match.header.game_id});
    print("Game Version: {s}\n", .{match.header.game_version});
    print("Start Time: {}\n", .{match.header.start_time});
    print("Duration (ms): {}\n", .{match.header.wall_clock_time * 1000});
    print("Player Count: {}\n", .{match.header.player_count});
    print("Team Count: {}\n", .{match.header.team_count});
    print("Mod Config Length: {}\n", .{match.mod_config.len});

    if (mode != .HEADER_ONLY and mode != .METADATA_ONLY) {
        print("Chat Messages: {}\n", .{match.chat_messages.items.len});
        print("Team Deaths: {}\n", .{match.team_deaths.items.len});
        print("Winning Teams: {}\n", .{match.winning_ally_teams.items.len});
        print("Duration Frames: {}\n", .{match.duration_frame_count});
    }

    print("\nParser completed successfully! [mode: {}]\n", .{mode});

    print("\nMod config:\n", .{});
    if (match.mod_config.len > 0) {
        print("{s}\n", .{match.mod_config});
    } else {
        print("No mod config found.\n", .{});
    }
}
