const snake = @import("snake.zig");
const std = @import("std");

fn TextBuffer(comptime size: usize) type {
    return struct {
        buf: [size]u8 = undefined,
        idx: usize = 0,

        fn clear(self: *TextBuffer(size)) void {
            self.idx = 0;
            self.buf = .{0} ** size;
        }

        fn print(self: *TextBuffer(size), comptime fmt: []const u8, args: anytype) !void {
            const buf = try std.fmt.bufPrint(self.buf[self.idx..], fmt, args);
            self.idx += buf.len;
        }
    };
}

var world_buf = TextBuffer(2 * snake.WORLD_H * snake.WORLD_W + 1024){};
var snake_buf = TextBuffer(2 * snake.WORLD_H * snake.WORLD_W + 1024){};

pub fn gen_world() error{NoSpaceLeft}![]const u8 {
    // clear buffer
    world_buf.clear();

    try world_buf.print("score = {d}, dir = {s}\n", .{ snake.score, snake.direction.to_string() });

    for (&snake.world) |line| {
        for (&line) |block| {
            try world_buf.print("{s}", .{block.render()});
        }
        try world_buf.print("\n", .{});
    }

    try world_buf.print("Press Q to exit\n", .{});

    try switch (snake.game_status) {
        .Playing => world_buf.print("Use ↑ ↓ ← → to move\n", .{}),
        .Lost => world_buf.print("You Lost!! Press any key to restart\n", .{}),
        .Win => world_buf.print("You Win!! Press any key to start a new game\n", .{}),
    };

    return &world_buf.buf;
}

pub fn gen_snake() ![]const u8 {
    snake_buf.clear();

    for (&snake.world) |line| {
        for (&line) |block| {
            try snake_buf.print("{s}", .{switch (block) {
                .SnakeBody => "██",
                .Food => "💖",
                .Edge => "",
                .Empty => "  ",
            }});
        }
        try snake_buf.print("\n", .{});
    }

    return &snake_buf.buf;
}

var status_buf = TextBuffer(1280){};

pub fn gen_status() ![]const u8 {
    status_buf.clear();

    try status_buf.print("Press Q to exit\n", .{});

    try switch (snake.game_status) {
        .Playing => status_buf.print("Use ↑ ↓ ← → to move\n", .{}),
        .Lost => status_buf.print("You Lost!! Press R to restart\n", .{}),
        .Win => status_buf.print("You Win!! Press R to start a new game\n", .{}),
    };

    return &status_buf.buf;
}
