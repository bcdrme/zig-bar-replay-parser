const std = @import("std");
const gameconfig_parser = @import("gameconfig_parser.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const ParseError = error{
    InvalidHeader,
    OutOfMemory,
    EndOfStream,
};

const PacketType = struct {
    const START_POS: u8 = 36;
    const CHAT: u8 = 7;
};

const Vector3 = struct { x: f32, y: f32, z: f32 };

const ChatMessage = struct {
    from_id: u8,
    to_id: u8,
    message: []const u8,
    game_timestamp: i32,
};

const PlayerStats = extern struct {
    mouse_pixels: i32,
    mouse_clicks: i32,
    key_presses: i32,
};

const TeamStatsDataPoint = extern struct {
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
    entries: []TeamStatsDataPoint,
};

const Statistics = struct {
    winning_ally_team_ids: []u8,
    player_stats: []PlayerStats,
    team_stats: []TeamStats,
};

pub const Header = extern struct {
    magic: [16]u8,
    header_version: i32,
    header_size: i32,
    game_version: [256]u8,
    game_id: [16]u8,
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

    fn init() Header {
        return std.mem.zeroes(Header);
    }
};

pub const ParseMode = enum {
    header_only,
    metadata_only,
    essential_only,
    full,
};

pub const BarMatch = struct {
    header: Header,
    game_config: gameconfig_parser.GameConfig,
    packet_offset: i32 = 0,
    stat_offset: i32 = 0,
    packet_count: i32 = 0,
    chat_messages: ArrayList(ChatMessage),
    statistics: Statistics,
    allocator: Allocator,

    pub fn init(allocator: Allocator) BarMatch {
        return BarMatch{
            .header = Header.init(),
            .game_config = gameconfig_parser.GameConfig.init(allocator),
            .chat_messages = ArrayList(ChatMessage).init(allocator),
            .statistics = Statistics{
                .winning_ally_team_ids = &[_]u8{},
                .player_stats = &[_]PlayerStats{},
                .team_stats = &[_]TeamStats{},
            },
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BarMatch) void {
        // GameConfig uses an arena allocator that will free all its allocations
        // when deinit() is called, so we don't need to free individual arrays
        self.game_config.deinit();

        for (self.chat_messages.items) |msg| {
            self.allocator.free(msg.message);
        }
        self.chat_messages.deinit();
        if (self.statistics.winning_ally_team_ids.len > 0) {
            self.allocator.free(self.statistics.winning_ally_team_ids);
        }
        if (self.statistics.player_stats.len > 0) {
            self.allocator.free(self.statistics.player_stats);
        }
        for (self.statistics.team_stats) |team| {
            if (team.entries.len > 0) {
                self.allocator.free(team.entries);
            }
        }
        if (self.statistics.team_stats.len > 0) {
            self.allocator.free(self.statistics.team_stats);
        }
    }

    pub fn toJson(self: *const BarMatch, allocator: Allocator) ![]u8 {
        var json = ArrayList(u8).init(allocator);
        const writer = json.writer();

        try writer.writeAll("{\"header\":{");
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

        try writer.print("\"packet_offset\":{d},\"stat_offset\":{d},", .{ self.packet_offset, self.stat_offset });

        try writer.writeAll("\"chat_messages\":[");
        for (self.chat_messages.items, 0..) |msg, i| {
            if (i > 0) try writer.writeByte(',');
            try writer.print("{{\"from_id\":{d},\"to_id\":{d},\"message\":\"{s}\",\"game_timestamp\":{d}}}", .{ msg.from_id, msg.to_id, msg.message, msg.game_timestamp });
        }
        try writer.writeAll("],");

        try writer.writeAll("\"statistics\":{\"winning_ally_team_ids\":[");
        for (self.statistics.winning_ally_team_ids, 0..) |team_id, i| {
            if (i > 0) try writer.writeByte(',');
            try writer.print("{d}", .{team_id});
        }
        try writer.writeAll("],\"player_stats\":[");
        for (self.statistics.player_stats, 0..) |stat, i| {
            if (i > 0) try writer.writeByte(',');
            try writer.print("{{\"player_id\":{d},\"mouse_pixels\":{d},\"mouse_clicks\":{d},\"key_presses\":{d}}}", .{ i, stat.mouse_pixels, stat.mouse_clicks, stat.key_presses });
        }
        try writer.writeAll("],\"team_stats\":[");
        for (self.statistics.team_stats, 0..) |team_stat, i| {
            if (i > 0) try writer.writeByte(',');
            try writer.print("{{\"team_id\":{d},\"stat_count\":{d},\"entries\":[", .{ team_stat.team_id, team_stat.stat_count });
            for (team_stat.entries, 0..) |entry, j| {
                if (j > 0) try writer.writeByte(',');
                try writer.print("{{\"team_id\":{d},\"frame\":{d},\"metal_used\":{d:.6},\"energy_used\":{d:.6},\"metal_produced\":{d:.6},\"energy_produced\":{d:.6},\"metal_excess\":{d:.6},\"energy_excess\":{d:.6},\"metal_received\":{d:.6},\"energy_received\":{d:.6},\"metal_send\":{d:.6},\"energy_send\":{d:.6},\"damage_dealt\":{d:.6},\"damage_received\":{d:.6},\"units_produced\":{d},\"units_died\":{d},\"units_received\":{d},\"units_sent\":{d},\"units_captured\":{d},\"units_out_captured\":{d},\"units_killed\":{d}}}", .{ entry.team_id, entry.frame, entry.metal_used, entry.energy_used, entry.metal_produced, entry.energy_produced, entry.metal_excess, entry.energy_excess, entry.metal_received, entry.energy_received, entry.metal_send, entry.energy_send, entry.damage_dealt, entry.damage_received, entry.units_produced, entry.units_died, entry.units_received, entry.units_sent, entry.units_captured, entry.units_out_captured, entry.units_killed });
            }
            try writer.writeAll("]}");
        }
        try writer.writeAll("]},");

        try writer.writeAll("\"game_config\":");
        const game_config_json = try self.game_config.toJson(allocator);
        defer allocator.free(game_config_json);
        try writer.writeAll(game_config_json);
        try writer.writeByte('}');

        return json.toOwnedSlice();
    }
};

pub const BarDemofileParser = struct {
    reader: std.io.AnyReader,
    mode: ParseMode,
    allocator: Allocator,

    pub fn init(allocator: Allocator, mode: ParseMode, reader: std.io.AnyReader) BarDemofileParser {
        return BarDemofileParser{
            .reader = reader,
            .mode = mode,
            .allocator = allocator,
        };
    }

    pub fn parse(self: *BarDemofileParser) !BarMatch {
        var match = BarMatch.init(self.allocator);
        errdefer match.deinit();

        match.header = try self.reader.readStruct(Header);

        if (!std.mem.eql(u8, &match.header.magic, "spring demofile\x00")) {
            return ParseError.InvalidHeader;
        }

        match.packet_offset = @sizeOf(Header) + match.header.script_size;
        match.stat_offset = match.packet_offset + match.header.demo_stream_size;

        if (self.mode == .header_only) return match;

        if (match.header.script_size > 0) {
            const script = try self.allocator.alloc(u8, @intCast(match.header.script_size));
            defer self.allocator.free(script);
            _ = try self.reader.readAll(script);
            match.game_config = try gameconfig_parser.parseScript(self.allocator, script);
        }

        if (self.mode == .metadata_only) return match;

        if (self.mode == .essential_only) {
            try self.reader.skipBytes(@intCast(match.header.demo_stream_size), .{});
            try self.parseStatistics(&match);
            return match;
        }

        try self.parsePacketsStreaming(&match);
        try self.parseStatistics(&match);

        return match;
    }

    const StartPos = extern struct {
        playerId: u8,
        teamId: u8,
        ready: u8,
        position: [3]f64,
    };

    fn parsePacketsStreaming(self: *BarDemofileParser, match: *BarMatch) !void {
        var bytes_read: u32 = 0;
        const total_size: u32 = @intCast(match.header.demo_stream_size);

        while (bytes_read < total_size) {
            const game_time = self.reader.readInt(i32, .little) catch break;
            bytes_read += 4;

            const length = try self.reader.readInt(u32, .little);
            bytes_read += 4;

            if (bytes_read + length > total_size) break;

            const packet_type = try self.reader.readByte();
            bytes_read += 1;

            switch (packet_type) {
                PacketType.START_POS => {
                    const pos = try self.reader.readStruct(StartPos);
                    if (pos.playerId < match.game_config.players.items.len) {
                        // Use the GameConfig's arena allocator for consistency
                        const startpos = try match.game_config.string_pool().alloc(f64, 3);
                        startpos[0] = pos.position[0];
                        startpos[1] = pos.position[1];
                        startpos[2] = pos.position[2];
                        match.game_config.players.items[pos.playerId].startpos = startpos;
                    }
                    bytes_read += @sizeOf(StartPos);
                },
                PacketType.CHAT => {
                    const from = try self.reader.readByte();
                    const to = try self.reader.readByte();
                    const msg_len = length - 3;
                    const msg = try self.allocator.alloc(u8, msg_len);
                    _ = try self.reader.readAll(msg);
                    try match.chat_messages.append(.{
                        .from_id = from,
                        .to_id = to,
                        .message = msg,
                        .game_timestamp = game_time,
                    });
                    bytes_read += length - 1;
                },
                else => {
                    try self.reader.skipBytes(length - 1, .{});
                    bytes_read += length - 1;
                },
            }
            match.packet_count += 1;
        }
    }

    fn parseStatistics(self: *BarDemofileParser, match: *BarMatch) !void {
        if (match.header.winning_ally_teams_size > 0) {
            const teams = try self.allocator.alloc(u8, @intCast(match.header.winning_ally_teams_size));
            _ = try self.reader.readAll(teams);
            match.statistics.winning_ally_team_ids = teams;
        }

        if (match.header.player_count > 0) {
            const stats = try self.allocator.alloc(PlayerStats, @intCast(match.header.player_count));
            const bytes = std.mem.sliceAsBytes(stats);
            _ = try self.reader.readAll(bytes);
            match.statistics.player_stats = stats;
        }

        if (match.header.team_count > 0) {
            const team_count: usize = @intCast(match.header.team_count);
            const teams = try self.allocator.alloc(TeamStats, team_count);

            const stat_counts = try self.allocator.alloc(i32, team_count);
            defer self.allocator.free(stat_counts);

            const counts_bytes = std.mem.sliceAsBytes(stat_counts);
            _ = try self.reader.readAll(counts_bytes);

            for (teams, 0..) |*team, i| {
                team.team_id = @intCast(i);
                team.stat_count = stat_counts[i];

                if (stat_counts[i] > 0 and stat_counts[i] < 100000) {
                    const entry_count: usize = @intCast(stat_counts[i]);
                    const entries = try self.allocator.alloc(TeamStatsDataPoint, entry_count);

                    for (entries) |*entry| {
                        const raw_entry = try self.reader.readStruct(TeamStatsDataPoint);
                        entry.* = raw_entry;
                        entry.team_id = team.team_id; // Override with correct team ID
                    }
                    team.entries = entries;
                } else {
                    team.entries = &[_]TeamStatsDataPoint{};
                }
            }
            match.statistics.team_stats = teams;
        }
    }
};
