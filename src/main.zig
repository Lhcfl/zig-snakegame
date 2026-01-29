const std = @import("std");
const Game = @import("snake.zig");
const View = @import("view.zig");
const builtin = @import("builtin");
const vaxis = @import("vaxis");
const Cell = vaxis.Cell;
const TextBuffer = @import("text-buffer.zig");

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
};

pub const panic = vaxis.panic_handler;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) {
            std.log.err("memory leak", .{});
        }
    }

    const allocator = gpa.allocator();
    const config = try @import("config.zig").parse_game_args(allocator);

    var game = Game{};
    try game.init(config);
    defer game.deinit();

    const view = View{ .game = &game };

    var tb = try TextBuffer.init(view.view_size() * view.view_size(), allocator);
    defer tb.deinit(allocator);
    var stb = try TextBuffer.init(view.view_size() * view.view_size(), allocator);
    defer stb.deinit(allocator);

    var buffer: [1024]u8 = undefined;
    var tty = try vaxis.Tty.init(&buffer);
    defer tty.deinit();

    var vx = try vaxis.init(allocator, .{});
    defer vx.deinit(allocator, tty.writer());

    var loop: vaxis.Loop(Event) = .{ .tty = &tty, .vaxis = &vx };
    try loop.init();

    try loop.start();
    defer loop.stop();

    try vx.enterAltScreen(tty.writer());
    try vx.queryTerminal(tty.writer(), 1 * std.time.ns_per_s);

    try vx.queryColor(tty.writer(), .fg);
    try vx.queryColor(tty.writer(), .bg);

    // block until we get a resize
    while (true) {
        const event = loop.nextEvent();
        switch (event) {
            .key_press => |key| if (key.matches('c', .{ .ctrl = true })) return,
            .winsize => |ws| {
                try vx.resize(allocator, tty.writer(), ws);
                break;
            },
        }
    }

    while (true) {
        while (loop.tryEvent()) |event| {
            switch (event) {
                .key_press => |key| {
                    if (key.matches('c', .{ .ctrl = true })) return;
                    if (key.matches('q', .{})) return;
                    if (key.matches(vaxis.Key.up, .{})) game.set_direction(.Up);
                    if (key.matches(vaxis.Key.down, .{})) game.set_direction(.Down);
                    if (key.matches(vaxis.Key.left, .{})) game.set_direction(.Left);
                    if (key.matches(vaxis.Key.right, .{})) game.set_direction(.Right);

                    if (key.matches('r', .{}) and game.game_stoped()) try game.init(config);
                },
                .winsize => |ws| try vx.resize(allocator, tty.writer(), ws),
            }
        }

        try game.tick();

        const win = vx.window();
        win.clear();

        const game_window = vaxis.widgets.alignment.center(win, view.view_size(), view.view_size());

        const game_window_main = game_window.child(.{ .x_off = 0, .y_off = 1 });

        _ = game_window_main.printSegment(.{
            .text = try view.gen_world(&tb),
        }, .{});

        const snake_window = game_window_main.child(.{
            .x_off = 2,
            .y_off = 1,
        });

        if (!config.basic) {
            _ = snake_window.printSegment(.{
                .text = try view.gen_snake(&stb),
                .style = .{ .fg = .{ .rgb = .{ 50, 255, 50 } } },
            }, .{});
        }

        const est_tick_per_second = (game.score / 8) + 10;
        const tick_per_second = if (est_tick_per_second < config.max_tick_per_second) est_tick_per_second else config.max_tick_per_second;

        var speed_buf: [10]u8 = undefined;
        _ = game_window.printSegment(.{ .text = try std.fmt.bufPrint(&speed_buf, "speed = {d}", .{tick_per_second}) }, .{});

        try vx.render(tty.writer());

        std.Thread.sleep(std.time.ns_per_s / tick_per_second);
    }
}
