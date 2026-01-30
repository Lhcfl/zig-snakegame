const std = @import("std");
const Game = @import("snake.zig");
const View = @import("view.zig");
const builtin = @import("builtin");
const vaxis = @import("vaxis");
const Cell = vaxis.Cell;
const TextBuffer = @import("text-buffer.zig");
const auto_control = @import("auto_control.zig").auto_control;

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

        if (config.auto) {
            auto_control(&game);
        }
        try game.tick();

        const win = vx.window();
        win.clear();

        const game_window = vaxis.widgets.alignment.center(win, view.view_size(), view.view_size());

        const game_window_main = game_window.child(.{ .x_off = 0, .y_off = 1 });

        _ = game_window_main.printSegment(.{
            .text = try view.gen_world(&tb, config.basic),
        }, .{});

        const snake_window = game_window_main.child(.{
            .x_off = 2,
            .y_off = 1,
        });

        // colorful snake
        if (!config.basic) {
            var curr = game.snake.first;
            var i: usize = 0;

            const colors = [_][3]u8{
                //    R    G  B
                .{ 50, 255, 50 }, // 绿色
                .{ 0, 255, 255 }, // 蓝色
                .{ 50, 0, 255 }, // 靛色
                .{ 255, 0, 255 }, // 紫色
                .{ 255, 50, 0 }, // 红色
                .{ 255, 165, 0 }, // 橙色
                .{ 255, 255, 0 }, // 黄色
            };

            const segment = 50;

            while (curr) |node| : ({
                i += 1;
                curr = node.next;
            }) {
                const idx = (i / segment) % colors.len;
                const rem: u8 = @intCast((i % segment) * 100 / segment);

                const color = blendColors(colors[idx], colors[(idx + 1) % colors.len], rem) catch colors[colors.len - 1];

                _ = snake_window.printSegment(.{ .text = "██", .style = .{ .fg = color } }, .{
                    .col_offset = @intCast((Game.data_of(node).x - 1) * 2),
                    .row_offset = @intCast(Game.data_of(node).y),
                });
            }
        }

        const est_tick_per_second = (game.score / 8) + 10;
        const tick_per_second = if (config.auto) config.max_tick_per_second else if (est_tick_per_second < config.max_tick_per_second) est_tick_per_second else config.max_tick_per_second;

        var speed_buf: [10]u8 = undefined;
        _ = game_window.printSegment(.{ .text = try std.fmt.bufPrint(&speed_buf, "speed = {d}", .{tick_per_second}) }, .{});

        try vx.render(tty.writer());

        std.Thread.sleep(std.time.ns_per_s / tick_per_second);
    }
}

/// blend two rgb colors. pct is an integer percentage for te portion of 'b' in
/// 'a'
fn blendColors(a: [3]u8, b: [3]u8, pct: u8) !vaxis.Color {
    // const r_a = (a[0] * (100 -| pct)) / 100;

    const r_a = (@as(u16, a[0]) * @as(u16, (100 -| pct))) / 100;
    const r_b = (@as(u16, b[0]) * @as(u16, pct)) / 100;

    const g_a = (@as(u16, a[1]) * @as(u16, (100 -| pct))) / 100;
    const g_b = (@as(u16, b[1]) * @as(u16, pct)) / 100;
    // const g_a = try std.math.mul(u8, a[1], (100 -| pct) / 100);
    // const g_b = (b[1] * pct) / 100;

    const b_a = (@as(u16, a[2]) * @as(u16, (100 -| pct))) / 100;
    const b_b = (@as(u16, b[2]) * @as(u16, pct)) / 100;
    // const b_a = try std.math.mul(u8, a[2], (100 -| pct) / 100);
    // const b_b = (b[2] * pct) / 100;
    return .{ .rgb = [_]u8{
        @min(r_a + r_b, 255),
        @min(g_a + g_b, 255),
        @min(b_a + b_b, 255),
    } };
}
