const std = @import("std");
const ArrayList = std.ArrayList;
const HashMap = std.HashMap;
const Allocator = std.mem.Allocator;
const print = std.debug.print;

// Pre-allocated string constants to avoid repeated allocations
const JSON_CONSTANTS = struct {
    const NULL_STR = "null";
    const EMPTY_OBJECT = "{}";
    const EMPTY_ARRAY = "[]";
};

// Optimized string writer with better buffer management
const OptimizedJsonWriter = struct {
    buffer: ArrayList(u8),

    pub fn init(allocator: Allocator, estimated_size: usize) !OptimizedJsonWriter {
        return OptimizedJsonWriter{
            .buffer = try ArrayList(u8).initCapacity(allocator, estimated_size),
        };
    }

    pub fn deinit(self: *OptimizedJsonWriter) void {
        self.buffer.deinit();
    }

    pub fn toOwnedSlice(self: *OptimizedJsonWriter) ![]u8 {
        return self.buffer.toOwnedSlice();
    }

    pub fn writer(self: *OptimizedJsonWriter) ArrayList(u8).Writer {
        return self.buffer.writer();
    }

    // Optimized methods for common JSON operations
    pub fn writeString(self: *OptimizedJsonWriter, str: []const u8) !void {
        try self.buffer.append('"');
        try self.buffer.appendSlice(str);
        try self.buffer.append('"');
    }

    pub fn writeFieldName(self: *OptimizedJsonWriter, name: []const u8) !void {
        try self.writeString(name);
        try self.buffer.append(':');
    }

    pub fn writeStringField(self: *OptimizedJsonWriter, name: []const u8, value: ?[]const u8) !void {
        try self.writeFieldName(name);
        if (value) |v| {
            try self.writeString(v);
        } else {
            try self.buffer.appendSlice(JSON_CONSTANTS.NULL_STR);
        }
    }

    pub fn writeNumberField(self: *OptimizedJsonWriter, name: []const u8, value: anytype) !void {
        try self.writeFieldName(name);
        try std.fmt.format(self.writer(), "{d}", .{value});
    }

    pub fn writeOptionalNumberField(self: *OptimizedJsonWriter, name: []const u8, value: anytype) !void {
        try self.writeFieldName(name);
        if (value) |v| {
            try std.fmt.format(self.writer(), "{d}", .{v});
        } else {
            try self.buffer.appendSlice(JSON_CONSTANTS.NULL_STR);
        }
    }

    pub fn writeFloatArrayField(self: *OptimizedJsonWriter, name: []const u8, value: ?[]f64) !void {
        try self.writeFieldName(name);
        if (value) |arr| {
            try self.buffer.append('[');
            for (arr, 0..) |v, i| {
                if (i > 0) try self.buffer.append(',');
                try std.fmt.format(self.writer(), "{d:.6}", .{v});
            }
            try self.buffer.append(']');
        } else {
            try self.buffer.appendSlice(JSON_CONSTANTS.NULL_STR);
        }
    }

    pub fn writeSeparator(self: *OptimizedJsonWriter) !void {
        try self.buffer.append(',');
    }

    pub fn writeObjectStart(self: *OptimizedJsonWriter) !void {
        try self.buffer.append('{');
    }

    pub fn writeObjectEnd(self: *OptimizedJsonWriter) !void {
        try self.buffer.append('}');
    }

    pub fn writeArrayStart(self: *OptimizedJsonWriter) !void {
        try self.buffer.append('[');
    }

    pub fn writeArrayEnd(self: *OptimizedJsonWriter) !void {
        try self.buffer.append(']');
    }
};

// String pool for efficient string management
const StringPool = struct {
    arena: std.heap.ArenaAllocator,

    pub fn init(backing_allocator: Allocator) StringPool {
        return StringPool{
            .arena = std.heap.ArenaAllocator.init(backing_allocator),
        };
    }

    pub fn deinit(self: *StringPool) void {
        self.arena.deinit();
    }

    pub fn allocator(self: *StringPool) Allocator {
        return self.arena.allocator();
    }

    pub fn dupeString(self: *StringPool, s: []const u8) ![]u8 {
        return self.arena.allocator().dupe(u8, s);
    }
};

// Optimized structures using string pool
const Player = struct {
    id: u32,
    team: ?u32 = null,
    countrycode: ?[]const u8 = null,
    accountid: ?u32 = null,
    name: ?[]const u8 = null,
    rank: ?u32 = null,
    skill: ?[]f64 = null,
    spectator: ?u32 = null,
    skilluncertainty: ?f64 = null,

    fn init(id: u32) Player {
        return Player{ .id = id };
    }

    // Optimized JSON writing
    fn writeToJson(self: *const Player, writer: *OptimizedJsonWriter) !void {
        try writer.writeObjectStart();
        try writer.writeNumberField("id", self.id);
        try writer.writeSeparator();
        try writer.writeOptionalNumberField("team", self.team);
        try writer.writeSeparator();
        try writer.writeStringField("countrycode", self.countrycode);
        try writer.writeSeparator();
        try writer.writeOptionalNumberField("accountid", self.accountid);
        try writer.writeSeparator();
        try writer.writeStringField("name", self.name);
        try writer.writeSeparator();
        try writer.writeOptionalNumberField("rank", self.rank);
        try writer.writeSeparator();
        try writer.writeFloatArrayField("skill", self.skill);
        try writer.writeSeparator();
        try writer.writeOptionalNumberField("spectator", self.spectator);
        try writer.writeSeparator();
        try writer.writeFieldName("skilluncertainty");
        if (self.skilluncertainty) |su| {
            try std.fmt.format(writer.writer(), "{d:.6}", .{su});
        } else {
            try writer.buffer.appendSlice(JSON_CONSTANTS.NULL_STR);
        }
        try writer.writeObjectEnd();
    }
};

const Team = struct {
    id: u32,
    allyteam: ?u32 = null,
    teamleader: ?u32 = null,
    rgbcolor: ?[]f64 = null,
    side: ?[]const u8 = null,
    handicap: ?u32 = null,

    fn init(id: u32) Team {
        return Team{ .id = id };
    }

    fn writeToJson(self: *const Team, writer: *OptimizedJsonWriter) !void {
        try writer.writeObjectStart();
        try writer.writeNumberField("id", self.id);
        try writer.writeSeparator();
        try writer.writeOptionalNumberField("allyteam", self.allyteam);
        try writer.writeSeparator();
        try writer.writeOptionalNumberField("teamleader", self.teamleader);
        try writer.writeSeparator();
        try writer.writeFloatArrayField("rgbcolor", self.rgbcolor);
        try writer.writeSeparator();
        try writer.writeStringField("side", self.side);
        try writer.writeSeparator();
        try writer.writeOptionalNumberField("handicap", self.handicap);
        try writer.writeObjectEnd();
    }
};

const AllyTeam = struct {
    id: u32,
    startrectleft: ?f64 = null,
    startrectright: ?f64 = null,
    startrectbottom: ?f64 = null,
    startrecttop: ?f64 = null,
    numallies: ?u32 = null,

    fn writeToJson(self: *const AllyTeam, writer: *OptimizedJsonWriter) !void {
        try writer.writeObjectStart();
        try writer.writeNumberField("id", self.id);
        try writer.writeSeparator();
        try writer.writeFieldName("startrectleft");
        if (self.startrectleft) |v| {
            try std.fmt.format(writer.writer(), "{d:.6}", .{v});
        } else {
            try writer.buffer.appendSlice(JSON_CONSTANTS.NULL_STR);
        }
        try writer.writeSeparator();
        try writer.writeFieldName("startrectright");
        if (self.startrectright) |v| {
            try std.fmt.format(writer.writer(), "{d:.6}", .{v});
        } else {
            try writer.buffer.appendSlice(JSON_CONSTANTS.NULL_STR);
        }
        try writer.writeSeparator();
        try writer.writeFieldName("startrectbottom");
        if (self.startrectbottom) |v| {
            try std.fmt.format(writer.writer(), "{d:.6}", .{v});
        } else {
            try writer.buffer.appendSlice(JSON_CONSTANTS.NULL_STR);
        }
        try writer.writeSeparator();
        try writer.writeFieldName("startrecttop");
        if (self.startrecttop) |v| {
            try std.fmt.format(writer.writer(), "{d:.6}", .{v});
        } else {
            try writer.buffer.appendSlice(JSON_CONSTANTS.NULL_STR);
        }
        try writer.writeSeparator();
        try writer.writeOptionalNumberField("numallies", self.numallies);
        try writer.writeObjectEnd();
    }
};

// Optimized string map with better memory management
const StringMap = HashMap([]const u8, []const u8, std.hash_map.StringContext, std.hash_map.default_max_load_percentage);

// Optimized GameConfig with string pool
pub const GameConfig = struct {
    players: ArrayList(Player),
    teams: ArrayList(Team),
    allyteams: ArrayList(AllyTeam),
    modoptions: ?StringMap = null,
    mapoptions: ?StringMap = null,
    hostoptions: ?StringMap = null,
    restrict: ?StringMap = null,

    // Global properties
    ishost: ?u32 = null,
    hostip: ?[]const u8 = null,
    numallyteams: ?u32 = null,
    server_match_id: ?u32 = null,
    numteams: ?u32 = null,
    startpostype: ?u32 = null,
    gametype: ?[]const u8 = null,
    hosttype: ?[]const u8 = null,
    mapname: ?[]const u8 = null,
    autohostport: ?u32 = null,
    numrestrictions: ?u32 = null,
    autohostname: ?[]const u8 = null,
    autohostrank: ?u32 = null,
    autohostaccountid: ?u32 = null,
    numplayers: ?u32 = null,
    autohostcountrycode: ?[]const u8 = null,
    hostport: ?u32 = null,

    allocator: Allocator,
    string_pool: StringPool,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .players = ArrayList(Player).init(allocator),
            .teams = ArrayList(Team).init(allocator),
            .allyteams = ArrayList(AllyTeam).init(allocator),
            .allocator = allocator,
            .string_pool = StringPool.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.players.deinit();
        self.teams.deinit();
        self.allyteams.deinit();

        if (self.modoptions) |*map| {
            map.deinit();
        }
        if (self.mapoptions) |*map| {
            map.deinit();
        }
        if (self.hostoptions) |*map| {
            map.deinit();
        }
        if (self.restrict) |*map| {
            map.deinit();
        }

        self.string_pool.deinit();
    }

    // Highly optimized JSON generation
    pub fn toJson(self: *const Self, allocator: Allocator) ![]u8 {
        // Estimate size more accurately
        const estimated_size = 1024 +
            (self.players.items.len * 512) +
            (self.teams.items.len * 256) +
            (self.allyteams.items.len * 256) +
            (if (self.modoptions) |*map| map.count() * 64 else 0) +
            (if (self.mapoptions) |*map| map.count() * 64 else 0) +
            (if (self.hostoptions) |*map| map.count() * 64 else 0) +
            (if (self.restrict) |*map| map.count() * 64 else 0);

        var writer = try OptimizedJsonWriter.init(allocator, estimated_size);
        defer writer.deinit();

        try writer.writeObjectStart();

        // Players section
        try writer.writeFieldName("players");
        try writer.writeArrayStart();
        for (self.players.items, 0..) |*player, i| {
            if (i > 0) try writer.writeSeparator();
            try player.writeToJson(&writer);
        }
        try writer.writeArrayEnd();
        try writer.writeSeparator();

        // Teams section
        try writer.writeFieldName("teams");
        try writer.writeArrayStart();
        for (self.teams.items, 0..) |*team, i| {
            if (i > 0) try writer.writeSeparator();
            try team.writeToJson(&writer);
        }
        try writer.writeArrayEnd();
        try writer.writeSeparator();

        // Allyteams section
        try writer.writeFieldName("allyteams");
        try writer.writeArrayStart();
        for (self.allyteams.items, 0..) |*allyteam, i| {
            if (i > 0) try writer.writeSeparator();
            try allyteam.writeToJson(&writer);
        }
        try writer.writeArrayEnd();
        try writer.writeSeparator();

        // Option sections - optimized
        try self.writeOptionsSection(&writer, "modoptions", self.modoptions);
        try writer.writeSeparator();
        try self.writeOptionsSection(&writer, "mapoptions", self.mapoptions);
        try writer.writeSeparator();
        try self.writeOptionsSection(&writer, "hostoptions", self.hostoptions);
        try writer.writeSeparator();
        try self.writeOptionsSection(&writer, "restrict", self.restrict);
        try writer.writeSeparator();

        // Global properties - batch write
        try self.writeGlobalProperties(&writer);

        try writer.writeObjectEnd();
        return writer.toOwnedSlice();
    }

    fn writeOptionsSection(self: *const Self, writer: *OptimizedJsonWriter, name: []const u8, map: ?StringMap) !void {
        _ = self;
        try writer.writeFieldName(name);
        if (map) |*m| {
            try writer.writeObjectStart();
            var iterator = m.iterator();
            var first = true;
            while (iterator.next()) |entry| {
                if (!first) try writer.writeSeparator();
                first = false;
                try writer.writeString(entry.key_ptr.*);
                try writer.buffer.append(':');
                try writer.writeString(entry.value_ptr.*);
            }
            try writer.writeObjectEnd();
        } else {
            try writer.buffer.appendSlice(JSON_CONSTANTS.EMPTY_OBJECT);
        }
    }

    fn writeGlobalProperties(self: *const Self, writer: *OptimizedJsonWriter) !void {
        try writer.writeOptionalNumberField("ishost", self.ishost);
        try writer.writeSeparator();
        try writer.writeStringField("hostip", self.hostip);
        try writer.writeSeparator();
        try writer.writeOptionalNumberField("numallyteams", self.numallyteams);
        try writer.writeSeparator();
        try writer.writeOptionalNumberField("server_match_id", self.server_match_id);
        try writer.writeSeparator();
        try writer.writeOptionalNumberField("numteams", self.numteams);
        try writer.writeSeparator();
        try writer.writeOptionalNumberField("startpostype", self.startpostype);
        try writer.writeSeparator();
        try writer.writeStringField("gametype", self.gametype);
        try writer.writeSeparator();
        try writer.writeStringField("hosttype", self.hosttype);
        try writer.writeSeparator();
        try writer.writeStringField("mapname", self.mapname);
        try writer.writeSeparator();
        try writer.writeOptionalNumberField("autohostport", self.autohostport);
        try writer.writeSeparator();
        try writer.writeOptionalNumberField("numrestrictions", self.numrestrictions);
        try writer.writeSeparator();
        try writer.writeStringField("autohostname", self.autohostname);
        try writer.writeSeparator();
        try writer.writeOptionalNumberField("autohostrank", self.autohostrank);
        try writer.writeSeparator();
        try writer.writeOptionalNumberField("autohostaccountid", self.autohostaccountid);
        try writer.writeSeparator();
        try writer.writeOptionalNumberField("numplayers", self.numplayers);
        try writer.writeSeparator();
        try writer.writeStringField("autohostcountrycode", self.autohostcountrycode);
        try writer.writeSeparator();
        try writer.writeOptionalNumberField("hostport", self.hostport);
    }
};

// Optimized parser with better string handling
const GameConfigParser = struct {
    allocator: Allocator,
    string_pool: *StringPool,

    const Self = @This();

    pub fn init(allocator: Allocator, string_pool: *StringPool) Self {
        return Self{
            .allocator = allocator,
            .string_pool = string_pool,
        };
    }

    pub fn parse(self: *Self, script: []const u8, config: *GameConfig) !void {
        var lines = std.mem.splitSequence(u8, script, "\n");
        var current_section: ?[]const u8 = null;
        var current_map: ?*StringMap = null;
        var in_section = false;

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r\n");
            if (trimmed.len == 0) continue;

            if (trimmed[0] == '[' and trimmed[trimmed.len - 1] == ']') {
                // Section header
                const section_name = trimmed[1 .. trimmed.len - 1];
                current_section = section_name;
                in_section = true;
                current_map = null;

                // Initialize section-specific storage
                if (std.mem.eql(u8, section_name, "modoptions")) {
                    config.modoptions = StringMap.init(self.allocator);
                    current_map = &config.modoptions.?;
                } else if (std.mem.eql(u8, section_name, "mapoptions")) {
                    config.mapoptions = StringMap.init(self.allocator);
                    current_map = &config.mapoptions.?;
                } else if (std.mem.eql(u8, section_name, "hostoptions")) {
                    config.hostoptions = StringMap.init(self.allocator);
                    current_map = &config.hostoptions.?;
                } else if (std.mem.eql(u8, section_name, "restrict")) {
                    config.restrict = StringMap.init(self.allocator);
                    current_map = &config.restrict.?;
                }
            } else if (trimmed[0] == '{') {
                continue;
            } else if (trimmed[0] == '}') {
                in_section = false;
                current_section = null;
                current_map = null;
            } else if (in_section) {
                if (std.mem.indexOf(u8, trimmed, "=")) |eq_pos| {
                    const key = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
                    var value = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t");

                    if (value.len > 0 and value[value.len - 1] == ';') {
                        value = value[0 .. value.len - 1];
                    }

                    if (current_section) |section| {
                        try self.parseKeyValue(config, section, key, value, current_map);
                    }
                }
            } else {
                if (std.mem.indexOf(u8, trimmed, "=")) |eq_pos| {
                    const key = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
                    var value = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t");

                    if (value.len > 0 and value[value.len - 1] == ';') {
                        value = value[0 .. value.len - 1];
                    }

                    try self.parseGlobalKeyValue(config, key, value);
                }
            }
        }
    }

    fn parseKeyValue(self: *Self, config: *GameConfig, section: []const u8, key: []const u8, value: []const u8, current_map: ?*StringMap) !void {
        if (std.mem.startsWith(u8, section, "player")) {
            const player_id = try std.fmt.parseInt(u32, section[6..], 10);
            try self.parsePlayer(config, player_id, key, value);
        } else if (std.mem.startsWith(u8, section, "team")) {
            const team_id = try std.fmt.parseInt(u32, section[4..], 10);
            try self.parseTeam(config, team_id, key, value);
        } else if (std.mem.startsWith(u8, section, "allyteam")) {
            const allyteam_id = try std.fmt.parseInt(u32, section[8..], 10);
            try parseAllyTeam(config, allyteam_id, key, value);
        } else if (current_map) |map| {
            const key_copy = try self.string_pool.dupeString(key);
            const value_copy = try self.string_pool.dupeString(value);
            try map.put(key_copy, value_copy);
        }
    }

    fn parseGlobalKeyValue(self: *Self, config: *GameConfig, key: []const u8, value: []const u8) !void {
        // Use string interning for better performance
        const GlobalField = enum {
            ishost,
            hostip,
            numallyteams,
            server_match_id,
            numteams,
            startpostype,
            gametype,
            hosttype,
            mapname,
            autohostport,
            numrestrictions,
            autohostname,
            autohostrank,
            autohostaccountid,
            numplayers,
            autohostcountrycode,
            hostport,
        };

        const field = std.meta.stringToEnum(GlobalField, key) orelse return;

        switch (field) {
            .ishost => config.ishost = try std.fmt.parseInt(u32, value, 10),
            .hostip => config.hostip = try self.string_pool.dupeString(value),
            .numallyteams => config.numallyteams = try std.fmt.parseInt(u32, value, 10),
            .server_match_id => config.server_match_id = try std.fmt.parseInt(u32, value, 10),
            .numteams => config.numteams = try std.fmt.parseInt(u32, value, 10),
            .startpostype => config.startpostype = try std.fmt.parseInt(u32, value, 10),
            .gametype => config.gametype = try self.string_pool.dupeString(value),
            .hosttype => config.hosttype = try self.string_pool.dupeString(value),
            .mapname => config.mapname = try self.string_pool.dupeString(value),
            .autohostport => config.autohostport = try std.fmt.parseInt(u32, value, 10),
            .numrestrictions => config.numrestrictions = try std.fmt.parseInt(u32, value, 10),
            .autohostname => config.autohostname = try self.string_pool.dupeString(value),
            .autohostrank => config.autohostrank = try std.fmt.parseInt(u32, value, 10),
            .autohostaccountid => config.autohostaccountid = try std.fmt.parseInt(u32, value, 10),
            .numplayers => config.numplayers = try std.fmt.parseInt(u32, value, 10),
            .autohostcountrycode => config.autohostcountrycode = try self.string_pool.dupeString(value),
            .hostport => config.hostport = try std.fmt.parseInt(u32, value, 10),
        }
    }

    fn parsePlayer(self: *Self, config: *GameConfig, player_id: u32, key: []const u8, value: []const u8) !void {
        var player_index: ?usize = null;
        for (config.players.items, 0..) |*player, i| {
            if (player.id == player_id) {
                player_index = i;
                break;
            }
        }

        if (player_index == null) {
            try config.players.append(Player.init(player_id));
            player_index = config.players.items.len - 1;
        }

        var player = &config.players.items[player_index.?];

        const PlayerField = enum { team, countrycode, accountid, name, rank, skill, spectator, skilluncertainty };
        const field = std.meta.stringToEnum(PlayerField, key) orelse return;

        switch (field) {
            .team => player.team = try std.fmt.parseInt(u32, value, 10),
            .countrycode => player.countrycode = try self.string_pool.dupeString(value),
            .accountid => player.accountid = try std.fmt.parseInt(u32, value, 10),
            .name => player.name = try self.string_pool.dupeString(value),
            .rank => player.rank = try std.fmt.parseInt(u32, value, 10),
            .skill => player.skill = try self.parseFloatArray(value),
            .spectator => player.spectator = try std.fmt.parseInt(u32, value, 10),
            .skilluncertainty => player.skilluncertainty = try std.fmt.parseFloat(f64, value),
        }
    }

    fn parseTeam(self: *Self, config: *GameConfig, team_id: u32, key: []const u8, value: []const u8) !void {
        var team_index: ?usize = null;
        for (config.teams.items, 0..) |*team, i| {
            if (team.id == team_id) {
                team_index = i;
                break;
            }
        }

        if (team_index == null) {
            try config.teams.append(Team.init(team_id));
            team_index = config.teams.items.len - 1;
        }

        var team = &config.teams.items[team_index.?];

        const TeamField = enum { allyteam, teamleader, rgbcolor, side, handicap };
        const field = std.meta.stringToEnum(TeamField, key) orelse return;

        switch (field) {
            .allyteam => team.allyteam = try std.fmt.parseInt(u32, value, 10),
            .teamleader => team.teamleader = try std.fmt.parseInt(u32, value, 10),
            .rgbcolor => team.rgbcolor = try self.parseFloatArray(value),
            .side => team.side = try self.string_pool.dupeString(value),
            .handicap => team.handicap = try std.fmt.parseInt(u32, value, 10),
        }
    }

    fn parseAllyTeam(config: *GameConfig, allyteam_id: u32, key: []const u8, value: []const u8) !void {
        var allyteam_index: ?usize = null;
        for (config.allyteams.items, 0..) |*allyteam, i| {
            if (allyteam.id == allyteam_id) {
                allyteam_index = i;
                break;
            }
        }

        if (allyteam_index == null) {
            try config.allyteams.append(AllyTeam{ .id = allyteam_id });
            allyteam_index = config.allyteams.items.len - 1;
        }

        var allyteam = &config.allyteams.items[allyteam_index.?];

        const AllyTeamField = enum { startrectleft, startrectright, startrectbottom, startrecttop, numallies };
        const field = std.meta.stringToEnum(AllyTeamField, key) orelse return;

        switch (field) {
            .startrectleft => allyteam.startrectleft = try std.fmt.parseFloat(f64, value),
            .startrectright => allyteam.startrectright = try std.fmt.parseFloat(f64, value),
            .startrectbottom => allyteam.startrectbottom = try std.fmt.parseFloat(f64, value),
            .startrecttop => allyteam.startrecttop = try std.fmt.parseFloat(f64, value),
            .numallies => allyteam.numallies = try std.fmt.parseInt(u32, value, 10),
        }
    }

    // Optimized float array parsing
    fn parseFloatArray(self: *Self, value: []const u8) ![]f64 {
        var trimmed = std.mem.trim(u8, value, " \t");

        if (trimmed.len >= 2 and trimmed[0] == '[' and trimmed[trimmed.len - 1] == ']') {
            trimmed = trimmed[1 .. trimmed.len - 1];
        }

        var result = ArrayList(f64).init(self.string_pool.allocator());

        // Check if it's space-separated (RGB colors) or comma-separated
        const has_spaces = std.mem.indexOf(u8, trimmed, " ") != null;
        const separator = if (has_spaces) " " else ",";

        var parts = std.mem.splitSequence(u8, trimmed, separator);
        while (parts.next()) |part| {
            const clean_part = std.mem.trim(u8, part, " \t,");
            if (clean_part.len > 0) {
                const float_val = try std.fmt.parseFloat(f64, clean_part);
                try result.append(float_val);
            }
        }

        return result.toOwnedSlice();
    }
};

// Optimized public interface
pub fn parseScript(allocator: Allocator, script: []const u8) !GameConfig {
    var config = GameConfig.init(allocator);
    var parser = GameConfigParser.init(allocator, &config.string_pool);
    try parser.parse(script, &config);
    return config;
}
