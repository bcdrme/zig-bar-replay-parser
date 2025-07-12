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

// StartBox equivalent
const StartBox = struct {
    top: f32 = 0.0,
    bottom: f32 = 0.0,
    left: f32 = 0.0,
    right: f32 = 0.0,
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

    pub fn init(allocator: Allocator) BarMatchPlayer {
        _ = allocator;
        return BarMatchPlayer{
            .team_id = 0,
            .game_id = "",
            .ally_team_id = 0,
            .player_id = 0,
            .user_id = 0,
            .name = "",
            .faction = "",
            .skill_uncertainty = 0.0,
            .skill = 0.0,
        };
    }
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
    allocator: Allocator,

    pub fn init(allocator: Allocator) BarMatch {
        return BarMatch{ .header = DemofileHeader.init(allocator), .file_name = "", .mod_config = "", .winning_ally_teams = ArrayList(u8).init(allocator), .allocator = allocator };
    }

    pub fn deinit(self: *BarMatch) void {
        self.header.deinit();
        self.allocator.free(self.file_name);
        self.allocator.free(self.mod_config);
        self.winning_ally_teams.deinit();
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
        return DemofileHeader{ .magic = "", .header_version = 0, .header_size = 0, .game_version = "", .game_id = "", .start_time = 0, .script_size = 0, .demo_stream_size = 0, .game_time = 0, .wall_clock_time = 0, .player_count = 0, .player_stat_size = 0, .player_stat_elem_size = 0, .team_count = 0, .team_stat_size = 0, .team_stat_elem_size = 0, .team_stat_period = 0, .winning_ally_teams_size = 0, .allocator = allocator };
    }

    pub fn deinit(self: *DemofileHeader) void {
        self.allocator.free(self.magic);
        self.allocator.free(self.game_version);
        self.allocator.free(self.game_id);
    }
};

// Packet structure
const DemofilePacket = struct {
    game_time: f32,
    length: u32,
    packet_type: u8,
    data: []const u8,
};

// Statistics structures
const DemofilePlayerStats = struct {
    player_id: i32,
    command_count: i32,
    unit_commands: i32,
    mouse_pixels: i32,
    mouse_clicks: i32,
    key_presses: i32,
};

const DemofileTeamFrameStats = struct {
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

const DemofileTeamStats = struct {
    team_id: i32,
    stat_count: i32,
    entries: ArrayList(DemofileTeamFrameStats),

    pub fn init(allocator: Allocator) DemofileTeamStats {
        return DemofileTeamStats{
            .team_id = 0,
            .stat_count = 0,
            .entries = ArrayList(DemofileTeamFrameStats).init(allocator),
        };
    }

    pub fn deinit(self: *DemofileTeamStats) void {
        self.entries.deinit();
    }
};

// Byte reader for binary data
const ByteArrayReader = struct {
    data: []const u8,
    index: usize,

    pub fn init(data: []const u8) ByteArrayReader {
        return ByteArrayReader{
            .data = data,
            .index = 0,
        };
    }

    pub fn jumpTo(self: *ByteArrayReader, position: usize) void {
        if (position <= self.data.len) {
            self.index = position;
        } else {
            self.index = self.data.len; // Prevent out of bounds
        }
    }

    pub fn readU8(self: *ByteArrayReader) !u8 {
        if (self.index >= self.data.len) return ParseError.EndOfStream;
        const result = self.data[self.index];
        self.index += 1;
        return result;
    }

    pub fn readI32LE(self: *ByteArrayReader) !i32 {
        if (self.index + 4 > self.data.len) return ParseError.EndOfStream;
        const result = std.mem.readInt(i32, self.data[self.index .. self.index + 4][0..4], .little);
        self.index += 4;
        return result;
    }

    pub fn readU32LE(self: *ByteArrayReader) !u32 {
        if (self.index + 4 > self.data.len) return ParseError.EndOfStream;
        const result = std.mem.readInt(u32, self.data[self.index .. self.index + 4][0..4], .little);
        self.index += 4;
        return result;
    }

    pub fn readI64LE(self: *ByteArrayReader) !i64 {
        if (self.index + 8 > self.data.len) return ParseError.EndOfStream;
        const result = std.mem.readInt(i64, self.data[self.index .. self.index + 8][0..8], .little);
        self.index += 8;
        return result;
    }

    pub fn readF32LE(self: *ByteArrayReader) !f32 {
        if (self.index + 4 > self.data.len) return ParseError.EndOfStream;
        const result = @as(f32, @bitCast(std.mem.readInt(u32, self.data[self.index .. self.index + 4][0..4], .little)));
        self.index += 4;
        return result;
    }

    pub fn readBytes(self: *ByteArrayReader, len: usize) ![]const u8 {
        if (self.index + len > self.data.len) return ParseError.EndOfStream;
        const result = self.data[self.index .. self.index + len];
        self.index += len;
        return result;
    }

    pub fn readAsciiString(self: *ByteArrayReader, len: usize) ![]const u8 {
        return self.readBytes(len);
    }

    pub fn readAsciiStringNullTerminated(self: *ByteArrayReader, max_len: usize) ![]const u8 {
        if (self.index + max_len > self.data.len) return ParseError.EndOfStream;
        const start = self.index;
        const slice = self.data[start .. start + max_len];
        const null_pos = std.mem.indexOfScalar(u8, slice, 0) orelse max_len;
        self.index += max_len;
        return slice[0..null_pos];
    }

    pub fn readUntilNull(self: *ByteArrayReader) ![]const u8 {
        const start = self.index;
        while (self.index < self.data.len and self.data[self.index] != 0) {
            self.index += 1;
        }
        const result = self.data[start..self.index];
        if (self.index < self.data.len) self.index += 1; // Skip null terminator
        return result;
    }

    pub fn readAll(self: *ByteArrayReader) []const u8 {
        const result = self.data[self.index..];
        self.index = self.data.len;
        return result;
    }

    pub fn hasMore(self: *ByteArrayReader) bool {
        return self.index < self.data.len;
    }
};

// Main parser
const BarDemofileParser = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) BarDemofileParser {
        return BarDemofileParser{
            .allocator = allocator,
        };
    }

    pub fn parse(self: *BarDemofileParser, filename: []const u8, demofile: []const u8) !BarMatch {
        var timer = std.time.Timer.start() catch unreachable;

        // Decompress the file
        var stream = std.io.fixedBufferStream(demofile);
        var gzip_stream = std.compress.gzip.decompressor(stream.reader());

        var decompressed = ArrayList(u8).init(self.allocator);
        defer decompressed.deinit();

        var buffer: [1024 * 1024]u8 = undefined;
        var total_read: usize = 0;

        while (true) {
            const bytes_read = gzip_stream.read(&buffer) catch |err| switch (err) {
                error.EndOfStream => break,
                else => return err,
            };

            if (bytes_read == 0) break;

            total_read += bytes_read;
            try decompressed.appendSlice(buffer[0..bytes_read]);

            // Anti-zip-bomb protection
            if (total_read > 256 * 1024 * 1024) {
                print("uncompressed demofile reached unsafe size, exiting [filename={s}]\n", .{filename});
                return ParseError.DecompressionTooLarge;
            }
        }

        const data = try decompressed.toOwnedSlice();
        defer self.allocator.free(data);

        const elapsed = timer.read() / std.time.ns_per_ms;
        print("decompressed demofile [duration={}ms] [input size={}] [output size={}]\n", .{ elapsed, demofile.len, data.len });

        return try self.readBytes(filename, data);
    }

    fn readBytes(self: *BarDemofileParser, filename: []const u8, data: []const u8) !BarMatch {
        var reader = ByteArrayReader.init(data);
        var match = BarMatch.init(self.allocator);

        // Copy filename
        const filename_copy = try self.allocator.dupe(u8, filename);
        match.file_name = filename_copy;

        // Read header
        const magic = try reader.readAsciiStringNullTerminated(16);
        const magic_copy = try self.allocator.dupe(u8, magic);
        match.header.magic = magic_copy;

        if (!std.mem.eql(u8, match.header.magic, "spring demofile")) {
            return ParseError.InvalidMagic;
        }

        match.header.header_version = try reader.readI32LE();
        match.header.header_size = try reader.readI32LE();

        const game_version = try reader.readAsciiString(256);
        const game_version_copy = try self.allocator.dupe(u8, game_version);
        match.header.game_version = game_version_copy;

        const game_id_bytes = try reader.readBytes(16);
        var game_id_buf: [32]u8 = undefined;
        const game_id = std.fmt.bufPrint(&game_id_buf, "{}", .{std.fmt.fmtSliceHexLower(game_id_bytes)}) catch unreachable;
        const game_id_copy = try self.allocator.dupe(u8, game_id);
        match.header.game_id = game_id_copy;

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

        if (reader.index != 0x0160) {
            print("expected reader index to be at {}, was at {} instead\n", .{ 0x0160, reader.index });
            return ParseError.UnexpectedReaderPosition;
        }

        // Read mod config
        const mod_config = try reader.readAsciiString(@intCast(match.header.script_size));
        const mod_config_copy = try self.allocator.dupe(u8, mod_config);

        // Set match properties
        match.mod_config = mod_config_copy;

        // Calculate packet and stat offsets
        match.packet_offset = reader.index;
        match.stat_offset = match.packet_offset + @as(usize, @intCast(match.header.demo_stream_size));

        // Parse packets
        // var unit_def_dict = std.HashMap(i32, []const u8, std.hash_map.AutoContext(i32), std.hash_map.default_max_load_percentage).init(self.allocator);
        // defer unit_def_dict.deinit();

        // var winning_ally_teams = ArrayList(u8).init(self.allocator);
        // defer winning_ally_teams.deinit();

        const packet_count: i32 = 0;
        // var frame_count: i32 = 0;
        // var max_frame: i32 = 0;

        // while (reader.index < header.stat_offset) {
        //     const packet_start = reader.index;
        //     const game_time = try reader.readF32LE();
        //     const length = try reader.readU32LE();
        //     const packet_type = try reader.readU8();

        //     if (packet_start + @as(usize, length) + 8 > data.len) break;

        //     const packet_data = try reader.readBytes(length - 1);
        //     packet_count += 1;

        //     try self.processPacket(packet_type, packet_data, game_time, &match, &players, &unit_def_dict, &winning_ally_teams, &max_frame, &frame_count, header.game_id);

        //     if (packet_type == PacketType.QUIT) {
        //         print("found packet type 3, breaking [index={}] [packet count={}]\n", .{ reader.index, packet_count });
        //         break;
        //     }
        // }

        // print("packets parsed [gameID={s}] [packet count={}] [frame count={}] [max frame={}]\n", .{ match.id, packet_count, frame_count, max_frame });
        // match.duration_frame_count = max_frame;

        reader.jumpTo(match.stat_offset);

        // Ensure we're at the stat offset
        if (match.stat_offset != reader.index) {
            print("expected reader to be {} (for reading stats), was at {} instead\n", .{ match.stat_offset, reader.index });
            return ParseError.UnexpectedReaderPosition;
        }

        // Parse statistics
        try self.parseStatistics(&reader, &match);

        // Set ally team win status and player counts
        // for (match.ally_teams.items) |*ally_team| {
        //     for (winning_ally_teams.items) |winning_id| {
        //         if (ally_team.ally_team_id == winning_id) {
        //             ally_team.won = true;
        //             break;
        //         }
        //     }

        //     var player_count: i32 = 0;
        //     for (match.players.items) |player| {
        //         if (player.ally_team_id == ally_team.ally_team_id) {
        //             player_count += 1;
        //         }
        //     }
        //     ally_team.player_count = player_count;
        //     match.player_count += player_count;
        // }

        // Determine gamemode
        // match.gamemode = self.determineGamemode(&match);

        print("demofile parsed [gameID={s}] [gamemode={}] [packets={}]\n", .{ match.header.game_id, match.gamemode, packet_count });

        return match;
    }

    fn processPacket(self: *BarDemofileParser, packet_type: u8, packet_data: []const u8, game_time: f32, match: *BarMatch, players: *std.HashMap(i32, BarMatchPlayer, std.hash_map.AutoContext(i32), std.hash_map.default_max_load_percentage), unit_def_dict: *std.HashMap(i32, []const u8, std.hash_map.AutoContext(i32), std.hash_map.default_max_load_percentage), winning_ally_teams: *ArrayList(u8), max_frame: *i32, frame_count: *i32, game_id: []const u8) !void {
        var packet_reader = ByteArrayReader.init(packet_data);

        switch (packet_type) {
            PacketType.CHAT => {
                var msg = BarMatchChatMessage{
                    .size = try packet_reader.readU8(),
                    .from_id = try packet_reader.readU8(),
                    .to_id = try packet_reader.readU8(),
                    .message = "",
                    .game_id = match.id,
                    .game_timestamp = game_time,
                };

                const message_bytes = try packet_reader.readUntilNull();
                msg.message = try self.allocator.dupe(u8, message_bytes);

                try match.chat_messages.append(msg);
            },

            PacketType.GAME_ID => {
                const packet_game_id_bytes = try packet_reader.readBytes(16);
                var packet_game_id_buf: [32]u8 = undefined;
                const packet_game_id = std.fmt.bufPrint(&packet_game_id_buf, "{}", .{std.fmt.fmtSliceHexLower(packet_game_id_bytes)}) catch unreachable;

                if (!std.mem.eql(u8, packet_game_id, game_id)) {
                    return ParseError.InvalidGameId;
                }
            },

            PacketType.START_POS => {
                const player_id = try packet_reader.readU8();
                const team_id = try packet_reader.readU8();
                const ready_state = try packet_reader.readU8();
                const x = try packet_reader.readF32LE();
                const y = try packet_reader.readF32LE();
                const z = try packet_reader.readF32LE();

                _ = player_id;
                _ = ready_state;

                if (players.getPtr(@intCast(team_id))) |player| {
                    player.starting_position = Vector3{ .x = x, .y = y, .z = z };
                } else {
                    print("cannot set start position, team does not exist [teamID={}] [gameID={s}]\n", .{ team_id, game_id });
                }
            },

            PacketType.LUA_MSG => {
                const size = try packet_reader.readI32LE();
                const player_num = try packet_reader.readU8();
                const script = try packet_reader.readI32LE();
                const mode = try packet_reader.readU8();

                _ = size;
                _ = script;
                _ = mode;

                const bytes = packet_reader.readAll();
                const msg = try self.allocator.dupe(u8, bytes);
                defer self.allocator.free(msg);

                try self.processLuaMessage(msg, player_num, players, unit_def_dict, game_id);
            },

            PacketType.KEYFRAME => {
                const frame = try packet_reader.readI32LE();
                max_frame.* = @max(max_frame.*, frame);
            },

            PacketType.NEW_FRAME => {
                frame_count.* += 1;
            },

            PacketType.GAME_OVER => {
                const size = try packet_reader.readU8();
                const player_num = try packet_reader.readU8();

                _ = size;
                _ = player_num;

                const winning_teams = packet_reader.readAll();
                try winning_ally_teams.appendSlice(winning_teams);
            },

            PacketType.TEAM_MSG => {
                const player_num = try packet_reader.readU8();
                const action = try packet_reader.readU8();
                const param1 = try packet_reader.readU8();

                if (action == 2 or action == 4) { // resigned or team died
                    const team_id = if (action == 2) player_num else param1;

                    const death = BarMatchTeamDeath{
                        .game_id = match.id,
                        .team_id = team_id,
                        .reason = action,
                        .game_time = game_time,
                    };

                    try match.team_deaths.append(death);
                }
            },

            else => {
                // Unknown packet type, skip
            },
        }
    }

    fn processLuaMessage(self: *BarDemofileParser, msg: []const u8, player_num: u8, players: *std.HashMap(i32, BarMatchPlayer, std.hash_map.AutoContext(i32), std.hash_map.default_max_load_percentage), unit_def_dict: *std.HashMap(i32, []const u8, std.hash_map.AutoContext(i32), std.hash_map.default_max_load_percentage), game_id: []const u8) !void {
        if (std.mem.startsWith(u8, msg, "AutoColors")) {
            // const colors = msg[10..];
            // const colors_array = parsed.value.array;
            // for (colors_array.items) |color_obj| {
            //     const team_id = @as(i32, @intCast(color_obj.object.get("teamID").?.integer));
            //     const r = @as(u8, @intCast(@max(0, @min(255, color_obj.object.get("r").?.integer))));
            //     const g = @as(u8, @intCast(@max(0, @min(255, color_obj.object.get("g").?.integer))));
            //     const b = @as(u8, @intCast(@max(0, @min(255, color_obj.object.get("b").?.integer))));

            //     if (players.getPtr(team_id)) |player| {
            //         player.color = (@as(u32, r) << 16) | (@as(u32, g) << 8) | @as(u32, b);
            //     }
            // }
        } else if (std.mem.startsWith(u8, msg, "changeStartUnit")) {
            const unit_def_id_str = msg["changeStartUnit".len..];
            const unit_def_id = try std.fmt.parseInt(i32, unit_def_id_str, 10);

            print("player changing factions [playerNum={}] [unitDefID={}] [gameID={s}]\n", .{ player_num, unit_def_id, game_id });

            if (unit_def_dict.get(unit_def_id)) |def_name| {
                if (players.getPtr(@intCast(player_num))) |player| {
                    if (std.mem.eql(u8, def_name, "armcom")) {
                        player.faction = try self.allocator.dupe(u8, "Armada");
                    } else if (std.mem.eql(u8, def_name, "corcom")) {
                        player.faction = try self.allocator.dupe(u8, "Cortex");
                    } else if (std.mem.eql(u8, def_name, "legcom")) {
                        player.faction = try self.allocator.dupe(u8, "Legion");
                    } else if (std.mem.eql(u8, def_name, "dummycom")) {
                        player.faction = try self.allocator.dupe(u8, "Random");
                    } else {
                        print("unchecked defName for changeStartUnit [id={s}] [def name={s}]\n", .{ game_id, def_name });
                    }
                    print("player changed factions [playerNum={}] [faction={s}] [unitDefID={}] [gameID={s}]\n", .{ player_num, player.faction, unit_def_id, game_id });
                }
            } else {
                print("missing unit definition in changeStartUnit! [gameID={s}] [def ID={}] [playerID={}]\n", .{ game_id, unit_def_id, player_num });
            }
        } else if (std.mem.startsWith(u8, msg, "unitdefs:")) {
            // const compressed_data = msg["unitdefs:".len..];

            // // Decompress using zlib
            // var stream = std.io.fixedBufferStream(compressed_data);
            // var zlib_stream = std.compress.zlib.decompressor(stream.reader());

            // var decompressed = ArrayList(u8).init(self.allocator);
            // defer decompressed.deinit();

            // var buffer: [4096]u8 = undefined;
            // while (true) {
            //     const bytes_read = zlib_stream.read(&buffer) catch |err| switch (err) {
            //         error.EndOfStream => break,
            //         else => return err,
            //     };

            //     if (bytes_read == 0) break;
            //     try decompressed.appendSlice(buffer[0..bytes_read]);
            // }

            // const unit_defs_json = try decompressed.toOwnedSlice();
            // defer self.allocator.free(unit_defs_json);

            // var parsed = json.parseFromSlice(json.Value, self.allocator, unit_defs_json, .{}) catch return;
            // defer parsed.deinit();

            // const unit_defs_array = parsed.value.array;
            // var index: i32 = 1; // Starts at 1 instead of 0

            // for (unit_defs_array.items) |unit_def| {
            //     const def_name = try self.allocator.dupe(u8, unit_def.string);

            //     if (unit_def_dict.get(index)) |existing_name| {
            //         if (!std.mem.eql(u8, existing_name, def_name)) {
            //             print("inconsistent def names! [gameID={s}] [index={}] [current={s}] [new={s}]\n", .{ game_id, index, existing_name, def_name });
            //         }
            //     } else {
            //         try unit_def_dict.put(index, def_name);
            //     }
            //     index += 1;
            // }
        }
    }

    fn parseStatistics(self: *BarDemofileParser, reader: *ByteArrayReader, match: *BarMatch) !void {
        // Parse winning ally teams
        var i: i32 = 0;
        while (i < match.header.winning_ally_teams_size) : (i += 1) {
            const ally_team_id = try reader.readU8();
            try match.winning_ally_teams.append(ally_team_id);
        }

        // Parse player statistics
        i = 0;
        while (i < match.header.player_count) : (i += 1) {
            const command_count = try reader.readI32LE();
            const unit_commands = try reader.readI32LE();
            const mouse_pixels = try reader.readI32LE();
            const mouse_clicks = try reader.readI32LE();
            const key_presses = try reader.readI32LE();

            _ = command_count;
            _ = unit_commands;
            _ = mouse_pixels;
            _ = mouse_clicks;
            _ = key_presses;
        }

        // Parse team statistics
        var team_stats = ArrayList(DemofileTeamStats).init(self.allocator);
        defer {
            for (team_stats.items) |*stat| {
                stat.deinit();
            }
            team_stats.deinit();
        }

        i = 0;
        while (i < match.header.team_count) : (i += 1) {
            var team_stat = DemofileTeamStats.init(self.allocator);
            team_stat.team_id = i;
            team_stat.stat_count = try reader.readI32LE();
            try team_stats.append(team_stat);
        }

        // Parse team frame statistics
        for (team_stats.items) |*team_stat| {
            var j: i32 = 0;
            while (j < team_stat.stat_count) : (j += 1) {
                const frame_stat = DemofileTeamFrameStats{
                    .team_id = team_stat.team_id,
                    .frame = try reader.readI32LE(),
                    .metal_used = try reader.readF32LE(),
                    .energy_used = try reader.readF32LE(),
                    .metal_produced = try reader.readF32LE(),
                    .energy_produced = try reader.readF32LE(),
                    .metal_excess = try reader.readF32LE(),
                    .energy_excess = try reader.readF32LE(),
                    .metal_received = try reader.readF32LE(),
                    .energy_received = try reader.readF32LE(),
                    .metal_send = try reader.readF32LE(),
                    .energy_send = try reader.readF32LE(),
                    .damage_dealt = try reader.readF32LE(),
                    .damage_received = try reader.readF32LE(),
                    .units_produced = try reader.readI32LE(),
                    .units_died = try reader.readI32LE(),
                    .units_received = try reader.readI32LE(),
                    .units_sent = try reader.readI32LE(),
                    .units_captured = try reader.readI32LE(),
                    .units_out_captured = try reader.readI32LE(),
                    .units_killed = try reader.readI32LE(),
                };

                try team_stat.entries.append(frame_stat);
            }
        }
    }

    // fn determineGamemode(self: *BarDemofileParser, match: *BarMatch) BarGamemode {
    //     _ = self;

    //     var largest_ally_team: i32 = 0;
    //     for (match.ally_teams.items) |ally_team| {
    //         largest_ally_team = @max(largest_ally_team, ally_team.player_count);
    //     }

    //     const ally_team_count = @as(i32, @intCast(match.ally_teams.items.len));

    //     if (ally_team_count == 2 and largest_ally_team == 1) {
    //         return .DUEL;
    //     } else if (ally_team_count == 2 and largest_ally_team <= 5) {
    //         return .SMALL_TEAM;
    //     } else if (ally_team_count == 2 and largest_ally_team <= 8) {
    //         return .LARGE_TEAM;
    //     } else if (ally_team_count > 2 and largest_ally_team == 1) {
    //         return .FFA;
    //     } else if (ally_team_count > 2 and largest_ally_team >= 2) {
    //         return .TEAM_FFA;
    //     } else {
    //         print("unchecked gamemode [gameID={s}] [largestAllyTeam={}] [allyTeamCount={}]\n", .{ match.id, largest_ally_team, ally_team_count });
    //         return .UNKNOWN;
    //     }
    // }
};

// Usage example
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = BarDemofileParser.init(allocator);
    print("BAR Demofile Parser initialized\n", .{});

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        print("Usage: bar_demofile_parser <demofile_path>\n", .{});
        return error.InvalidArguments;
    }

    const file_path = args[1];
    const file_data = try std.fs.cwd().readFileAlloc(allocator, file_path, 1024 * 1024 * 100);
    defer allocator.free(file_data);

    print("Parsing demofile: {s}\n", .{file_path});

    const file_name = std.fs.path.basename(file_path);
    var match = try parser.parse(file_name, file_data);
    defer match.deinit();

    // Print match details
    print("Match ID: {s}\n", .{match.header.game_id});
    print("Game Version: {s}\n", .{match.header.game_version});
    // print("Map: {s}\n", .{match.header.map});
    print("Start Time: {}\n", .{match.header.start_time});
    print("Duration (ms): {}\n", .{match.header.wall_clock_time * 1000});
    print("Player Count: {}\n", .{match.header.player_count});
    // print("Gamemode: {}\n", .{match.header.gamemode});
    // print("Players:\n", .{});
    // for (match.players.items) |player| {
    //     print("  Player ID: {} Name: {s} Faction: {s}\n", .{ player.player_id, player.name, player.faction });
    // }
    // print("Ally Teams:\n", .{});
    // for (match.ally_teams.items) |ally_team| {
    //     print("  Ally Team ID: {} Won: {} Player Count: {}\n", .{ ally_team.ally_team_id, ally_team.won, ally_team.player_count });
    // }
    // print("Spectators:\n", .{});
    // for (match.spectators.items) |spectator| {
    //     print("  Spectator ID: {} Name: {s} User ID: {}\n", .{ spectator.player_id, spectator.name, spectator.user_id });
    // }
    // print("Chat Messages:\n", .{});
    // for (match.chat_messages.items) |msg| {
    //     print("  From: {} To: {} Message: {s} Timestamp: {}\n", .{ msg.from_id, msg.to_id, msg.message, msg.game_timestamp });
    // }
    // print("Team Deaths:\n", .{});
    // for (match.team_deaths.items) |death| {
    //     print("  Team ID: {} Reason: {} Game Time: {}\n", .{ death.team_id, death.reason, death.game_time });
    // }
    // print("AI Players:\n", .{});
    // for (match.ai_players.items) |ai| {
    //     print("  AI ID: {} Team ID: {} Name: {s}\n", .{ ai.ai_id, ai.team_id, ai.name });
    // }
    print("Demofile Parser completed successfully\n", .{});
}
