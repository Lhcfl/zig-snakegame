const std = @import("std");

pub const GameConfig = @This();

max_tick_per_second: usize = 25,
food: usize = 3,
allocator: std.mem.Allocator,
size: usize = 20,
basic: bool = false,
auto: bool = false,

pub fn parse_game_args(alloc: std.mem.Allocator) !GameConfig {
    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();

    var ret = GameConfig{
        .allocator = alloc,
    };

    while (args.next()) |it| {
        const arg: []const u8 = it[0..];
        if (std.mem.startsWith(u8, arg, "--max-speed")) {
            const next = if (args.next()) |val| val else {
                std.log.err("missing value for --max-speed", .{});
                std.process.exit(1);
            };
            ret.max_tick_per_second = std.fmt.parseInt(usize, next, 10) catch |e| {
                std.log.err("invalid max-speed: {}", .{e});
                std.process.exit(1);
            };
        } else if (std.mem.startsWith(u8, arg, "--food")) {
            const next = if (args.next()) |val| val else {
                std.log.err("missing value for --food", .{});
                std.process.exit(1);
            };
            ret.food = std.fmt.parseInt(usize, next, 10) catch |e| {
                std.log.err("invalid food count: {}", .{e});
                std.process.exit(1);
            };
        } else if (std.mem.startsWith(u8, arg, "--size")) {
            const next = if (args.next()) |val| val else {
                std.log.err("missing value for --size", .{});
                std.process.exit(1);
            };
            ret.size = std.fmt.parseInt(usize, next, 10) catch |e| {
                std.log.err("invalid size: {}", .{e});
                std.process.exit(1);
            };
        } else if (std.mem.startsWith(u8, arg, "--basic")) {
            ret.basic = true;
        } else if (std.mem.startsWith(u8, arg, "--auto")) {
            ret.auto = true;
        } else if (std.mem.startsWith(u8, arg, "--help") or std.mem.startsWith(u8, arg, "-h") or std.mem.startsWith(u8, arg, "/?")) {
            const stdout = std.fs.File.stdout();
            try stdout.writeAll(HELP_MESSAGE);
            stdout.close();
            std.process.exit(0);
        }
    }

    validate(ret);

    return ret;
}

fn validate(config: GameConfig) void {
    if (config.size > 100 or config.size < 8) {
        std.log.err("size must be >= 8 and <= 100", .{});
        std.process.exit(1);
    }
    if (config.food < 1 or config.food > (config.size - 2) * (config.size - 2) - 5) {
        std.log.err("food count is too big or too small", .{});
        std.process.exit(1);
    }
    if (config.max_tick_per_second < 1 or config.max_tick_per_second > 100) {
        std.log.err("max tick per second must be >= 1 and <= 100", .{});
        std.process.exit(1);
    }
}

pub const HELP_MESSAGE =
    \\Snake Game! powered by Zig and Vaxis
    \\Usage:
    \\  --max-speed <number>   Set the maximum speed (ticks per second). Default is 25.
    \\  --food <number>        Set the number of food items in the game. Default is 3.
    \\  --size <number>        Set the size of the game world (width and height). Default is 20.
    \\  --basic                Enable basic mode (no color and simplified rendering).
    \\  --auto                 Enable automatic control (AI plays the game).
    \\Enjoy the game!
;
