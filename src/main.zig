const std = @import("std");
const gameconfig_parser = @import("gameconfig_parser.zig");

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
// https://github.com/beyond-all-reason/RecoilEngine/blob/master/rts/Net/Protocol/NetMessageTypes.h
const PacketType = struct {
    const KEYFRAME: u8 = 1;
    const NEW_FRAME: u8 = 2;
    const QUIT: u8 = 3;
    const START_PLAYING: u8 = 4;
    const SET_PLAYER_NUM: u8 = 5;
    const PLAYER_NAME: u8 = 6;
    const CHAT: u8 = 7;
    const RAND_SEED: u8 = 8;
    const GAME_ID: u8 = 9;
    const PATH_CHECKSUM: u8 = 10;
    const COMMAND: u8 = 11;
    const SELECT: u8 = 12;
    const PAUSE: u8 = 13;
    const AI_COMMAND: u8 = 14;
    const AI_COMMANDS: u8 = 15;
    const AI_SHARE: u8 = 16;
    const USER_SPEED: u8 = 19;
    const INTERNAL_SPEED: u8 = 20;
    const CPU_USAGE: u8 = 21;
    const DIRECT_CONTROL: u8 = 22;
    const DC_UPDATE: u8 = 23;
    const SHARE: u8 = 26;
    const SET_SHARE: u8 = 27;
    const PLAYER_STAT: u8 = 29;
    const GAME_OVER: u8 = 30;
    const MAP_DRAW: u8 = 31;
    const SYNC_RESPONSE: u8 = 33;
    const SYSTEM_MSG: u8 = 35;
    const START_POS: u8 = 36;
    const PLAYER_INFO: u8 = 38;
    const PLAYER_LEFT: u8 = 39;
    const SD_CHK_REQUEST: u8 = 41;
    const SD_CHK_RESPONSE: u8 = 42;
    const SD_BLK_REQUEST: u8 = 43;
    const SD_BLK_RESPONSE: u8 = 44;
    const SD_RESET: u8 = 45;
    const LOG_MSG: u8 = 49;
    const LUA_MSG: u8 = 50;
    const TEAM: u8 = 51;
    const GAME_DATA: u8 = 52;
    const ALLIANCE: u8 = 53;
    const C_COMMAND: u8 = 54;
    const TEAM_STAT: u8 = 60;
    const CLIENT_DATA: u8 = 61;
    const ATTEMPT_CONNECT: u8 = 65;
    const REJECT_CONNECT: u8 = 66;
    const AI_CREATED: u8 = 70;
    const AI_STATE_CHANGED: u8 = 71;
    const REQUEST_TEAM_STAT: u8 = 72;
    const CREATE_NEW_PLAYER: u8 = 75;
    const AI_COMMAND_TRACKED: u8 = 76;
    const GAME_FRAME_PROGRESS: u8 = 77;
    const PING: u8 = 78;
};

fn packetTypeToString(packetType: u8) []const u8 {
    return switch (packetType) {
        PacketType.KEYFRAME => "KEYFRAME",
        PacketType.NEW_FRAME => "NEW_FRAME",
        PacketType.QUIT => "QUIT",
        PacketType.START_PLAYING => "START_PLAYING",
        PacketType.SET_PLAYER_NUM => "SET_PLAYER_NUM",
        PacketType.PLAYER_NAME => "PLAYER_NAME",
        PacketType.CHAT => "CHAT",
        PacketType.RAND_SEED => "RAND_SEED",
        PacketType.GAME_ID => "GAME_ID",
        PacketType.PATH_CHECKSUM => "PATH_CHECKSUM",
        PacketType.COMMAND => "COMMAND",
        PacketType.SELECT => "SELECT",
        PacketType.PAUSE => "PAUSE",
        PacketType.AI_COMMAND => "AI_COMMAND",
        PacketType.AI_COMMANDS => "AI_COMMANDS",
        PacketType.AI_SHARE => "AI_SHARE",
        PacketType.USER_SPEED => "USER_SPEED",
        PacketType.INTERNAL_SPEED => "INTERNAL_SPEED",
        PacketType.CPU_USAGE => "CPU_USAGE",
        PacketType.DIRECT_CONTROL => "DIRECT_CONTROL",
        PacketType.DC_UPDATE => "DC_UPDATE",
        PacketType.SHARE => "SHARE",
        PacketType.SET_SHARE => "SET_SHARE",
        PacketType.PLAYER_STAT => "PLAYER_STAT",
        PacketType.GAME_OVER => "GAME_OVER",
        PacketType.MAP_DRAW => "MAP_DRAW",
        PacketType.SYNC_RESPONSE => "SYNC_RESPONSE",
        PacketType.SYSTEM_MSG => "SYSTEM_MSG",
        PacketType.START_POS => "START_POS",
        PacketType.PLAYER_INFO => "PLAYER_INFO",
        PacketType.PLAYER_LEFT => "PLAYER_LEFT",
        PacketType.SD_CHK_REQUEST => "SD_CHK_REQUEST",
        PacketType.SD_CHK_RESPONSE => "SD_CHK_RESPONSE",
        PacketType.SD_BLK_REQUEST => "SD_BLK_REQUEST",
        PacketType.SD_BLK_RESPONSE => "SD_BLK_RESPONSE",
        PacketType.SD_RESET => "SD_RESET",
        PacketType.LOG_MSG => "LOG_MSG",
        PacketType.LUA_MSG => "LUA_MSG",
        PacketType.TEAM => "TEAM",
        PacketType.GAME_DATA => "GAME_DATA",
        PacketType.ALLIANCE => "ALLIANCE",
        PacketType.C_COMMAND => "C_COMMAND",
        PacketType.TEAM_STAT => "TEAM_STAT",
        PacketType.CLIENT_DATA => "CLIENT_DATA",
        PacketType.ATTEMPT_CONNECT => "ATTEMPT_CONNECT",
        PacketType.REJECT_CONNECT => "REJECT_CONNECT",
        PacketType.AI_CREATED => "AI_CREATED",
        PacketType.AI_STATE_CHANGED => "AI_STATE_CHANGED",
        PacketType.REQUEST_TEAM_STAT => "REQUEST_TEAM_STAT",
        PacketType.CREATE_NEW_PLAYER => "CREATE_NEW_PLAYER",
        PacketType.AI_COMMAND_TRACKED => "AI_COMMAND_TRACKED",
        PacketType.GAME_FRAME_PROGRESS => "GAME_FRAME_PROGRESS",
        PacketType.PING => "PING",
        else => "UNKNOWN",
    };
}

// Vector3 equivalent
const Vector3 = struct {
    x: f32,
    y: f32,
    z: f32,
};

const ChatMessage = struct {
    from_id: u8,
    to_id: u8,
    message: []const u8,
    game_timestamp: i32,
};

const TeamDeath = struct {
    team_id: u8,
    reason: u8,
    game_time: i32,
};

// Statistics structures
const PlayerStats = struct {
    player_id: i32,
    command_count: i32,
    unit_commands: i32,
    mouse_pixels: i32,
    mouse_clicks: i32,
    key_presses: i32,
};

const TeamStatsDataPoint = struct {
    team_id: i32,
    frame: i32,
    metal_used: f32,
    energy_used: f32,
    metal_produced: f32,
    energy_produced: f32,
    metal_excess: f32,
    energy_excess: f32,
    metal_received: f32,
    energy_received: f32,
    metal_send: f32,
    energy_send: f32,
    damage_dealt: f32,
    damage_received: f32,
    units_produced: i32,
    units_died: i32,
    units_received: i32,
    units_sent: i32,
    units_captured: i32,
    units_out_captured: i32,
    units_killed: i32,
};

const TeamStats = struct {
    team_id: i32,
    stat_count: i32,
    entries: ArrayList(TeamStatsDataPoint),
    allocator: Allocator,

    pub fn init(allocator: Allocator) TeamStats {
        return TeamStats{
            .team_id = 0,
            .stat_count = 0,
            .entries = ArrayList(TeamStatsDataPoint).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TeamStats) void {
        self.entries.deinit();
    }
};

const Statistics = struct {
    winning_ally_team_ids: ArrayList(u8),
    player_stats: ArrayList(PlayerStats),
    team_stats: ArrayList(TeamStats),
    allocator: Allocator,

    pub fn init(allocator: Allocator) Statistics {
        return Statistics{
            .winning_ally_team_ids = ArrayList(u8).init(allocator),
            .player_stats = ArrayList(PlayerStats).init(allocator),
            .team_stats = ArrayList(TeamStats).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Statistics) void {
        self.winning_ally_team_ids.deinit();
        self.player_stats.deinit();
        for (self.team_stats.items) |*team_stat| {
            team_stat.deinit();
        }
        self.team_stats.deinit();
    }
};

fn escapeJsonString(allocator: Allocator, input: []const u8) ![]u8 {
    var result = ArrayList(u8).init(allocator);
    defer result.deinit();

    for (input) |char| {
        switch (char) {
            '"' => try result.appendSlice("\\\""),
            '\\' => try result.appendSlice("\\\\"),
            '\n' => try result.appendSlice("\\n"),
            '\r' => try result.appendSlice("\\r"),
            '\t' => try result.appendSlice("\\t"),
            '\x08' => try result.appendSlice("\\b"), // backspace
            '\x0C' => try result.appendSlice("\\f"), // form feed
            else => {
                if (char < 32) {
                    // Control characters - escape as \uXXXX
                    try std.fmt.format(result.writer(), "\\u{x:0>4}", .{char});
                } else {
                    try result.append(char);
                }
            },
        }
    }

    return result.toOwnedSlice();
}

// Main match structure
const BarMatch = struct {
    header: Header,
    file_name: []const u8,
    game_config: gameconfig_parser.GameConfig,
    packet_offset: i32 = 0,
    stat_offset: i32 = 0,
    packet_count: i32 = 0,
    packet_parsed: i32 = 0,
    chat_messages: ArrayList(ChatMessage),
    team_deaths: ArrayList(TeamDeath),
    statistics: Statistics,
    allocator: Allocator,

    pub fn init(allocator: Allocator) BarMatch {
        return BarMatch{
            .header = Header.init(),
            .file_name = "",
            .game_config = gameconfig_parser.GameConfig.init(allocator),
            .chat_messages = ArrayList(ChatMessage).init(allocator),
            .team_deaths = ArrayList(TeamDeath).init(allocator),
            .statistics = Statistics.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BarMatch) void {
        if (self.file_name.len > 0) self.allocator.free(self.file_name);
        self.game_config.deinit();
        for (self.chat_messages.items) |msg| {
            if (msg.message.len > 0) self.allocator.free(msg.message);
        }
        self.chat_messages.deinit();
        self.team_deaths.deinit();
        self.statistics.deinit();
    }

    pub fn toJson(self: *const BarMatch, allocator: Allocator) ![]u8 {
        // Pre-calculate approximate size to reduce reallocations
        const estimated_size = 8192 +
            (self.chat_messages.items.len * 256) +
            (self.team_deaths.items.len * 128) +
            (self.statistics.player_stats.items.len * 256) +
            (self.statistics.team_stats.items.len * 1024);

        var json_str = try ArrayList(u8).initCapacity(allocator, estimated_size);
        defer json_str.deinit();

        const writer = json_str.writer();

        // Use format strings for better performance
        try writer.print("{{\"header\":{{", .{});
        try writer.print("\"magic\":\"{s}\",", .{std.mem.sliceTo(&self.header.magic, 0)});
        try writer.print("\"header_version\":{d},", .{self.header.header_version});
        try writer.print("\"header_size\":{d},", .{self.header.header_size});
        try writer.print("\"game_version\":\"{s}\",", .{std.mem.sliceTo(&self.header.game_version, 0)});
        try writer.print("\"game_id\":\"{s}\",", .{std.fmt.fmtSliceHexLower(&self.header.game_id)});
        try writer.print("\"start_time\":{d},", .{self.header.start_time});
        try writer.print("\"script_size\":{d},", .{self.header.script_size});
        try writer.print("\"demo_stream_size\":{d},", .{self.header.demo_stream_size});
        try writer.print("\"game_time\":{d},", .{self.header.game_time});
        try writer.print("\"wall_clock_time\":{d},", .{self.header.wall_clock_time});
        try writer.print("\"player_count\":{d},", .{self.header.player_count});
        try writer.print("\"player_stat_size\":{d},", .{self.header.player_stat_size});
        try writer.print("\"player_stat_elem_size\":{d},", .{self.header.player_stat_elem_size});
        try writer.print("\"team_count\":{d},", .{self.header.team_count});
        try writer.print("\"team_stat_size\":{d},", .{self.header.team_stat_size});
        try writer.print("\"team_stat_elem_size\":{d},", .{self.header.team_stat_elem_size});
        try writer.print("\"team_stat_period\":{d},", .{self.header.team_stat_period});
        try writer.print("\"winning_ally_teams_size\":{d}}},", .{self.header.winning_ally_teams_size});

        try writer.print("\"file_name\":\"{s}\",", .{self.file_name});
        try writer.print("\"packet_offset\":{d},", .{self.packet_offset});
        try writer.print("\"stat_offset\":{d},", .{self.stat_offset});

        // Chat messages - batch writing
        try writer.writeAll("\"chat_messages\":[");
        for (self.chat_messages.items, 0..) |msg, i| {
            if (i > 0) try writer.writeByte(',');

            // Escape message once and reuse
            const escaped_message = try escapeJsonString(allocator, msg.message);
            defer allocator.free(escaped_message);

            try writer.print("{{\"from_id\":{d},\"to_id\":{d},\"message\":\"{s}\",\"game_timestamp\":{d}}}", .{ msg.from_id, msg.to_id, escaped_message, msg.game_timestamp });
        }
        try writer.writeAll("],");

        // Team deaths - batch writing
        try writer.writeAll("\"team_deaths\":[");
        for (self.team_deaths.items, 0..) |death, i| {
            if (i > 0) try writer.writeByte(',');
            try writer.print("{{\"team_id\":{d},\"reason\":{d},\"game_time\":{d:.6}}}", .{ death.team_id, death.reason, death.game_time });
        }
        try writer.writeAll("],");

        // Statistics section - more efficient formatting
        try writer.writeAll("\"statistics\":{");

        // Winning ally teams
        try writer.writeAll("\"winning_ally_team_ids\":[");
        for (self.statistics.winning_ally_team_ids.items, 0..) |team_id, i| {
            if (i > 0) try writer.writeByte(',');
            try writer.print("{d}", .{team_id});
        }
        try writer.writeAll("],");

        // Player stats - batch processing
        try writer.writeAll("\"player_stats\":[");
        for (self.statistics.player_stats.items, 0..) |stat, i| {
            if (i > 0) try writer.writeByte(',');
            try writer.print("{{\"player_id\":{d},\"command_count\":{d},\"unit_commands\":{d},\"mouse_pixels\":{d},\"mouse_clicks\":{d},\"key_presses\":{d}}}", .{ stat.player_id, stat.command_count, stat.unit_commands, stat.mouse_pixels, stat.mouse_clicks, stat.key_presses });
        }
        try writer.writeAll("],");

        // Team stats - most complex section, optimize heavily
        try writer.writeAll("\"team_stats\":[");
        for (self.statistics.team_stats.items, 0..) |team_stat, i| {
            if (i > 0) try writer.writeByte(',');
            try writer.print("{{\"team_id\":{d},\"stat_count\":{d},\"entries\":[", .{ team_stat.team_id, team_stat.stat_count });

            for (team_stat.entries.items, 0..) |entry, j| {
                if (j > 0) try writer.writeByte(',');
                try writer.print("{{\"team_id\":{d},\"frame\":{d},\"metal_used\":{d:.6},\"energy_used\":{d:.6},\"metal_produced\":{d:.6},\"energy_produced\":{d:.6},\"metal_excess\":{d:.6},\"energy_excess\":{d:.6},\"metal_received\":{d:.6},\"energy_received\":{d:.6},\"metal_send\":{d:.6},\"energy_send\":{d:.6},\"damage_dealt\":{d:.6},\"damage_received\":{d:.6},\"units_produced\":{d},\"units_died\":{d},\"units_received\":{d},\"units_sent\":{d},\"units_captured\":{d},\"units_out_captured\":{d},\"units_killed\":{d}}}", .{ entry.team_id, entry.frame, entry.metal_used, entry.energy_used, entry.metal_produced, entry.energy_produced, entry.metal_excess, entry.energy_excess, entry.metal_received, entry.energy_received, entry.metal_send, entry.energy_send, entry.damage_dealt, entry.damage_received, entry.units_produced, entry.units_died, entry.units_received, entry.units_sent, entry.units_captured, entry.units_out_captured, entry.units_killed });
            }
            try writer.writeAll("]}");
        }
        try writer.writeAll("]},");

        // Game config
        try writer.writeAll("\"game_config\":");
        const game_config_json = try self.game_config.toJson(allocator);
        defer allocator.free(game_config_json);
        try writer.writeAll(game_config_json);

        try writer.writeByte('}');
        return json_str.toOwnedSlice();
    }
};

// Header structure
// https://github.com/beyond-all-reason/RecoilEngine/blob/7c505ac918a50ffce413ebcfe9f8ff9e342c8efd/rts/System/LoadSave/demofile.h
const Header = extern struct {
    magic: [16]u8, // DEMOFILE_MAGIC
    header_version: i32, // DEMOFILE_VERSION
    header_size: i32, // Size of the DemoFileHeader, minor version number.
    game_version: [256]u8, // Spring version string
    game_id: [16]u8, // Unique game identifier. Identical for each player of the game.
    start_time: i64, // Unix time when game was started.
    script_size: i32, // Size of startscript.
    demo_stream_size: i32, // Size of the demo stream. (0 if spring has crashed)
    game_time: i32, // Total number of seconds game time.
    wall_clock_time: i32, // Total number of seconds wallclock time.
    player_count: i32, // Number of players for which stats are saved. (this contains also later joined spectators!)
    player_stat_size: i32, // Size of the entire player statistics chunk.
    player_stat_elem_size: i32, // sizeof(CPlayer::Statistics)
    team_count: i32, // Number of teams for which stats are saved.
    team_stat_size: i32, // Size of the entire team statistics chunk.
    team_stat_elem_size: i32, // sizeof(CTeam::Statistics)
    team_stat_period: i32, // Interval (in seconds) between team stats.
    winning_ally_teams_size: i32, // The size of the vector of the winning ally teams

    pub fn init() Header {
        return Header{ .magic = [_]u8{0} ** 16, .header_version = 0, .header_size = 0, .game_version = [_]u8{0} ** 256, .game_id = [_]u8{0} ** 16, .start_time = 0, .script_size = 0, .demo_stream_size = 0, .game_time = 0, .wall_clock_time = 0, .player_count = 0, .player_stat_size = 0, .player_stat_elem_size = 0, .team_count = 0, .team_stat_size = 0, .team_stat_elem_size = 0, .team_stat_period = 0, .winning_ally_teams_size = 0 };
    }
};

// Streaming byte reader for incremental decompression
const StreamingByteReader = struct {
    gzip_stream: std.compress.gzip.Decompressor(std.io.FixedBufferStream([]const u8).Reader),
    buffer: []u8,
    buffer_pos: usize,
    buffer_len: usize,
    reader_pos: usize = 0, // Track position in the decompressed stream
    total_read: usize,
    allocator: Allocator,
    max_size: usize,
    // Add these fields to prevent use-after-free
    compressed_data_copy: []u8, // Keep our own copy
    stream_wrapper: std.io.FixedBufferStream([]const u8),

    pub fn init(allocator: Allocator, compressed_data: []const u8, max_size: usize) !StreamingByteReader {
        // Validate minimum gzip header size
        if (compressed_data.len < 10) {
            return ParseError.InvalidHeader;
        }

        // Validate gzip magic number (0x1f, 0x8b)
        if (compressed_data[0] != 0x1f or compressed_data[1] != 0x8b) {
            return ParseError.InvalidHeader;
        }

        // CRITICAL: Make a copy of the compressed data to ensure it doesn't get freed
        const data_copy = try allocator.dupe(u8, compressed_data);
        errdefer allocator.free(data_copy);

        // Cast to []const u8 to match expected type
        var stream_wrapper = std.io.fixedBufferStream(@as([]const u8, data_copy));

        // Initialize the gzip stream
        const gzip_stream = std.compress.gzip.decompressor(stream_wrapper.reader());

        // Use a reasonable buffer size and ZERO-INITIALIZE it
        const buffer = try allocator.alloc(u8, 4096);
        // Zero out the buffer to prevent uninitialized memory issues
        @memset(buffer, 0);

        return StreamingByteReader{
            .gzip_stream = gzip_stream,
            .buffer = buffer,
            .buffer_pos = 0,
            .buffer_len = 0,
            .total_read = 0,
            .allocator = allocator,
            .max_size = max_size,
            .compressed_data_copy = data_copy,
            .stream_wrapper = stream_wrapper,
        };
    }

    pub fn deinit(self: *StreamingByteReader) void {
        self.allocator.free(self.buffer);
        self.allocator.free(self.compressed_data_copy);
        // Zero out the struct to prevent use-after-free
        self.buffer_pos = 0;
        self.buffer_len = 0;
        self.total_read = 0;
    }

    fn fillBuffer(self: *StreamingByteReader) !void {
        if (self.buffer_pos < self.buffer_len) return; // Buffer still has data

        // Validate buffer state before proceeding
        if (self.buffer_pos > self.buffer.len or self.buffer_len > self.buffer.len) {
            return ParseError.UnexpectedReaderPosition;
        }

        // Reset buffer position
        self.buffer_pos = 0;

        // Zero out buffer before reading to prevent stale data
        @memset(self.buffer, 0);

        // Read into buffer with comprehensive error handling
        const bytes_read = try self.gzip_stream.read(self.buffer);

        // Validate read length
        if (bytes_read > self.buffer.len) {
            return ParseError.UnexpectedReaderPosition;
        }

        self.buffer_len = bytes_read;
        self.total_read += bytes_read;

        // Anti-zip-bomb protection
        if (self.total_read > self.max_size) {
            return ParseError.DecompressionTooLarge;
        }
    }

    pub fn skipBytes(self: *StreamingByteReader, len: u32) !void {
        var remaining = len;
        while (remaining > 0) {
            try self.fillBuffer();
            const to_skip = @min(remaining, self.buffer_len - self.buffer_pos);
            if (to_skip == 0) {
                return ParseError.EndOfStream; // No more data to skip
            }
            self.buffer_pos += to_skip;
            remaining -= to_skip;
        }
    }

    pub fn readU8(self: *StreamingByteReader) !u8 {
        try self.fillBuffer();

        if (self.buffer_len == 0 or self.buffer_pos >= self.buffer_len) {
            return ParseError.EndOfStream;
        }

        // Additional bounds check
        if (self.buffer_pos >= self.buffer.len) {
            return ParseError.UnexpectedReaderPosition;
        }

        const result = self.buffer[self.buffer_pos];
        self.reader_pos += 1;
        self.buffer_pos += 1;
        return result;
    }

    // Rest of the methods...
    pub fn readI32LE(self: *StreamingByteReader) !i32 {
        var bytes: [4]u8 = undefined;
        // Initialize to prevent undefined behavior
        @memset(&bytes, 0);
        for (&bytes) |*byte| {
            byte.* = try self.readU8();
        }
        return std.mem.readInt(i32, &bytes, .little);
    }

    pub fn readU32LE(self: *StreamingByteReader) !u32 {
        var bytes: [4]u8 = undefined;
        @memset(&bytes, 0);
        for (&bytes) |*byte| {
            byte.* = try self.readU8();
        }
        return std.mem.readInt(u32, &bytes, .little);
    }

    pub fn readI64LE(self: *StreamingByteReader) !i64 {
        var bytes: [8]u8 = undefined;
        @memset(&bytes, 0);
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
        if (len > self.max_size) {
            return ParseError.DecompressionTooLarge;
        }

        const result = try self.allocator.alloc(u8, len);
        errdefer self.allocator.free(result);

        // Initialize the result buffer
        @memset(result, 0);

        for (result) |*byte| {
            byte.* = try self.readU8();
        }
        return result;
    }

    pub fn readStringIntoBuffer(self: *StreamingByteReader, buffer: []u8) !usize {
        // Initialize buffer to prevent undefined behavior
        @memset(buffer, 0);

        var len: usize = 0;
        for (buffer) |*byte| {
            const b = try self.readU8();
            if (b == 0) break;
            byte.* = b;
            len += 1;
        }
        return len;
    }

    pub fn readMultipleU8(self: *StreamingByteReader, dest: []u8) !void {
        if (dest.len > self.max_size) {
            return ParseError.DecompressionTooLarge;
        }

        @memset(dest, 0); // Initialize destination

        for (dest) |*byte| {
            byte.* = try self.readU8();
        }
    }

    pub fn readMultipleI32LE(self: *StreamingByteReader, dest: []i32) !void {
        if (dest.len > self.max_size / 4) {
            return ParseError.DecompressionTooLarge;
        }

        // Initialize destination
        for (dest) |*val| {
            val.* = 0;
        }

        for (dest) |*val| {
            val.* = try self.readI32LE();
        }
    }

    pub fn readMultipleF32LE(self: *StreamingByteReader, dest: []f32) !void {
        if (dest.len > self.max_size / 4) {
            return ParseError.DecompressionTooLarge;
        }

        // Initialize destination
        for (dest) |*val| {
            val.* = 0.0;
        }

        for (dest) |*val| {
            val.* = try self.readF32LE();
        }
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
        const max_size: usize = 200 * 1024 * 1024; // 200MB max
        var reader = try StreamingByteReader.init(self.allocator, demofile, max_size);
        defer reader.deinit();
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

    // Packet types (NETMSG from NetMessageTypes.h)
    // https://github.com/beyond-all-reason/RecoilEngine/blob/master/rts/Net/Protocol/NetMessageTypes.h
    const NETMSG = struct {
        const KEYFRAME: u8 = 1;
        const NEWFRAME: u8 = 2;
        const QUIT: u8 = 3;
        const STARTPLAYING: u8 = 4;
        const SETPLAYERNUM: u8 = 5;
        const PLAYERNAME: u8 = 6;
        const CHAT: u8 = 7;
        const RANDSEED: u8 = 8;
        const GAMEID: u8 = 9;
        const PATH_CHECKSUM: u8 = 10;
        const COMMAND: u8 = 11;
        const SELECT: u8 = 12;
        const PAUSE: u8 = 13;
        const AICOMMAND: u8 = 14;
        const AICOMMANDS: u8 = 15;
        const AISHARE: u8 = 16;
        const USER_SPEED: u8 = 19;
        const INTERNAL_SPEED: u8 = 20;
        const CPU_USAGE: u8 = 21;
        const DIRECT_CONTROL: u8 = 22;
        const DC_UPDATE: u8 = 23;
        const SHARE: u8 = 26;
        const SETSHARE: u8 = 27;
        const PLAYERSTAT: u8 = 29;
        const GAMEOVER: u8 = 30;
        const MAPDRAW_OLD: u8 = 31;
        const MAPDRAW: u8 = 32;
        const SYNCRESPONSE: u8 = 33;
        const SYSTEMMSG: u8 = 35;
        const STARTPOS: u8 = 36;
        const PLAYERINFO: u8 = 38;
        const PLAYERLEFT: u8 = 39;
        const SD_CHKREQUEST: u8 = 41;
        const SD_CHKRESPONSE: u8 = 42;
        const SD_BLKREQUEST: u8 = 43;
        const SD_BLKRESPONSE: u8 = 44;
        const SD_RESET: u8 = 45;
        const GAMESTATE_DUMP: u8 = 46;
        const LOGMSG: u8 = 49;
        const LUAMSG: u8 = 50;
        const TEAM: u8 = 51;
        const GAMEDATA: u8 = 52;
        const ALLIANCE: u8 = 53;
        const CCOMMAND: u8 = 54;
        const TEAMSTAT: u8 = 60;
        const CLIENTDATA: u8 = 61;
        const ATTEMPTCONNECT: u8 = 65;
        const REJECTCONNECT: u8 = 66;
        const AI_CREATED: u8 = 70;
        const AI_STATE_CHANGED: u8 = 71;
        const REQUEST_TEAMSTAT: u8 = 72;
        const CREATE_NEWPLAYER: u8 = 75;
        const AICOMMAND_TRACKED: u8 = 76;
        const GAME_FRAME_PROGRESS: u8 = 77;
        const PING: u8 = 78;
    };

    fn netmsgToString(netmsg: u8) []const u8 {
        return switch (netmsg) {
            NETMSG.KEYFRAME => "NETMSG_KEYFRAME",
            NETMSG.NEWFRAME => "NETMSG_NEWFRAME",
            NETMSG.QUIT => "NETMSG_QUIT",
            NETMSG.STARTPLAYING => "NETMSG_STARTPLAYING",
            NETMSG.SETPLAYERNUM => "NETMSG_SETPLAYERNUM",
            NETMSG.PLAYERNAME => "NETMSG_PLAYERNAME",
            NETMSG.CHAT => "NETMSG_CHAT",
            NETMSG.RANDSEED => "NETMSG_RANDSEED",
            NETMSG.GAMEID => "NETMSG_GAMEID",
            NETMSG.PATH_CHECKSUM => "NETMSG_PATH_CHECKSUM",
            NETMSG.COMMAND => "NETMSG_COMMAND",
            NETMSG.SELECT => "NETMSG_SELECT",
            NETMSG.PAUSE => "NETMSG_PAUSE",
            NETMSG.AICOMMAND => "NETMSG_AICOMMAND",
            NETMSG.AICOMMANDS => "NETMSG_AICOMMANDS",
            NETMSG.AISHARE => "NETMSG_AISHARE",
            NETMSG.USER_SPEED => "NETMSG_USER_SPEED",
            NETMSG.INTERNAL_SPEED => "NETMSG_INTERNAL_SPEED",
            NETMSG.CPU_USAGE => "NETMSG_CPU_USAGE",
            NETMSG.DIRECT_CONTROL => "NETMSG_DIRECT_CONTROL",
            NETMSG.DC_UPDATE => "NETMSG_DC_UPDATE",
            NETMSG.SHARE => "NETMSG_SHARE",
            NETMSG.SETSHARE => "NETMSG_SETSHARE",
            NETMSG.PLAYERSTAT => "NETMSG_PLAYERSTAT",
            NETMSG.GAMEOVER => "NETMSG_GAMEOVER",
            NETMSG.MAPDRAW_OLD => "NETMSG_MAPDRAW_OLD",
            NETMSG.MAPDRAW => "NETMSG_MAPDRAW",
            NETMSG.SYNCRESPONSE => "NETMSG_SYNCRESPONSE",
            NETMSG.SYSTEMMSG => "NETMSG_SYSTEMMSG",
            NETMSG.STARTPOS => "NETMSG_STARTPOS",
            NETMSG.PLAYERINFO => "NETMSG_PLAYERINFO",
            NETMSG.PLAYERLEFT => "NETMSG_PLAYERLEFT",
            NETMSG.SD_CHKREQUEST => "NETMSG_SD_CHKREQUEST",
            NETMSG.SD_CHKRESPONSE => "NETMSG_SD_CHKRESPONSE",
            NETMSG.SD_BLKREQUEST => "NETMSG_SD_BLKREQUEST",
            NETMSG.SD_BLKRESPONSE => "NETMSG_SD_BLKRESPONSE",
            NETMSG.SD_RESET => "NETMSG_SD_RESET",
            NETMSG.GAMESTATE_DUMP => "NETMSG_GAMESTATE_DUMP",
            NETMSG.LOGMSG => "NETMSG_LOGMSG",
            NETMSG.LUAMSG => "NETMSG_LUAMSG",
            NETMSG.TEAM => "NETMSG_TEAM",
            NETMSG.GAMEDATA => "NETMSG_GAMEDATA",
            NETMSG.ALLIANCE => "NETMSG_ALLIANCE",
            NETMSG.CCOMMAND => "NETMSG_CCOMMAND",
            NETMSG.TEAMSTAT => "NETMSG_TEAMSTAT",
            NETMSG.CLIENTDATA => "NETMSG_CLIENTDATA",
            NETMSG.ATTEMPTCONNECT => "NETMSG_ATTEMPTCONNECT",
            NETMSG.REJECTCONNECT => "NETMSG_REJECTCONNECT",
            NETMSG.AI_CREATED => "NETMSG_AI_CREATED",
            NETMSG.AI_STATE_CHANGED => "NETMSG_AI_STATE_CHANGED",
            NETMSG.REQUEST_TEAMSTAT => "NETMSG_REQUEST_TEAMSTAT",
            NETMSG.CREATE_NEWPLAYER => "NETMSG_CREATE_NEWPLAYER",
            NETMSG.AICOMMAND_TRACKED => "NETMSG_AICOMMAND_TRACKED",
            NETMSG.GAME_FRAME_PROGRESS => "NETMSG_GAME_FRAME_PROGRESS",
            NETMSG.PING => "NETMSG_PING",
            else => "UNKNOWN",
        };
    }

    fn readBytesStreaming(self: *BarDemofileParser, filename: []const u8, reader: *StreamingByteReader, mode: ParseMode) !BarMatch {
        var match = BarMatch.init(self.allocator);
        errdefer match.deinit();

        // Copy filename
        match.file_name = try self.allocator.dupe(u8, filename);

        // Read header
        match.header = try reader.gzip_stream.reader().readStructEndian(Header, .little);

        // Validate header
        if (!std.mem.eql(u8, &match.header.magic, "spring demofile\x00")) {
            return ParseError.InvalidHeader;
        }

        // Calculate offsets (these are calculated based on the header information)
        match.packet_offset = @sizeOf(Header) + match.header.script_size;
        match.stat_offset = match.packet_offset + match.header.demo_stream_size;

        // Early exit for header-only mode
        if (mode == .HEADER_ONLY) {
            match.game_config = gameconfig_parser.GameConfig.init(self.allocator);
            return match;
        }

        // Read script if present
        if (match.header.script_size > 0) {
            const script = try reader.readBytes(@intCast(match.header.script_size));
            defer self.allocator.free(script);
            match.game_config = try gameconfig_parser.parseScript(self.allocator, script);
        } else {
            match.game_config = gameconfig_parser.GameConfig.init(self.allocator);
        }

        // Check reader if we are at the expected position
        if (reader.reader_pos != match.packet_offset) {
            return ParseError.UnexpectedReaderPosition;
        }

        // Parse packets or skip demo stream data
        if (mode == .ESSENTIAL_ONLY or mode == .FULL) {
            parsePacketsStreaming(reader, &match, mode) catch |err| {
                print("Warning: packet parsing failed: {}\n", .{err});
                print("[reader position={}] [packet count={}] [packet parsed={}]\n", .{ reader.reader_pos, match.packet_count, match.packet_parsed });
                return match; // Return what we have so far
            };
            print("packets parsed [gameID={s}] [packet count={}] [packet parsed={}]\n", .{ match.header.game_id, match.packet_count, match.packet_parsed });
        } else {
            try reader.skipBytes(@as(u32, @intCast(match.header.demo_stream_size)));
            print("skipped demo stream data [gameID={s}]\n", .{match.header.game_id});
        }

        // Check reader position after packets
        if (reader.reader_pos != match.stat_offset) {
            return ParseError.UnexpectedReaderPosition;
        }

        // Parse statistics
        parseStatisticsStreaming(reader, &match) catch |err| {
            print("Warning: statistics parsing failed: {}\n", .{err});
            return match; // Return what we have so far
        };
        print("statistics parsed [gameID={s}]\n", .{match.header.game_id});

        return match;
    }

    fn parsePacketsStreaming(reader: *StreamingByteReader, match: *BarMatch, mode: ParseMode) !void {
        var packetBytesRead: usize = 0;
        while (true) {
            // Check if we are finished reading the demo stream
            if (reader.reader_pos >= match.stat_offset) {
                print("Reached end of demo stream [packet bytes read={}]\n", .{packetBytesRead});
                break;
            }

            // Read game time as i32
            const game_time = try reader.readI32LE();

            // Read packet length as u32
            const length = try reader.readU32LE();

            // Read packet type
            const packet_type = try reader.readU8();

            match.packet_count += 1;
            packetBytesRead += length;

            if (match.packet_count >= 895936) {
                print("packet [game_time={}] [length={}] [type={s}]\n", .{ game_time, length, netmsgToString(packet_type) });
            }

            // If length is 0 or just the packet type byte, skip
            if (length <= 1) {
                continue;
            }

            // Only process essential packets in ESSENTIAL_ONLY mode
            const should_process = switch (mode) {
                .ESSENTIAL_ONLY =>
                // packet_type == NETMSG.CHAT or
                packet_type == NETMSG.GAMEOVER or
                    packet_type == NETMSG.QUIT,
                .FULL => true,
                else => false,
            };

            if (should_process) {
                // print("packet [game_time={}] [length={}] [type={s}]\n", .{ game_time, length, netmsgToString(packet_type) });
                processPacketStreaming(game_time, length, packet_type, reader, match) catch |err| {
                    print("Error with packet [game_time={}] [length={}] [type={s}]\n", .{ game_time, length, netmsgToString(packet_type) });
                    print("Error processing packet: {}\n", .{err});
                    return err; // Stop on error
                };
                match.packet_parsed += 1;
            } else {
                // Skip packet data if not processing (length - 1 because we already read the packet type)
                if (length > 1) {
                    try reader.skipBytes(length - 1);
                }
            }

            // if (packet_type == NETMSG.QUIT) {
            //     print("found quit packet, breaking [packet count={}]\n", .{match.packet_count});
            //     break;
            // }
        }
    }

    fn parseStatisticsStreaming(reader: *StreamingByteReader, match: *BarMatch) !void {
        // Read winning ally teams - batch read
        if (match.header.winning_ally_teams_size > 0) {
            const team_ids = try match.allocator.alloc(u8, @intCast(match.header.winning_ally_teams_size));
            defer match.allocator.free(team_ids);

            try reader.readMultipleU8(team_ids);
            try match.statistics.winning_ally_team_ids.appendSlice(team_ids);
        }

        // Read player statistics - batch read the raw data
        if (match.header.player_count > 0) {
            try match.statistics.player_stats.ensureTotalCapacity(@intCast(match.header.player_count));

            for (0..@intCast(match.header.player_count)) |i| {
                // Read all 5 i32 values at once into a buffer
                var stats_data: [5]i32 = undefined;
                try reader.readMultipleI32LE(&stats_data);

                const player_stat = PlayerStats{
                    .player_id = @intCast(i),
                    .command_count = stats_data[0],
                    .unit_commands = stats_data[1],
                    .mouse_pixels = stats_data[2],
                    .mouse_clicks = stats_data[3],
                    .key_presses = stats_data[4],
                };
                match.statistics.player_stats.appendAssumeCapacity(player_stat);
            }
        }

        // Read team statistics - optimize for batch reading
        if (match.header.team_count > 0) {
            try match.statistics.team_stats.ensureTotalCapacity(@intCast(match.header.team_count));

            // First pass: read stat counts
            const stat_counts = try match.allocator.alloc(i32, @intCast(match.header.team_count));
            defer match.allocator.free(stat_counts);

            try reader.readMultipleI32LE(stat_counts);

            // Initialize team stats with known capacities
            for (0..@intCast(match.header.team_count)) |i| {
                var team_stat = TeamStats.init(match.allocator);
                team_stat.team_id = @intCast(i);
                team_stat.stat_count = stat_counts[i];

                // Add sanity check for stat count
                if (stat_counts[i] < 0 or stat_counts[i] > 100000) {
                    print("Warning: Invalid stat count {} for team {}, skipping\n", .{ stat_counts[i], i });
                    match.statistics.team_stats.appendAssumeCapacity(team_stat);
                    continue;
                }

                try team_stat.entries.ensureTotalCapacity(@intCast(stat_counts[i]));
                match.statistics.team_stats.appendAssumeCapacity(team_stat);
            }

            // Second pass: read actual frame statistics in batches
            for (match.statistics.team_stats.items) |*team_stat| {
                const entry_count = @as(usize, @intCast(team_stat.stat_count));

                for (0..entry_count) |_| {
                    // Read all 20 values for this entry at once
                    var frame_data: [20]f32 = undefined;

                    // Read frame (i32) and convert to f32 for batch processing
                    const frame = try reader.readI32LE();

                    // Read all float values at once
                    try reader.readMultipleF32LE(frame_data[0..19]);

                    // Read integer values
                    var int_data: [7]i32 = undefined;
                    try reader.readMultipleI32LE(&int_data);

                    const frame_stat = TeamStatsDataPoint{
                        .team_id = team_stat.team_id,
                        .frame = frame,
                        .metal_used = frame_data[0],
                        .energy_used = frame_data[1],
                        .metal_produced = frame_data[2],
                        .energy_produced = frame_data[3],
                        .metal_excess = frame_data[4],
                        .energy_excess = frame_data[5],
                        .metal_received = frame_data[6],
                        .energy_received = frame_data[7],
                        .metal_send = frame_data[8],
                        .energy_send = frame_data[9],
                        .damage_dealt = frame_data[10],
                        .damage_received = frame_data[11],
                        .units_produced = int_data[0],
                        .units_died = int_data[1],
                        .units_received = int_data[2],
                        .units_sent = int_data[3],
                        .units_captured = int_data[4],
                        .units_out_captured = int_data[5],
                        .units_killed = int_data[6],
                    };
                    team_stat.entries.appendAssumeCapacity(frame_stat);
                }
            }
        }
    }

    fn processPacketStreaming(game_time: i32, length: u32, packet_type: u8, reader: *StreamingByteReader, match: *BarMatch) !void {
        // Calculate remaining bytes to read (subtract 1 for the packet type we already read)
        const remaining_bytes = if (length > 1) length - 1 else 0;

        switch (packet_type) {
            NETMSG.CHAT => {
                // NETMSG_CHAT has format: uint8_t messageSize; uint8_t from, dest; std::string message;
                // The messageSize is redundant (same as packet length), so we ignore it
                if (remaining_bytes < 3) {
                    try reader.skipBytes(remaining_bytes);
                    return;
                }
                try reader.skipBytes(1); // Skip message size byte
                const from_id = try reader.readU8();
                const to_id = try reader.readU8();
                // The actual message length is remaining_bytes - 3 (for the 3 bytes we just read)
                const message_len = remaining_bytes - 3;
                const message = if (message_len > 0) blk: {
                    const message_bytes = try reader.readBytes(message_len);
                    // Find null terminator
                    var actual_len: usize = 0;
                    for (message_bytes) |byte| {
                        if (byte == 0) break;
                        actual_len += 1;
                    }
                    // Create properly sized message
                    const result = try match.allocator.alloc(u8, actual_len);
                    @memcpy(result, message_bytes[0..actual_len]);
                    match.allocator.free(message_bytes);
                    break :blk result;
                } else try match.allocator.alloc(u8, 0);
                const msg = ChatMessage{
                    .from_id = from_id,
                    .to_id = to_id,
                    .message = message,
                    .game_timestamp = game_time,
                };
                try match.chat_messages.append(msg);
            },

            NETMSG.TEAM => {
                // NETMSG_TEAM: uint8_t playerNum; uint8_t action; uint8_t param1;
                if (remaining_bytes >= 3) {
                    const player_num = try reader.readU8();
                    const action = try reader.readU8();
                    const param1 = try reader.readU8();

                    if (action == 2) { // 2 = resigned
                        const death = TeamDeath{
                            .team_id = player_num,
                            .reason = action,
                            .game_time = game_time,
                        };
                        try match.team_deaths.append(death);
                    } else if (action == 4) { // 4 = TEAM_DIED, param1 = team that died
                        const death = TeamDeath{
                            .team_id = param1,
                            .reason = action,
                            .game_time = game_time,
                        };
                        try match.team_deaths.append(death);
                    }

                    // Skip any remaining bytes
                    if (remaining_bytes > 3) {
                        try reader.skipBytes(remaining_bytes - 3);
                    }
                } else {
                    try reader.skipBytes(remaining_bytes);
                }
            },

            else => {
                // Skip unknown packet types
                if (remaining_bytes > 0) {
                    try reader.skipBytes(remaining_bytes);
                }
            },
        }
    }
};

pub fn parseDemofile(allocator: Allocator, filename: []const u8, demofile: []const u8) !BarMatch {
    var parser = BarDemofileParser.init(allocator);
    return parser.parse(filename, demofile);
}

pub fn main() !void {
    var total_timer = std.time.Timer.start() catch unreachable;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = BarDemofileParser.init(allocator);

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

    const file_name = std.fs.path.basename(file_path);
    var match = try parser.parseWithMode(file_name, file_data, mode);
    defer match.deinit();

    // Convert to JSON and print
    const json = try match.toJson(allocator);
    defer allocator.free(json);

    // Total time taken
    print("Total time taken: {}ms\n", .{total_timer.read() / std.time.ns_per_ms});

    // stdout json
    // const stdout = std.io.getStdOut().writer();
    // try stdout.writeAll(json);
}

// WASM handles

// Global variables to store the result (use a simple approach)
var global_json_result: [1024 * 1024]u8 = undefined; // 1MB buffer
var global_json_length: u32 = 0;
var global_error_message: [1024]u8 = undefined;
var global_error_length: usize = 0;

// Simple exported function that takes a file path and returns length of JSON (0 if error)
export fn parse_demo_file(file_path_ptr: [*]const u8, file_path_len: u32, mode: u8) u32 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Reset global state
    global_json_length = 0;
    global_error_length = 0;

    // Convert C string to Zig slice
    const file_path = file_path_ptr[0..file_path_len];

    // Convert mode number to ParseMode
    const parse_mode = switch (mode) {
        0 => ParseMode.HEADER_ONLY,
        1 => ParseMode.METADATA_ONLY,
        2 => ParseMode.ESSENTIAL_ONLY,
        3 => ParseMode.FULL,
        else => ParseMode.METADATA_ONLY,
    };

    // Parse the demo file
    const result = parseDemoFileInternal(allocator, file_path, parse_mode);

    if (result) |json| {
        defer allocator.free(json);

        // Copy to global buffer
        if (json.len <= global_json_result.len) {
            @memcpy(global_json_result[0..json.len], json);
            global_json_length = @intCast(json.len);
            return global_json_length;
        } else {
            // JSON too large
            const error_msg = "JSON result too large for buffer";
            @memcpy(global_error_message[0..error_msg.len], error_msg);
            global_error_length = error_msg.len;
            return 0;
        }
    } else |err| {
        // Store error message
        const error_msg = switch (err) {
            error.FileNotFound => "File not found",
            error.AccessDenied => "Access denied",
            error.OutOfMemory => "Out of memory",
            error.InvalidMagic => "Invalid demo file format",
            error.InvalidGameId => "Invalid game ID",
            error.DecompressionTooLarge => "Decompression too large",
            else => "Unknown error",
        };

        @memcpy(global_error_message[0..error_msg.len], error_msg);
        global_error_length = error_msg.len;
        return 0;
    }
}

// Get the JSON result buffer pointer
export fn get_json_buffer() [*]u8 {
    return &global_json_result;
}

// Get the error message buffer pointer
export fn get_error_buffer() [*]u8 {
    return &global_error_message;
}

// Get error message length
export fn get_error_length() usize {
    return global_error_length;
}

// Internal parsing function (same as before)
fn parseDemoFileInternal(allocator: Allocator, file_name: []const u8, mode: ParseMode) ![]u8 {
    // Read the file
    const file_data = std.fs.cwd().readFileAlloc(allocator, file_name, 1024 * 1024 * 500) catch |err| {
        return err;
    };
    defer allocator.free(file_data);

    // Parse the demo file
    var parser = BarDemofileParser.init(allocator);
    var match = parser.parseWithMode(file_name, file_data, mode) catch |err| {
        return err;
    };
    defer match.deinit();

    // Convert to JSON
    const json = match.toJson(allocator) catch |err| {
        return err;
    };

    return json;
}
