const std = @import("std");
const inputer = @import("inputer.zig");
const snake = @import("snake.zig");
const graph = @import("graph.zig");
const builtin = @import("builtin");
const io = @import("io.zig");
const TickPerSeconds = 16;
const vaxis = @import("vaxis");
const Cell = vaxis.Cell;

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
};

pub const panic = vaxis.panic_handler;

pub fn main() !void {
    try snake.init();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) {
            std.log.err("memory leak", .{});
        }
    }
    const alloc = gpa.allocator();

    var buffer: [1024]u8 = undefined;
    var tty = try vaxis.Tty.init(&buffer);
    defer tty.deinit();

    var vx = try vaxis.init(alloc, .{});
    defer vx.deinit(alloc, tty.writer());

    var loop: vaxis.Loop(Event) = .{ .tty = &tty, .vaxis = &vx };
    try loop.init();

    try loop.start();
    defer loop.stop();

    try vx.enterAltScreen(tty.writer());
    try vx.queryTerminal(tty.writer(), 1 * std.time.ns_per_s);

    try vx.queryColor(tty.writer(), .fg);
    try vx.queryColor(tty.writer(), .bg);

    var frame: u32 = 0;

    // block until we get a resize
    while (true) {
        const event = loop.nextEvent();
        switch (event) {
            .key_press => |key| if (key.matches('c', .{ .ctrl = true })) return,
            .winsize => |ws| {
                try vx.resize(alloc, tty.writer(), ws);
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
                    if (key.matches(vaxis.Key.up, .{})) snake.set_direction(.Up);
                    if (key.matches(vaxis.Key.down, .{})) snake.set_direction(.Down);
                    if (key.matches(vaxis.Key.left, .{})) snake.set_direction(.Left);
                    if (key.matches(vaxis.Key.right, .{})) snake.set_direction(.Right);

                    if (snake.game_stoped()) {
                        try snake.init();
                    }
                },
                .winsize => |ws| try vx.resize(alloc, tty.writer(), ws),
            }
        }

        if (frame == 0) try snake.tick();

        const win = vx.window();
        win.clear();

        const game_window = vaxis.widgets.alignment.center(win, snake.WORLD_W * 2 + 4, snake.WORLD_H + 4);

        _ = game_window.printSegment(.{
            .text = try graph.gen_world(),
        }, .{});

        const snake_window = game_window.child(.{
            .x_off = 2,
            .y_off = 1,
        });

        _ = snake_window.printSegment(.{
            .text = try graph.gen_snake(),
            .style = .{ .fg = .{ .rgb = .{ 50, 255, 50 } } },
        }, .{});

        try vx.render(tty.writer());
        std.Thread.sleep(16 * std.time.ns_per_ms);
        frame = (frame + 1) % 3;
    }
}
