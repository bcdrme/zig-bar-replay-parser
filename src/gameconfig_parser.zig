const std = @import("std");
const ArrayList = std.ArrayList;
const HashMap = std.HashMap;
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const json = std.json;

// Serializable structures (no allocator or function pointers)
const SerializablePlayer = struct {
    id: u32,
    team: ?u32 = null,
    countrycode: ?[]const u8 = null,
    accountid: ?u32 = null,
    name: ?[]const u8 = null,
    rank: ?u32 = null,
    skill: ?[]f64 = null,
    spectator: ?u32 = null,
    skilluncertainty: ?f64 = null,
};

const SerializableTeam = struct {
    id: u32,
    allyteam: ?u32 = null,
    teamleader: ?u32 = null,
    rgbcolor: ?[]f64 = null,
    side: ?[]const u8 = null,
    handicap: ?u32 = null,
};

const SerializableAllyTeam = struct {
    id: u32,
    startrectleft: ?f64 = null,
    startrectright: ?f64 = null,
    startrectbottom: ?f64 = null,
    startrecttop: ?f64 = null,
    numallies: ?u32 = null,
};

const SerializableGameConfig = struct {
    players: []SerializablePlayer,
    teams: []SerializableTeam,
    allyteams: []SerializableAllyTeam,
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
};

// Player structure
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
    allocator: Allocator,

    fn init(allocator: Allocator, id: u32) Player {
        return Player{
            .id = id,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Player) void {
        if (self.countrycode) |code| {
            self.allocator.free(code);
        }
        if (self.name) |name| {
            self.allocator.free(name);
        }
        if (self.skill) |skill| {
            self.allocator.free(skill);
        }
    }

    fn toSerializable(self: *const Player) SerializablePlayer {
        return SerializablePlayer{
            .id = self.id,
            .team = self.team,
            .countrycode = self.countrycode,
            .accountid = self.accountid,
            .name = self.name,
            .rank = self.rank,
            .skill = self.skill,
            .spectator = self.spectator,
            .skilluncertainty = self.skilluncertainty,
        };
    }
};

// Team structure
const Team = struct {
    id: u32,
    allyteam: ?u32 = null,
    teamleader: ?u32 = null,
    rgbcolor: ?[]f64 = null,
    side: ?[]const u8 = null,
    handicap: ?u32 = null,
    allocator: Allocator,

    fn init(allocator: Allocator, id: u32) Team {
        return Team{
            .id = id,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Team) void {
        if (self.rgbcolor) |color| {
            self.allocator.free(color);
        }
        if (self.side) |side| {
            self.allocator.free(side);
        }
    }

    fn toSerializable(self: *const Team) SerializableTeam {
        return SerializableTeam{
            .id = self.id,
            .allyteam = self.allyteam,
            .teamleader = self.teamleader,
            .rgbcolor = self.rgbcolor,
            .side = self.side,
            .handicap = self.handicap,
        };
    }
};

// AllyTeam structure
const AllyTeam = struct {
    id: u32,
    startrectleft: ?f64 = null,
    startrectright: ?f64 = null,
    startrectbottom: ?f64 = null,
    startrecttop: ?f64 = null,
    numallies: ?u32 = null,

    fn toSerializable(self: *const AllyTeam) SerializableAllyTeam {
        return SerializableAllyTeam{
            .id = self.id,
            .startrectleft = self.startrectleft,
            .startrectright = self.startrectright,
            .startrectbottom = self.startrectbottom,
            .startrecttop = self.startrecttop,
            .numallies = self.numallies,
        };
    }
};

// Generic string map for flexible sections
const StringMap = HashMap([]const u8, []const u8, std.hash_map.StringContext, std.hash_map.default_max_load_percentage);

// Main game configuration structure
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

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .players = ArrayList(Player).init(allocator),
            .teams = ArrayList(Team).init(allocator),
            .allyteams = ArrayList(AllyTeam).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.players.items) |*player| {
            player.deinit();
        }
        self.players.deinit();
        for (self.teams.items) |*team| {
            team.deinit();
        }
        self.teams.deinit();
        self.allyteams.deinit();

        if (self.modoptions) |*map| {
            deinitStringMap(map, self.allocator);
        }
        if (self.mapoptions) |*map| {
            deinitStringMap(map, self.allocator);
        }
        if (self.hostoptions) |*map| {
            deinitStringMap(map, self.allocator);
        }
        if (self.restrict) |*map| {
            deinitStringMap(map, self.allocator);
        }

        // Free global string fields
        if (self.hostip) |hostip| {
            self.allocator.free(hostip);
        }
        if (self.gametype) |gametype| {
            self.allocator.free(gametype);
        }
        if (self.hosttype) |hosttype| {
            self.allocator.free(hosttype);
        }
        if (self.mapname) |mapname| {
            self.allocator.free(mapname);
        }
        if (self.autohostname) |autohostname| {
            self.allocator.free(autohostname);
        }
        if (self.autohostcountrycode) |autohostcountrycode| {
            self.allocator.free(autohostcountrycode);
        }
    }

    pub fn toJson(self: *const Self, allocator: Allocator) ![]u8 {
        return self.toJsonCustom(allocator);
    }

    fn toJsonCustom(self: *const Self, allocator: Allocator) ![]u8 {
        var json_str = ArrayList(u8).init(allocator);
        defer json_str.deinit();

        try json_str.appendSlice("{");

        // Players section
        try json_str.appendSlice("\"players\":[");
        for (self.players.items, 0..) |*player, i| {
            if (i > 0) try json_str.appendSlice(",");
            try self.writePlayer(&json_str, player);
        }
        try json_str.appendSlice("],");

        // Teams section
        try json_str.appendSlice("\"teams\":[");
        for (self.teams.items, 0..) |*team, i| {
            if (i > 0) try json_str.appendSlice(",");
            try self.writeTeam(&json_str, team);
        }
        try json_str.appendSlice("],");

        // Allyteams section
        try json_str.appendSlice("\"allyteams\":[");
        for (self.allyteams.items, 0..) |*allyteam, i| {
            if (i > 0) try json_str.appendSlice(",");
            try self.writeAllyTeam(&json_str, allyteam);
        }
        try json_str.appendSlice("],");

        // Modoptions section
        try json_str.appendSlice("\"modoptions\":");
        if (self.modoptions) |*map| {
            try self.writeKeyValueObject(&json_str, map);
        } else {
            try json_str.appendSlice("{}");
        }
        try json_str.appendSlice(",");

        // Mapoptions section
        try json_str.appendSlice("\"mapoptions\":");
        if (self.mapoptions) |*map| {
            try self.writeKeyValueObject(&json_str, map);
        } else {
            try json_str.appendSlice("{}");
        }
        try json_str.appendSlice(",");

        // Hostoptions section
        try json_str.appendSlice("\"hostoptions\":");
        if (self.hostoptions) |*map| {
            try self.writeKeyValueObject(&json_str, map);
        } else {
            try json_str.appendSlice("{}");
        }
        try json_str.appendSlice(",");

        // Restrict section
        try json_str.appendSlice("\"restrict\":");
        if (self.restrict) |*map| {
            try self.writeKeyValueObject(&json_str, map);
        } else {
            try json_str.appendSlice("{}");
        }
        try json_str.appendSlice(",");

        // Global properties
        try self.writeGlobalProperties(&json_str);

        try json_str.appendSlice("}");

        return json_str.toOwnedSlice();
    }

    fn writeKeyValueObject(self: *const Self, json_str: *ArrayList(u8), map: *const StringMap) !void {
        _ = self;
        try json_str.appendSlice("{");
        var iterator = map.iterator();
        var first = true;
        while (iterator.next()) |entry| {
            if (!first) try json_str.appendSlice(",");
            first = false;
            try json_str.appendSlice("\"");
            try json_str.appendSlice(entry.key_ptr.*);
            try json_str.appendSlice("\":\"");
            try json_str.appendSlice(entry.value_ptr.*);
            try json_str.appendSlice("\"");
        }
        try json_str.appendSlice("}");
    }

    fn writePlayer(self: *const Self, json_str: *ArrayList(u8), player: *const Player) !void {
        _ = self;
        try json_str.appendSlice("{");
        try json_str.appendSlice("\"id\":");
        try std.fmt.format(json_str.writer(), "{d}", .{player.id});

        if (player.team) |team| {
            try json_str.appendSlice(",\"team\":");
            try std.fmt.format(json_str.writer(), "{d}", .{team});
        } else {
            try json_str.appendSlice(",\"team\":null");
        }

        if (player.countrycode) |cc| {
            try json_str.appendSlice(",\"countrycode\":\"");
            try json_str.appendSlice(cc);
            try json_str.appendSlice("\"");
        } else {
            try json_str.appendSlice(",\"countrycode\":null");
        }

        if (player.accountid) |aid| {
            try json_str.appendSlice(",\"accountid\":");
            try std.fmt.format(json_str.writer(), "{d}", .{aid});
        } else {
            try json_str.appendSlice(",\"accountid\":null");
        }

        if (player.name) |name| {
            try json_str.appendSlice(",\"name\":\"");
            try json_str.appendSlice(name);
            try json_str.appendSlice("\"");
        } else {
            try json_str.appendSlice(",\"name\":null");
        }

        if (player.rank) |rank| {
            try json_str.appendSlice(",\"rank\":");
            try std.fmt.format(json_str.writer(), "{d}", .{rank});
        } else {
            try json_str.appendSlice(",\"rank\":null");
        }

        if (player.skill) |skill| {
            try json_str.appendSlice(",\"skill\":[");
            for (skill, 0..) |s, i| {
                if (i > 0) try json_str.appendSlice(",");
                try std.fmt.format(json_str.writer(), "{d:.6}", .{s});
            }
            try json_str.appendSlice("]");
        } else {
            try json_str.appendSlice(",\"skill\":null");
        }

        if (player.spectator) |spec| {
            try json_str.appendSlice(",\"spectator\":");
            try std.fmt.format(json_str.writer(), "{d}", .{spec});
        } else {
            try json_str.appendSlice(",\"spectator\":null");
        }

        if (player.skilluncertainty) |su| {
            try json_str.appendSlice(",\"skilluncertainty\":");
            try std.fmt.format(json_str.writer(), "{d:.6}", .{su});
        } else {
            try json_str.appendSlice(",\"skilluncertainty\":null");
        }

        try json_str.appendSlice("}");
    }

    fn writeTeam(self: *const Self, json_str: *ArrayList(u8), team: *const Team) !void {
        _ = self;
        try json_str.appendSlice("{");
        try json_str.appendSlice("\"id\":");
        try std.fmt.format(json_str.writer(), "{d}", .{team.id});

        if (team.allyteam) |at| {
            try json_str.appendSlice(",\"allyteam\":");
            try std.fmt.format(json_str.writer(), "{d}", .{at});
        } else {
            try json_str.appendSlice(",\"allyteam\":null");
        }

        if (team.teamleader) |tl| {
            try json_str.appendSlice(",\"teamleader\":");
            try std.fmt.format(json_str.writer(), "{d}", .{tl});
        } else {
            try json_str.appendSlice(",\"teamleader\":null");
        }

        if (team.rgbcolor) |color| {
            try json_str.appendSlice(",\"rgbcolor\":[");
            for (color, 0..) |c, i| {
                if (i > 0) try json_str.appendSlice(",");
                try std.fmt.format(json_str.writer(), "{d:.6}", .{c});
            }
            try json_str.appendSlice("]");
        } else {
            try json_str.appendSlice(",\"rgbcolor\":null");
        }

        if (team.side) |side| {
            try json_str.appendSlice(",\"side\":\"");
            try json_str.appendSlice(side);
            try json_str.appendSlice("\"");
        } else {
            try json_str.appendSlice(",\"side\":null");
        }

        if (team.handicap) |handicap| {
            try json_str.appendSlice(",\"handicap\":");
            try std.fmt.format(json_str.writer(), "{d}", .{handicap});
        } else {
            try json_str.appendSlice(",\"handicap\":null");
        }

        try json_str.appendSlice("}");
    }

    fn writeAllyTeam(self: *const Self, json_str: *ArrayList(u8), allyteam: *const AllyTeam) !void {
        _ = self;
        try json_str.appendSlice("{");
        try json_str.appendSlice("\"id\":");
        try std.fmt.format(json_str.writer(), "{d}", .{allyteam.id});

        if (allyteam.startrectleft) |srl| {
            try json_str.appendSlice(",\"startrectleft\":");
            try std.fmt.format(json_str.writer(), "{d:.6}", .{srl});
        } else {
            try json_str.appendSlice(",\"startrectleft\":null");
        }

        if (allyteam.startrectright) |srr| {
            try json_str.appendSlice(",\"startrectright\":");
            try std.fmt.format(json_str.writer(), "{d:.6}", .{srr});
        } else {
            try json_str.appendSlice(",\"startrectright\":null");
        }

        if (allyteam.startrectbottom) |srb| {
            try json_str.appendSlice(",\"startrectbottom\":");
            try std.fmt.format(json_str.writer(), "{d:.6}", .{srb});
        } else {
            try json_str.appendSlice(",\"startrectbottom\":null");
        }

        if (allyteam.startrecttop) |srt| {
            try json_str.appendSlice(",\"startrecttop\":");
            try std.fmt.format(json_str.writer(), "{d:.6}", .{srt});
        } else {
            try json_str.appendSlice(",\"startrecttop\":null");
        }

        if (allyteam.numallies) |na| {
            try json_str.appendSlice(",\"numallies\":");
            try std.fmt.format(json_str.writer(), "{d}", .{na});
        } else {
            try json_str.appendSlice(",\"numallies\":null");
        }

        try json_str.appendSlice("}");
    }

    fn writeGlobalProperties(self: *const Self, json_str: *ArrayList(u8)) !void {
        if (self.ishost) |ih| {
            try json_str.appendSlice("\"ishost\":");
            try std.fmt.format(json_str.writer(), "{d}", .{ih});
        } else {
            try json_str.appendSlice("\"ishost\":null");
        }

        if (self.hostip) |hip| {
            try json_str.appendSlice(",\"hostip\":\"");
            try json_str.appendSlice(hip);
            try json_str.appendSlice("\"");
        } else {
            try json_str.appendSlice(",\"hostip\":null");
        }

        if (self.numallyteams) |nat| {
            try json_str.appendSlice(",\"numallyteams\":");
            try std.fmt.format(json_str.writer(), "{d}", .{nat});
        } else {
            try json_str.appendSlice(",\"numallyteams\":null");
        }

        if (self.server_match_id) |smi| {
            try json_str.appendSlice(",\"server_match_id\":");
            try std.fmt.format(json_str.writer(), "{d}", .{smi});
        } else {
            try json_str.appendSlice(",\"server_match_id\":null");
        }

        if (self.numteams) |nt| {
            try json_str.appendSlice(",\"numteams\":");
            try std.fmt.format(json_str.writer(), "{d}", .{nt});
        } else {
            try json_str.appendSlice(",\"numteams\":null");
        }

        if (self.startpostype) |spt| {
            try json_str.appendSlice(",\"startpostype\":");
            try std.fmt.format(json_str.writer(), "{d}", .{spt});
        } else {
            try json_str.appendSlice(",\"startpostype\":null");
        }

        if (self.gametype) |gt| {
            try json_str.appendSlice(",\"gametype\":\"");
            try json_str.appendSlice(gt);
            try json_str.appendSlice("\"");
        } else {
            try json_str.appendSlice(",\"gametype\":null");
        }

        if (self.hosttype) |ht| {
            try json_str.appendSlice(",\"hosttype\":\"");
            try json_str.appendSlice(ht);
            try json_str.appendSlice("\"");
        } else {
            try json_str.appendSlice(",\"hosttype\":null");
        }

        if (self.mapname) |mn| {
            try json_str.appendSlice(",\"mapname\":\"");
            try json_str.appendSlice(mn);
            try json_str.appendSlice("\"");
        } else {
            try json_str.appendSlice(",\"mapname\":null");
        }

        if (self.autohostport) |ahp| {
            try json_str.appendSlice(",\"autohostport\":");
            try std.fmt.format(json_str.writer(), "{d}", .{ahp});
        } else {
            try json_str.appendSlice(",\"autohostport\":null");
        }

        if (self.numrestrictions) |nr| {
            try json_str.appendSlice(",\"numrestrictions\":");
            try std.fmt.format(json_str.writer(), "{d}", .{nr});
        } else {
            try json_str.appendSlice(",\"numrestrictions\":null");
        }

        if (self.autohostname) |ahn| {
            try json_str.appendSlice(",\"autohostname\":\"");
            try json_str.appendSlice(ahn);
            try json_str.appendSlice("\"");
        } else {
            try json_str.appendSlice(",\"autohostname\":null");
        }

        if (self.autohostrank) |ahr| {
            try json_str.appendSlice(",\"autohostrank\":");
            try std.fmt.format(json_str.writer(), "{d}", .{ahr});
        } else {
            try json_str.appendSlice(",\"autohostrank\":null");
        }

        if (self.autohostaccountid) |ahai| {
            try json_str.appendSlice(",\"autohostaccountid\":");
            try std.fmt.format(json_str.writer(), "{d}", .{ahai});
        } else {
            try json_str.appendSlice(",\"autohostaccountid\":null");
        }

        if (self.numplayers) |np| {
            try json_str.appendSlice(",\"numplayers\":");
            try std.fmt.format(json_str.writer(), "{d}", .{np});
        } else {
            try json_str.appendSlice(",\"numplayers\":null");
        }

        if (self.autohostcountrycode) |ahcc| {
            try json_str.appendSlice(",\"autohostcountrycode\":\"");
            try json_str.appendSlice(ahcc);
            try json_str.appendSlice("\"");
        } else {
            try json_str.appendSlice(",\"autohostcountrycode\":null");
        }

        if (self.hostport) |hp| {
            try json_str.appendSlice(",\"hostport\":");
            try std.fmt.format(json_str.writer(), "{d}", .{hp});
        } else {
            try json_str.appendSlice(",\"hostport\":null");
        }
    }
};

fn deinitStringMap(map: *StringMap, allocator: Allocator) void {
    var iterator = map.iterator();
    while (iterator.next()) |entry| {
        allocator.free(entry.key_ptr.*);
        allocator.free(entry.value_ptr.*);
    }
    map.deinit();
}

// Parser state
const ParseState = enum {
    None,
    InSection,
};

// Parser structure
const GameConfigParser = struct {
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }

    pub fn parse(self: *Self, input: []const u8) !GameConfig {
        var config = GameConfig.init(self.allocator);
        var lines = std.mem.splitSequence(u8, input, "\n");
        var state = ParseState.None;
        var current_section: ?[]const u8 = null;
        var current_map: ?*StringMap = null;

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r\n");
            if (trimmed.len == 0) continue;

            if (trimmed[0] == '[' and trimmed[trimmed.len - 1] == ']') {
                // Section header
                const section_name = trimmed[1 .. trimmed.len - 1];
                if (current_section) |section| {
                    self.allocator.free(section);
                }
                current_section = try self.allocator.dupe(u8, section_name);
                state = ParseState.InSection;
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
                // Start of section content
                continue;
            } else if (trimmed[0] == '}') {
                // End of section content
                state = ParseState.None;
                if (current_section) |section| {
                    self.allocator.free(section);
                    current_section = null;
                }
                current_map = null;
            } else if (state == ParseState.InSection) {
                // Key-value pair
                if (std.mem.indexOf(u8, trimmed, "=")) |eq_pos| {
                    const key = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
                    var value = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t");

                    // Remove trailing semicolon if present
                    if (value.len > 0 and value[value.len - 1] == ';') {
                        value = value[0 .. value.len - 1];
                    }

                    if (current_section) |section| {
                        try self.parseKeyValue(&config, section, key, value, current_map);
                    }
                }
            } else {
                // Global key-value pair
                if (std.mem.indexOf(u8, trimmed, "=")) |eq_pos| {
                    const key = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
                    var value = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t");

                    // Remove trailing semicolon if present
                    if (value.len > 0 and value[value.len - 1] == ';') {
                        value = value[0 .. value.len - 1];
                    }

                    try self.parseGlobalKeyValue(&config, key, value);
                }
            }
        }

        // Clean up current_section if still allocated
        if (current_section) |section| {
            self.allocator.free(section);
        }

        return config;
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
            // Store in generic map
            const key_copy = try self.allocator.dupe(u8, key);
            const value_copy = try self.allocator.dupe(u8, value);
            try map.put(key_copy, value_copy);
        }
    }

    fn parseGlobalKeyValue(self: *Self, config: *GameConfig, key: []const u8, value: []const u8) !void {
        if (std.mem.eql(u8, key, "ishost")) {
            config.ishost = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "hostip")) {
            config.hostip = try self.allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, key, "numallyteams")) {
            config.numallyteams = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "server_match_id")) {
            config.server_match_id = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "numteams")) {
            config.numteams = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "startpostype")) {
            config.startpostype = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "gametype")) {
            config.gametype = try self.allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, key, "hosttype")) {
            config.hosttype = try self.allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, key, "mapname")) {
            config.mapname = try self.allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, key, "autohostport")) {
            config.autohostport = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "numrestrictions")) {
            config.numrestrictions = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "autohostname")) {
            config.autohostname = try self.allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, key, "autohostrank")) {
            config.autohostrank = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "autohostaccountid")) {
            config.autohostaccountid = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "numplayers")) {
            config.numplayers = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "autohostcountrycode")) {
            config.autohostcountrycode = try self.allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, key, "hostport")) {
            config.hostport = try std.fmt.parseInt(u32, value, 10);
        }
    }

    fn parsePlayer(self: *Self, config: *GameConfig, player_id: u32, key: []const u8, value: []const u8) !void {
        // Find or create player
        var player_index: ?usize = null;
        for (config.players.items, 0..) |*player, i| {
            if (player.id == player_id) {
                player_index = i;
                break;
            }
        }

        if (player_index == null) {
            try config.players.append(Player.init(self.allocator, player_id));
            player_index = config.players.items.len - 1;
        }

        var player = &config.players.items[player_index.?];

        if (std.mem.eql(u8, key, "team")) {
            player.team = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "countrycode")) {
            player.countrycode = try self.allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, key, "accountid")) {
            player.accountid = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "name")) {
            player.name = try self.allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, key, "rank")) {
            player.rank = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "skill")) {
            player.skill = try self.parseFloatArray(value);
        } else if (std.mem.eql(u8, key, "spectator")) {
            player.spectator = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "skilluncertainty")) {
            player.skilluncertainty = try std.fmt.parseFloat(f64, value);
        }
    }

    fn parseTeam(self: *Self, config: *GameConfig, team_id: u32, key: []const u8, value: []const u8) !void {
        // Find or create team
        var team_index: ?usize = null;
        for (config.teams.items, 0..) |*team, i| {
            if (team.id == team_id) {
                team_index = i;
                break;
            }
        }

        if (team_index == null) {
            try config.teams.append(Team.init(self.allocator, team_id));
            team_index = config.teams.items.len - 1;
        }

        var team = &config.teams.items[team_index.?];

        if (std.mem.eql(u8, key, "allyteam")) {
            team.allyteam = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "teamleader")) {
            team.teamleader = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "rgbcolor")) {
            team.rgbcolor = try self.parseFloatArray(value);
        } else if (std.mem.eql(u8, key, "side")) {
            team.side = try self.allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, key, "handicap")) {
            team.handicap = try std.fmt.parseInt(u32, value, 10);
        }
    }

    fn parseAllyTeam(config: *GameConfig, allyteam_id: u32, key: []const u8, value: []const u8) !void {
        // Find or create allyteam
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

        if (std.mem.eql(u8, key, "startrectleft")) {
            allyteam.startrectleft = try std.fmt.parseFloat(f64, value);
        } else if (std.mem.eql(u8, key, "startrectright")) {
            allyteam.startrectright = try std.fmt.parseFloat(f64, value);
        } else if (std.mem.eql(u8, key, "startrectbottom")) {
            allyteam.startrectbottom = try std.fmt.parseFloat(f64, value);
        } else if (std.mem.eql(u8, key, "startrecttop")) {
            allyteam.startrecttop = try std.fmt.parseFloat(f64, value);
        } else if (std.mem.eql(u8, key, "numallies")) {
            allyteam.numallies = try std.fmt.parseInt(u32, value, 10);
        }
    }

    fn parseFloatArray(self: *Self, value: []const u8) ![]f64 {
        // Handle arrays like [16.67] or space-separated values like "0.91765 0.20784 0.47451"
        var trimmed = std.mem.trim(u8, value, " \t");

        if (trimmed.len >= 2 and trimmed[0] == '[' and trimmed[trimmed.len - 1] == ']') {
            // Array notation [value1, value2, ...]
            trimmed = trimmed[1 .. trimmed.len - 1];
        }

        var result = ArrayList(f64).init(self.allocator);

        // Try space-separated first (for RGB colors)
        if (std.mem.indexOf(u8, trimmed, " ")) |_| {
            var parts = std.mem.splitSequence(u8, trimmed, " ");
            while (parts.next()) |part| {
                const clean_part = std.mem.trim(u8, part, " \t,");
                if (clean_part.len > 0) {
                    const float_val = try std.fmt.parseFloat(f64, clean_part);
                    try result.append(float_val);
                }
            }
        } else {
            // Single value or comma-separated
            var parts = std.mem.splitSequence(u8, trimmed, ",");
            while (parts.next()) |part| {
                const clean_part = std.mem.trim(u8, part, " \t,");
                if (clean_part.len > 0) {
                    const float_val = try std.fmt.parseFloat(f64, clean_part);
                    try result.append(float_val);
                }
            }
        }

        return result.toOwnedSlice();
    }
};

pub fn parseScript(allocator: Allocator, input: []const u8) !GameConfig {
    var parser = GameConfigParser.init(allocator);
    return parser.parse(input);
}

// Example usage and test
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const sample_input =
        \\[player0]
        \\{
        \\team=0;
        \\countrycode=FR;
        \\accountid=226535;
        \\name=Kamfrenchie;
        \\rank=4;
        \\skill=[31.53];
        \\spectator=0;
        \\skilluncertainty=3.07;
        \\}
        \\[team0]
        \\{
        \\allyteam=0;
        \\teamleader=0;
        \\rgbcolor=0.05098 0.73725 0.54118;
        \\side=Armada;
        \\handicap=0;
        \\}
        \\[player1]
        \\{
        \\team=1;
        \\countrycode=US;
        \\accountid=12345;
        \\name=TestPlayer;
        \\rank=3;
        \\skill=[25.98];
        \\spectator=0;
        \\skilluncertainty=4.12;
        \\}
        \\[team1]
        \\{
        \\allyteam=1;
        \\teamleader=1;
        \\rgbcolor=0.88627 0.03137 0.67843;
        \\side=Cortex;
        \\handicap=0;
        \\}
        \\ishost=1;
        \\numplayers=2;
        \\mapname=Test Map;
    ;

    var config = try parseScript(allocator, sample_input);
    defer config.deinit();

    print("Parsed config successfully!\n");
    print("Players: {}\n", .{config.players.items.len});
    print("Teams: {}\n", .{config.teams.items.len});
    print("Map name: {?s}\n", .{config.mapname});

    // Test skill parsing
    if (config.players.items.len > 0) {
        const player = &config.players.items[0];
        print("Player 0 skill: ");
        if (player.skill) |skill| {
            for (skill) |s| {
                print("{d} ", .{s});
            }
        }
        print("\n");
        print("Player 0 skilluncertainty: {?d}\n", .{player.skilluncertainty});
    }

    // Test RGB color parsing
    if (config.teams.items.len > 0) {
        const team = &config.teams.items[0];
        print("Team 0 RGB color: ");
        if (team.rgbcolor) |color| {
            for (color) |c| {
                print("{d} ", .{c});
            }
        }
        print("\n");
    }

    // JSON output test
    const json_output = try config.toJson(allocator);
    defer allocator.free(json_output);
    print("\nMinified JSON output:\n{s}\n", .{json_output});
}
