const std = @import("std");

pub const GameConfig = @This();

max_tick_per_second: usize = 25,
food: usize = 3,

pub fn parse_game_args(alloc: std.mem.Allocator) !GameConfig {
    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();

    var ret = GameConfig{};

    const ParsingStatus = enum {
        Nothing,
        Speed,
        Food,
    };

    var status: ParsingStatus = .Nothing;

    while (args.next()) |it| {
        const arg: []const u8 = it[0..];
        switch (status) {
            .Nothing => {
                if (std.mem.startsWith(u8, arg, "--max-speed")) {
                    status = .Speed;
                }
                if (std.mem.startsWith(u8, arg, "--food")) {
                    status = .Food;
                }

                continue;
            },
            .Speed => {
                ret.max_tick_per_second = try std.fmt.parseInt(usize, arg, 10);
            },
            .Food => {
                ret.food = try std.fmt.parseInt(usize, arg, 10);
            },
        }

        status = .Nothing;
    }

    return ret;
}
