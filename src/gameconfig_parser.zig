const std = @import("std");
const ArrayList = std.ArrayList;
const HashMap = std.HashMap;
const Allocator = std.mem.Allocator;

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
    startpos: ?[]f32 = null,

    fn writeToJson(self: *const Player, writer: anytype) !void {
        try writer.print("{{\"id\":{d},\"team\":", .{self.id});
        if (self.team) |team| {
            try writer.print("{d}", .{team});
        } else {
            try writer.writeAll("null");
        }
        try writer.writeAll(",\"countrycode\":");
        if (self.countrycode) |cc| {
            try writer.print("\"{s}\"", .{cc});
        } else {
            try writer.writeAll("null");
        }
        try writer.writeAll(",\"accountid\":");
        if (self.accountid) |aid| {
            try writer.print("{d}", .{aid});
        } else {
            try writer.writeAll("null");
        }
        try writer.writeAll(",\"name\":");
        if (self.name) |name| {
            try writer.print("\"{s}\"", .{name});
        } else {
            try writer.writeAll("null");
        }
        try writer.writeAll(",\"rank\":");
        if (self.rank) |rank| {
            try writer.print("{d}", .{rank});
        } else {
            try writer.writeAll("null");
        }
        try writer.writeAll(",\"skill\":");
        if (self.skill) |skill| {
            try writer.writeByte('[');
            for (skill, 0..) |v, i| {
                if (i > 0) try writer.writeByte(',');
                try writer.print("{d:.6}", .{v});
            }
            try writer.writeByte(']');
        } else {
            try writer.writeAll("null");
        }
        try writer.writeAll(",\"spectator\":");
        if (self.spectator) |spec| {
            try writer.print("{d}", .{spec});
        } else {
            try writer.writeAll("null");
        }
        try writer.writeAll(",\"skilluncertainty\":");
        if (self.skilluncertainty) |su| {
            try writer.print("{d:.6}", .{su});
        } else {
            try writer.writeAll("null");
        }
        try writer.writeAll(",\"startpos\":");
        if (self.startpos) |pos| {
            try writer.writeByte('[');
            for (pos, 0..) |v, i| {
                if (i > 0) try writer.writeByte(',');
                try writer.print("{d:.6}", .{v});
            }
            try writer.writeByte(']');
        } else {
            try writer.writeAll("null");
        }
        try writer.writeByte('}');
    }
};

const Team = struct {
    id: u32,
    allyteam: ?u32 = null,
    teamleader: ?u32 = null,
    rgbcolor: ?[]f64 = null,
    side: ?[]const u8 = null,
    handicap: ?u32 = null,

    fn writeToJson(self: *const Team, writer: anytype) !void {
        try writer.print("{{\"id\":{d},\"allyteam\":", .{self.id});
        if (self.allyteam) |at| {
            try writer.print("{d}", .{at});
        } else {
            try writer.writeAll("null");
        }
        try writer.writeAll(",\"teamleader\":");
        if (self.teamleader) |tl| {
            try writer.print("{d}", .{tl});
        } else {
            try writer.writeAll("null");
        }
        try writer.writeAll(",\"rgbcolor\":");
        if (self.rgbcolor) |color| {
            try writer.writeByte('[');
            for (color, 0..) |v, i| {
                if (i > 0) try writer.writeByte(',');
                try writer.print("{d:.6}", .{v});
            }
            try writer.writeByte(']');
        } else {
            try writer.writeAll("null");
        }
        try writer.writeAll(",\"side\":");
        if (self.side) |side| {
            try writer.print("\"{s}\"", .{side});
        } else {
            try writer.writeAll("null");
        }
        try writer.writeAll(",\"handicap\":");
        if (self.handicap) |hc| {
            try writer.print("{d}", .{hc});
        } else {
            try writer.writeAll("null");
        }
        try writer.writeByte('}');
    }
};

const AllyTeam = struct {
    id: u32,
    startrectleft: ?f64 = null,
    startrectright: ?f64 = null,
    startrectbottom: ?f64 = null,
    startrecttop: ?f64 = null,
    numallies: ?u32 = null,

    fn writeToJson(self: *const AllyTeam, writer: anytype) !void {
        try writer.print("{{\"id\":{d},\"startrectleft\":", .{self.id});
        if (self.startrectleft) |v| {
            try writer.print("{d:.6}", .{v});
        } else {
            try writer.writeAll("null");
        }
        try writer.writeAll(",\"startrectright\":");
        if (self.startrectright) |v| {
            try writer.print("{d:.6}", .{v});
        } else {
            try writer.writeAll("null");
        }
        try writer.writeAll(",\"startrectbottom\":");
        if (self.startrectbottom) |v| {
            try writer.print("{d:.6}", .{v});
        } else {
            try writer.writeAll("null");
        }
        try writer.writeAll(",\"startrecttop\":");
        if (self.startrecttop) |v| {
            try writer.print("{d:.6}", .{v});
        } else {
            try writer.writeAll("null");
        }
        try writer.writeAll(",\"numallies\":");
        if (self.numallies) |v| {
            try writer.print("{d}", .{v});
        } else {
            try writer.writeAll("null");
        }
        try writer.writeByte('}');
    }
};

const StringMap = HashMap([]const u8, []const u8, std.hash_map.StringContext, std.hash_map.default_max_load_percentage);

pub const GameConfig = struct {
    players: ArrayList(Player),
    teams: ArrayList(Team),
    allyteams: ArrayList(AllyTeam),
    modoptions: ?StringMap = null,
    mapoptions: ?StringMap = null,
    hostoptions: ?StringMap = null,
    restrict: ?StringMap = null,
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
    arena: std.heap.ArenaAllocator,

    pub fn init(allocator: Allocator) GameConfig {
        return GameConfig{
            .players = ArrayList(Player).init(allocator),
            .teams = ArrayList(Team).init(allocator),
            .allyteams = ArrayList(AllyTeam).init(allocator),
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
    }

    pub fn deinit(self: *GameConfig) void {
        self.players.deinit();
        self.teams.deinit();
        self.allyteams.deinit();
        if (self.modoptions) |*map| map.deinit();
        if (self.mapoptions) |*map| map.deinit();
        if (self.hostoptions) |*map| map.deinit();
        if (self.restrict) |*map| map.deinit();
        self.arena.deinit();
    }

    pub fn toJson(self: *const GameConfig, allocator: Allocator) ![]u8 {
        const estimated_size = 4096 + (self.players.items.len * 512) + (self.teams.items.len * 256) + (self.allyteams.items.len * 256);
        var json = try ArrayList(u8).initCapacity(allocator, estimated_size);
        const writer = json.writer();

        try writer.writeAll("{\"players\":[");
        for (self.players.items, 0..) |*player, i| {
            if (i > 0) try writer.writeByte(',');
            try player.writeToJson(writer);
        }
        try writer.writeAll("],\"teams\":[");
        for (self.teams.items, 0..) |*team, i| {
            if (i > 0) try writer.writeByte(',');
            try team.writeToJson(writer);
        }
        try writer.writeAll("],\"allyteams\":[");
        for (self.allyteams.items, 0..) |*allyteam, i| {
            if (i > 0) try writer.writeByte(',');
            try allyteam.writeToJson(writer);
        }
        try writer.writeAll("],");

        try self.writeOptionsSection(writer, "modoptions", self.modoptions);
        try writer.writeByte(',');
        try self.writeOptionsSection(writer, "mapoptions", self.mapoptions);
        try writer.writeByte(',');
        try self.writeOptionsSection(writer, "hostoptions", self.hostoptions);
        try writer.writeByte(',');
        try self.writeOptionsSection(writer, "restrict", self.restrict);
        try writer.writeByte(',');

        try writer.writeAll("\"ishost\":");
        if (self.ishost) |v| try writer.print("{d}", .{v}) else try writer.writeAll("null");
        try writer.writeAll(",\"hostip\":");
        if (self.hostip) |v| try writer.print("\"{s}\"", .{v}) else try writer.writeAll("null");
        try writer.writeAll(",\"numallyteams\":");
        if (self.numallyteams) |v| try writer.print("{d}", .{v}) else try writer.writeAll("null");
        try writer.writeAll(",\"server_match_id\":");
        if (self.server_match_id) |v| try writer.print("{d}", .{v}) else try writer.writeAll("null");
        try writer.writeAll(",\"numteams\":");
        if (self.numteams) |v| try writer.print("{d}", .{v}) else try writer.writeAll("null");
        try writer.writeAll(",\"startpostype\":");
        if (self.startpostype) |v| try writer.print("{d}", .{v}) else try writer.writeAll("null");
        try writer.writeAll(",\"gametype\":");
        if (self.gametype) |v| try writer.print("\"{s}\"", .{v}) else try writer.writeAll("null");
        try writer.writeAll(",\"hosttype\":");
        if (self.hosttype) |v| try writer.print("\"{s}\"", .{v}) else try writer.writeAll("null");
        try writer.writeAll(",\"mapname\":");
        if (self.mapname) |v| try writer.print("\"{s}\"", .{v}) else try writer.writeAll("null");
        try writer.writeAll(",\"autohostport\":");
        if (self.autohostport) |v| try writer.print("{d}", .{v}) else try writer.writeAll("null");
        try writer.writeAll(",\"numrestrictions\":");
        if (self.numrestrictions) |v| try writer.print("{d}", .{v}) else try writer.writeAll("null");
        try writer.writeAll(",\"autohostname\":");
        if (self.autohostname) |v| try writer.print("\"{s}\"", .{v}) else try writer.writeAll("null");
        try writer.writeAll(",\"autohostrank\":");
        if (self.autohostrank) |v| try writer.print("{d}", .{v}) else try writer.writeAll("null");
        try writer.writeAll(",\"autohostaccountid\":");
        if (self.autohostaccountid) |v| try writer.print("{d}", .{v}) else try writer.writeAll("null");
        try writer.writeAll(",\"numplayers\":");
        if (self.numplayers) |v| try writer.print("{d}", .{v}) else try writer.writeAll("null");
        try writer.writeAll(",\"autohostcountrycode\":");
        if (self.autohostcountrycode) |v| try writer.print("\"{s}\"", .{v}) else try writer.writeAll("null");
        try writer.writeAll(",\"hostport\":");
        if (self.hostport) |v| try writer.print("{d}", .{v}) else try writer.writeAll("null");
        try writer.writeByte('}');

        return json.toOwnedSlice();
    }

    fn writeOptionsSection(self: *const GameConfig, writer: anytype, name: []const u8, map: ?StringMap) !void {
        _ = self;
        try writer.print("\"{s}\":", .{name});
        if (map) |*m| {
            try writer.writeByte('{');
            var iterator = m.iterator();
            var first = true;
            while (iterator.next()) |entry| {
                if (!first) try writer.writeByte(',');
                first = false;
                try writer.print("\"{s}\":\"{s}\"", .{ entry.key_ptr.*, entry.value_ptr.* });
            }
            try writer.writeByte('}');
        } else {
            try writer.writeAll("{}");
        }
    }
};

const GameConfigParser = struct {
    config: *GameConfig,

    fn parseKeyValue(self: *GameConfigParser, section: []const u8, key: []const u8, value: []const u8, current_map: ?*StringMap) !void {
        if (std.mem.startsWith(u8, section, "player")) {
            const player_id = try std.fmt.parseInt(u32, section[6..], 10);
            try self.parsePlayer(player_id, key, value);
        } else if (std.mem.startsWith(u8, section, "team")) {
            const team_id = try std.fmt.parseInt(u32, section[4..], 10);
            try self.parseTeam(team_id, key, value);
        } else if (std.mem.startsWith(u8, section, "allyteam")) {
            const allyteam_id = try std.fmt.parseInt(u32, section[8..], 10);
            try self.parseAllyTeam(allyteam_id, key, value);
        } else if (current_map) |map| {
            const arena = self.config.arena.allocator();
            const key_copy = try arena.dupe(u8, key);
            const value_copy = try arena.dupe(u8, value);
            try map.put(key_copy, value_copy);
        }
    }

    fn parseGlobalKeyValue(self: *GameConfigParser, key: []const u8, value: []const u8) !void {
        const arena = self.config.arena.allocator();
        const GlobalField = enum { ishost, hostip, numallyteams, server_match_id, numteams, startpostype, gametype, hosttype, mapname, autohostport, numrestrictions, autohostname, autohostrank, autohostaccountid, numplayers, autohostcountrycode, hostport };
        const field = std.meta.stringToEnum(GlobalField, key) orelse return;

        switch (field) {
            .ishost => self.config.ishost = try std.fmt.parseInt(u32, value, 10),
            .hostip => self.config.hostip = try arena.dupe(u8, value),
            .numallyteams => self.config.numallyteams = try std.fmt.parseInt(u32, value, 10),
            .server_match_id => self.config.server_match_id = try std.fmt.parseInt(u32, value, 10),
            .numteams => self.config.numteams = try std.fmt.parseInt(u32, value, 10),
            .startpostype => self.config.startpostype = try std.fmt.parseInt(u32, value, 10),
            .gametype => self.config.gametype = try arena.dupe(u8, value),
            .hosttype => self.config.hosttype = try arena.dupe(u8, value),
            .mapname => self.config.mapname = try arena.dupe(u8, value),
            .autohostport => self.config.autohostport = try std.fmt.parseInt(u32, value, 10),
            .numrestrictions => self.config.numrestrictions = try std.fmt.parseInt(u32, value, 10),
            .autohostname => self.config.autohostname = try arena.dupe(u8, value),
            .autohostrank => self.config.autohostrank = try std.fmt.parseInt(u32, value, 10),
            .autohostaccountid => self.config.autohostaccountid = try std.fmt.parseInt(u32, value, 10),
            .numplayers => self.config.numplayers = try std.fmt.parseInt(u32, value, 10),
            .autohostcountrycode => self.config.autohostcountrycode = try arena.dupe(u8, value),
            .hostport => self.config.hostport = try std.fmt.parseInt(u32, value, 10),
        }
    }

    fn parsePlayer(self: *GameConfigParser, player_id: u32, key: []const u8, value: []const u8) !void {
        var player_index: ?usize = null;
        for (self.config.players.items, 0..) |*player, i| {
            if (player.id == player_id) {
                player_index = i;
                break;
            }
        }

        if (player_index == null) {
            try self.config.players.append(Player{ .id = player_id });
            player_index = self.config.players.items.len - 1;
        }

        var player = &self.config.players.items[player_index.?];
        const arena = self.config.arena.allocator();

        const PlayerField = enum { team, countrycode, accountid, name, rank, skill, spectator, skilluncertainty };
        const field = std.meta.stringToEnum(PlayerField, key) orelse return;

        switch (field) {
            .team => player.team = try std.fmt.parseInt(u32, value, 10),
            .countrycode => player.countrycode = try arena.dupe(u8, value),
            .accountid => player.accountid = try std.fmt.parseInt(u32, value, 10),
            .name => player.name = try arena.dupe(u8, value),
            .rank => player.rank = try std.fmt.parseInt(u32, value, 10),
            .skill => player.skill = try self.parseFloatArray(value),
            .spectator => player.spectator = try std.fmt.parseInt(u32, value, 10),
            .skilluncertainty => player.skilluncertainty = try std.fmt.parseFloat(f64, value),
        }
    }

    fn parseTeam(self: *GameConfigParser, team_id: u32, key: []const u8, value: []const u8) !void {
        var team_index: ?usize = null;
        for (self.config.teams.items, 0..) |*team, i| {
            if (team.id == team_id) {
                team_index = i;
                break;
            }
        }

        if (team_index == null) {
            try self.config.teams.append(Team{ .id = team_id });
            team_index = self.config.teams.items.len - 1;
        }

        var team = &self.config.teams.items[team_index.?];
        const arena = self.config.arena.allocator();

        const TeamField = enum { allyteam, teamleader, rgbcolor, side, handicap };
        const field = std.meta.stringToEnum(TeamField, key) orelse return;

        switch (field) {
            .allyteam => team.allyteam = try std.fmt.parseInt(u32, value, 10),
            .teamleader => team.teamleader = try std.fmt.parseInt(u32, value, 10),
            .rgbcolor => team.rgbcolor = try self.parseFloatArray(value),
            .side => team.side = try arena.dupe(u8, value),
            .handicap => team.handicap = try std.fmt.parseInt(u32, value, 10),
        }
    }

    fn parseAllyTeam(self: *GameConfigParser, allyteam_id: u32, key: []const u8, value: []const u8) !void {
        var allyteam_index: ?usize = null;
        for (self.config.allyteams.items, 0..) |*allyteam, i| {
            if (allyteam.id == allyteam_id) {
                allyteam_index = i;
                break;
            }
        }

        if (allyteam_index == null) {
            try self.config.allyteams.append(AllyTeam{ .id = allyteam_id });
            allyteam_index = self.config.allyteams.items.len - 1;
        }

        var allyteam = &self.config.allyteams.items[allyteam_index.?];

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

    fn parseFloatArray(self: *GameConfigParser, value: []const u8) ![]f64 {
        var trimmed = std.mem.trim(u8, value, " \t");
        if (trimmed.len >= 2 and trimmed[0] == '[' and trimmed[trimmed.len - 1] == ']') {
            trimmed = trimmed[1 .. trimmed.len - 1];
        }

        const arena = self.config.arena.allocator();
        var result = ArrayList(f64).init(arena);

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

    fn parse(self: *GameConfigParser, script: []const u8) !void {
        var lines = std.mem.splitSequence(u8, script, "\n");
        var current_section: ?[]const u8 = null;
        var current_map: ?*StringMap = null;
        var in_section = false;

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r\n");
            if (trimmed.len == 0) continue;

            if (trimmed[0] == '[' and trimmed[trimmed.len - 1] == ']') {
                const section_name = trimmed[1 .. trimmed.len - 1];
                current_section = section_name;
                in_section = true;
                current_map = null;

                if (std.mem.eql(u8, section_name, "modoptions")) {
                    self.config.modoptions = StringMap.init(self.config.allocator);
                    current_map = &self.config.modoptions.?;
                } else if (std.mem.eql(u8, section_name, "mapoptions")) {
                    self.config.mapoptions = StringMap.init(self.config.allocator);
                    current_map = &self.config.mapoptions.?;
                } else if (std.mem.eql(u8, section_name, "hostoptions")) {
                    self.config.hostoptions = StringMap.init(self.config.allocator);
                    current_map = &self.config.hostoptions.?;
                } else if (std.mem.eql(u8, section_name, "restrict")) {
                    self.config.restrict = StringMap.init(self.config.allocator);
                    current_map = &self.config.restrict.?;
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
                        try self.parseKeyValue(section, key, value, current_map);
                    }
                }
            } else {
                if (std.mem.indexOf(u8, trimmed, "=")) |eq_pos| {
                    const key = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
                    var value = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t");

                    if (value.len > 0 and value[value.len - 1] == ';') {
                        value = value[0 .. value.len - 1];
                    }

                    try self.parseGlobalKeyValue(key, value);
                }
            }
        }
    }
};

pub fn parseScript(allocator: Allocator, script: []const u8) !GameConfig {
    var config = GameConfig.init(allocator);
    var parser = GameConfigParser{ .config = &config };
    try parser.parse(script);
    return config;
}
