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
    const STARTPLAYING: u8 = 4;
};

const Vector3 = struct { x: f32, y: f32, z: f32 };

const ChatMessagePacket = struct {
    from_id: u8,
    to_id: u8,
    message: []const u8,
    game_timestamp: i32,
};

const PlayerStats = struct {
    num_commands: i32,
    unit_commands: i32,
    mouse_pixels: i32,
    mouse_clicks: i32,
    key_presses: i32,
};

const TeamStatsDataPoint = struct {
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

    pub fn readFrom(reader: std.io.AnyReader) !TeamStatsDataPoint {
        return TeamStatsDataPoint{
            .frame = try reader.readInt(i32, .little),
            .metal_used = @as(f32, @bitCast(try reader.readInt(u32, .little))),
            .energy_used = @as(f32, @bitCast(try reader.readInt(u32, .little))),
            .metal_produced = @as(f32, @bitCast(try reader.readInt(u32, .little))),
            .energy_produced = @as(f32, @bitCast(try reader.readInt(u32, .little))),
            .metal_excess = @as(f32, @bitCast(try reader.readInt(u32, .little))),
            .energy_excess = @as(f32, @bitCast(try reader.readInt(u32, .little))),
            .metal_received = @as(f32, @bitCast(try reader.readInt(u32, .little))),
            .energy_received = @as(f32, @bitCast(try reader.readInt(u32, .little))),
            .metal_send = @as(f32, @bitCast(try reader.readInt(u32, .little))),
            .energy_send = @as(f32, @bitCast(try reader.readInt(u32, .little))),
            .damage_dealt = @as(f32, @bitCast(try reader.readInt(u32, .little))),
            .damage_received = @as(f32, @bitCast(try reader.readInt(u32, .little))),
            .units_produced = try reader.readInt(i32, .little),
            .units_died = try reader.readInt(i32, .little),
            .units_received = try reader.readInt(i32, .little),
            .units_sent = try reader.readInt(i32, .little),
            .units_captured = try reader.readInt(i32, .little),
            .units_out_captured = try reader.readInt(i32, .little),
            .units_killed = try reader.readInt(i32, .little),
        };
    }
};

const TeamStats = struct {
    team_id: i32,
    stat_count: i32,
    entries: ArrayList(TeamStatsDataPoint),

    pub fn init(allocator: Allocator) TeamStats {
        return TeamStats{
            .team_id = 0,
            .stat_count = 0,
            .entries = ArrayList(TeamStatsDataPoint).init(allocator),
        };
    }
};

const Statistics = struct {
    winning_ally_team_ids: []u8,
    player_stats: ArrayList(PlayerStats),
    team_stats: ArrayList(TeamStats),

    pub fn init(allocator: Allocator) Statistics {
        return Statistics{
            .winning_ally_team_ids = &[_]u8{},
            .player_stats = ArrayList(PlayerStats).init(allocator),
            .team_stats = ArrayList(TeamStats).init(allocator),
        };
    }
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
    metadata_and_stats,
    full_without_chat,
    full,
};

pub const BarMatch = struct {
    header: Header,
    game_config: gameconfig_parser.GameConfig,
    packet_offset: i32 = 0,
    stat_offset: i32 = 0,
    packet_count: i32 = 0,
    chat_messages: ArrayList(ChatMessagePacket),
    statistics: Statistics,
    allocator: Allocator,

    pub fn init(allocator: Allocator) BarMatch {
        return BarMatch{
            .header = Header.init(),
            .game_config = gameconfig_parser.GameConfig.init(allocator),
            .chat_messages = ArrayList(ChatMessagePacket).init(allocator),
            .statistics = Statistics.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BarMatch) void {
        self.game_config.deinit();
        for (self.chat_messages.items) |msg| {
            self.allocator.free(msg.message);
        }
        self.chat_messages.deinit();
        if (self.statistics.winning_ally_team_ids.len > 0) {
            self.allocator.free(self.statistics.winning_ally_team_ids);
        }
        self.statistics.player_stats.deinit();
        self.statistics.team_stats.deinit();
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
            const escaped_message = try escapeJsonString(allocator, msg.message);
            defer allocator.free(escaped_message);
            try writer.print("{{\"from_id\":{d},\"to_id\":{d},\"message\":\"{s}\",\"game_timestamp\":{d}}}", .{ msg.from_id, msg.to_id, escaped_message, msg.game_timestamp });
        }
        try writer.writeAll("],");

        try writer.writeAll("\"statistics\":{\"winning_ally_team_ids\":[");
        for (self.statistics.winning_ally_team_ids, 0..) |team_id, i| {
            if (i > 0) try writer.writeByte(',');
            try writer.print("{d}", .{team_id});
        }
        try writer.writeAll("],\"player_stats\":[");
        for (self.statistics.player_stats.items, 0..) |stat, i| {
            if (i > 0) try writer.writeByte(',');
            try writer.print("{{\"player_id\":{d},\"mouse_pixels\":{d},\"mouse_clicks\":{d},\"key_presses\":{d}}}", .{ i, stat.mouse_pixels, stat.mouse_clicks, stat.key_presses });
        }
        try writer.writeAll("],\"team_stats\":[");
        for (self.statistics.team_stats.items, 0..) |team_stat, i| {
            if (i > 0) try writer.writeByte(',');
            try writer.print("{{\"team_id\":{d},\"stat_count\":{d},", .{ team_stat.team_id, team_stat.stat_count });

            // Write columnar data format
            try writer.writeAll("\"frame\":[");
            for (team_stat.entries.items, 0..) |entry, j| {
                if (j > 0) try writer.writeByte(',');
                try writer.print("{d}", .{entry.frame});
            }
            try writer.writeAll("],\"metal_used\":[");
            for (team_stat.entries.items, 0..) |entry, j| {
                if (j > 0) try writer.writeByte(',');
                try writer.print("{d}", .{@as(i32, @intFromFloat(entry.metal_used))});
            }
            try writer.writeAll("],\"energy_used\":[");
            for (team_stat.entries.items, 0..) |entry, j| {
                if (j > 0) try writer.writeByte(',');
                try writer.print("{d}", .{@as(i32, @intFromFloat(entry.energy_used))});
            }
            try writer.writeAll("],\"metal_produced\":[");
            for (team_stat.entries.items, 0..) |entry, j| {
                if (j > 0) try writer.writeByte(',');
                try writer.print("{d}", .{@as(i32, @intFromFloat(entry.metal_produced))});
            }
            try writer.writeAll("],\"energy_produced\":[");
            for (team_stat.entries.items, 0..) |entry, j| {
                if (j > 0) try writer.writeByte(',');
                try writer.print("{d}", .{@as(i32, @intFromFloat(entry.energy_produced))});
            }
            try writer.writeAll("],\"metal_excess\":[");
            for (team_stat.entries.items, 0..) |entry, j| {
                if (j > 0) try writer.writeByte(',');
                try writer.print("{d}", .{@as(i32, @intFromFloat(entry.metal_excess))});
            }
            try writer.writeAll("],\"energy_excess\":[");
            for (team_stat.entries.items, 0..) |entry, j| {
                if (j > 0) try writer.writeByte(',');
                try writer.print("{d}", .{@as(i32, @intFromFloat(entry.energy_excess))});
            }
            try writer.writeAll("],\"metal_received\":[");
            for (team_stat.entries.items, 0..) |entry, j| {
                if (j > 0) try writer.writeByte(',');
                try writer.print("{d}", .{@as(i32, @intFromFloat(entry.metal_received))});
            }
            try writer.writeAll("],\"energy_received\":[");
            for (team_stat.entries.items, 0..) |entry, j| {
                if (j > 0) try writer.writeByte(',');
                try writer.print("{d}", .{@as(i32, @intFromFloat(entry.energy_received))});
            }
            try writer.writeAll("],\"metal_send\":[");
            for (team_stat.entries.items, 0..) |entry, j| {
                if (j > 0) try writer.writeByte(',');
                try writer.print("{d}", .{@as(i32, @intFromFloat(entry.metal_send))});
            }
            try writer.writeAll("],\"energy_send\":[");
            for (team_stat.entries.items, 0..) |entry, j| {
                if (j > 0) try writer.writeByte(',');
                try writer.print("{d}", .{@as(i32, @intFromFloat(entry.energy_send))});
            }
            try writer.writeAll("],\"damage_dealt\":[");
            for (team_stat.entries.items, 0..) |entry, j| {
                if (j > 0) try writer.writeByte(',');
                try writer.print("{d}", .{@as(i32, @intFromFloat(entry.damage_dealt))});
            }
            try writer.writeAll("],\"damage_received\":[");
            for (team_stat.entries.items, 0..) |entry, j| {
                if (j > 0) try writer.writeByte(',');
                try writer.print("{d}", .{@as(i32, @intFromFloat(entry.damage_received))});
            }
            try writer.writeAll("],\"units_produced\":[");
            for (team_stat.entries.items, 0..) |entry, j| {
                if (j > 0) try writer.writeByte(',');
                try writer.print("{d}", .{entry.units_produced});
            }
            try writer.writeAll("],\"units_died\":[");
            for (team_stat.entries.items, 0..) |entry, j| {
                if (j > 0) try writer.writeByte(',');
                try writer.print("{d}", .{entry.units_died});
            }
            try writer.writeAll("],\"units_received\":[");
            for (team_stat.entries.items, 0..) |entry, j| {
                if (j > 0) try writer.writeByte(',');
                try writer.print("{d}", .{entry.units_received});
            }
            try writer.writeAll("],\"units_sent\":[");
            for (team_stat.entries.items, 0..) |entry, j| {
                if (j > 0) try writer.writeByte(',');
                try writer.print("{d}", .{entry.units_sent});
            }
            try writer.writeAll("],\"units_captured\":[");
            for (team_stat.entries.items, 0..) |entry, j| {
                if (j > 0) try writer.writeByte(',');
                try writer.print("{d}", .{entry.units_captured});
            }
            try writer.writeAll("],\"units_out_captured\":[");
            for (team_stat.entries.items, 0..) |entry, j| {
                if (j > 0) try writer.writeByte(',');
                try writer.print("{d}", .{entry.units_out_captured});
            }
            try writer.writeAll("],\"units_killed\":[");
            for (team_stat.entries.items, 0..) |entry, j| {
                if (j > 0) try writer.writeByte(',');
                try writer.print("{d}", .{entry.units_killed});
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

pub fn parse(allocator: Allocator, mode: ParseMode, reader: std.io.AnyReader) !BarMatch {
    var match = BarMatch.init(allocator);
    errdefer match.deinit();

    match.header = try reader.readStruct(Header);

    if (!std.mem.eql(u8, &match.header.magic, "spring demofile\x00")) {
        return ParseError.InvalidHeader;
    }

    match.packet_offset = @sizeOf(Header) + match.header.script_size;
    match.stat_offset = match.packet_offset + match.header.demo_stream_size;

    if (mode == .header_only) return match;

    if (match.header.script_size > 0) {
        const script = try allocator.alloc(u8, @intCast(match.header.script_size));
        defer allocator.free(script);
        _ = try reader.readAll(script);
        match.game_config = try gameconfig_parser.parseScript(allocator, script);
    }

    if (mode == .metadata_only) return match;

    if (mode == .metadata_and_stats) {
        try reader.skipBytes(@intCast(match.header.demo_stream_size), .{});
        try parseStatistics(allocator, reader, &match);
        return match;
    }

    try parsePacketsStreaming(allocator, reader, mode, &match);
    try parseStatistics(allocator, reader, &match);

    return match;
}

const StartPosPacket = struct {
    playerId: u8,
    teamId: u8,
    ready: u8,
    x: f32,
    y: f32,
    z: f32,

    pub fn readFrom(reader: std.io.AnyReader) !StartPosPacket {
        const playerId = try reader.readByte();
        const teamId = try reader.readByte();
        const ready = try reader.readByte();
        const x = @as(f32, @bitCast(try reader.readInt(u32, .little)));
        const y = @as(f32, @bitCast(try reader.readInt(u32, .little)));
        const z = @as(f32, @bitCast(try reader.readInt(u32, .little)));

        return StartPosPacket{
            .playerId = playerId,
            .teamId = teamId,
            .ready = ready,
            .x = x,
            .y = y,
            .z = z,
        };
    }
};

fn parsePacketsStreaming(allocator: Allocator, reader: std.io.AnyReader, mode: ParseMode, match: *BarMatch) !void {
    var bytes_read: u32 = 0;
    const total_size: u32 = @intCast(match.header.demo_stream_size);

    while (bytes_read < total_size) {
        const game_time = try reader.readInt(i32, .little);
        bytes_read += 4;

        const length = try reader.readInt(u32, .little);
        bytes_read += 4;

        const packet_type = try reader.readByte();
        switch (packet_type) {
            PacketType.START_POS => {
                const pos = try StartPosPacket.readFrom(reader);
                const startpos = try match.game_config.arena.allocator().alloc(f32, 3);
                startpos[0] = pos.x;
                startpos[1] = pos.y;
                startpos[2] = pos.z;
                for (match.game_config.players.items) |*player| {
                    if (player.id == pos.playerId) {
                        player.startpos = startpos;
                        break;
                    }
                }
            },
            PacketType.STARTPLAYING => {
                // uint32_t countdown
                const countdown = try reader.readInt(u32, .little);
                if (mode == .full_without_chat) {
                    if (countdown == 0) {
                        // Stop parsing packets if game has started
                        bytes_read += length;
                        _ = try reader.skipBytes(total_size - bytes_read, .{});
                        break;
                    }
                }
            },
            PacketType.CHAT => {
                if (mode == .full_without_chat) {
                    try reader.skipBytes(length - 1, .{});
                } else {
                    const from = try reader.readByte();
                    const to = try reader.readByte();
                    const msg_len = length - 3;
                    const msg = try allocator.alloc(u8, msg_len);
                    _ = try reader.readAll(msg);
                    try match.chat_messages.append(.{
                        .from_id = from,
                        .to_id = to,
                        .message = msg[1 .. msg_len - 1],
                        .game_timestamp = game_time,
                    });
                }
            },
            else => {
                try reader.skipBytes(length - 1, .{});
            },
        }
        bytes_read += length;
        match.packet_count += 1;
    }
}

fn parseStatistics(allocator: Allocator, reader: std.io.AnyReader, match: *BarMatch) !void {
    if (match.header.winning_ally_teams_size > 0) {
        const teams = try allocator.alloc(u8, @intCast(match.header.winning_ally_teams_size));
        _ = try reader.readAll(teams);
        match.statistics.winning_ally_team_ids = teams;
    }

    if (match.header.player_stat_size > 0) {
        const playerStatsBuffer = try allocator.alloc(u8, @intCast(match.header.player_stat_size));
        _ = try reader.readAll(playerStatsBuffer);
        const playerStatElemSize: usize = @intCast(match.header.player_stat_elem_size);
        const playerCount: usize = @intCast(match.header.player_count);
        for (0..playerCount) |i| {
            const offset = i * playerStatElemSize;
            const playerStatSlice = playerStatsBuffer[offset .. offset + playerStatElemSize];
            const num_commands = @as(i32, @bitCast(std.mem.readInt(u32, playerStatSlice[0..4], .little)));
            const unit_commands = @as(i32, @bitCast(std.mem.readInt(u32, playerStatSlice[4..8], .little)));
            const mouse_pixels = @as(i32, @bitCast(std.mem.readInt(u32, playerStatSlice[8..12], .little)));
            const mouse_clicks = @as(i32, @bitCast(std.mem.readInt(u32, playerStatSlice[12..16], .little)));
            const key_presses = @as(i32, @bitCast(std.mem.readInt(u32, playerStatSlice[16..20], .little)));
            const stat = PlayerStats{
                .num_commands = num_commands,
                .unit_commands = unit_commands,
                .mouse_pixels = mouse_pixels,
                .mouse_clicks = mouse_clicks,
                .key_presses = key_presses,
            };
            try match.statistics.player_stats.append(stat);
        }
    }

    if (match.header.team_count > 0) {
        const teamCount: usize = @intCast(match.header.team_count);
        const teamStatSize: usize = @intCast(match.header.team_stat_size);
        // const teamStatElemSize: usize = @intCast(match.header.team_stat_elem_size);

        var teams = ArrayList(TeamStats).init(allocator);
        const teamStatsBuffer = try allocator.alloc(u8, @intCast(teamStatSize));
        _ = try reader.readAll(teamStatsBuffer);

        var fixedBufferStream = std.io.fixedBufferStream(teamStatsBuffer);
        const teamStatsReader = fixedBufferStream.reader();

        const numberOfStatsForTeam = try allocator.alloc(u8, teamCount * 4);
        _ = try teamStatsReader.readAll(numberOfStatsForTeam);

        for (0..teamCount) |i| {
            var teamStat = TeamStats.init(allocator);
            teamStat.team_id = @intCast(i);
            teamStat.stat_count = std.mem.bytesAsValue(i32, numberOfStatsForTeam[i * 4 .. (i + 1) * 4]).*;
            for (0..@intCast(teamStat.stat_count)) |_| {
                const entry = try TeamStatsDataPoint.readFrom(teamStatsReader.any());
                try teamStat.entries.append(entry);
            }

            try teams.append(teamStat);
        }
        match.statistics.team_stats = teams;
    }
}

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
