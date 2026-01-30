const Game = @import("snake.zig");
const std = @import("std");
const TextBuffer = @import("text-buffer.zig");
const View = @This();

game: *Game,

pub fn view_size(self: *const View) u16 {
    return @intCast(self.game.world_w * 2 + 4);
}

pub fn gen_world(self: *const View, buf: *TextBuffer, is_basic: bool) ![]const u8 {
    // clear buffer
    buf.clear();

    try buf.print("score {d}\n", .{self.game.score});

    for (0..self.game.world_h) |y| {
        for (0..self.game.world_w) |x| {
            try buf.print("{s}", .{switch (self.game.world[self.game.indexOf(.{ .x = x, .y = y })]) {
                .SnakeBody => "()",
                .Food => if (is_basic) "<>" else "💖",
                .Edge => "██",
                .Empty => "  ",
            }});
        }
        try buf.print("\n", .{});
    }

    try switch (self.game.game_status) {
        .Playing => buf.print("Q = Exit    ↑ ↓ ← → = Move\n", .{}),
        .Lost => buf.print("You Lost!! Press R to restart\n", .{}),
        .Win => buf.print("You Win!! Press R to start a new game\n", .{}),
    };

    return buf.buf;
}

pub fn gen_snake(self: *const View, buf: *TextBuffer) ![]const u8 {
    buf.clear();

    for (0..self.game.world_h) |y| {
        for (0..self.game.world_w) |x| {
            try buf.print("{s}", .{switch (self.game.world[self.game.indexOf(.{ .x = x, .y = y })]) {
                .SnakeBody => "██",
                .Food => "💖",
                .Edge => "",
                .Empty => "  ",
            }});
        }
        try buf.print("\n", .{});
    }

    return buf.buf;
}
