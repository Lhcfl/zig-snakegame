const std = @import("std");
const inputer = @import("inputer.zig");
const snake = @import("snake.zig");
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

    const fg = [_]u8{ 192, 202, 245 };
    const bg = [_]u8{ 26, 27, 38 };

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

        const color = try blendColors(bg, fg, 100);

        const style: vaxis.Style = .{ .fg = color };

        const segment: vaxis.Segment = .{
            .text = try snake.gen_world(),
            .style = style,
        };
        const center = vaxis.widgets.alignment.center(win, snake.WORLD_W * 2 + 20, snake.WORLD_H + 10);
        _ = center.printSegment(segment, .{ .wrap = .grapheme });
        // var bw = tty.bufferedWriter();
        // try vx.render(bw.writer().any());
        // try bw.flush();
        try vx.render(tty.writer());
        std.Thread.sleep(16 * std.time.ns_per_ms);
        frame = (frame + 1) % 3;
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
