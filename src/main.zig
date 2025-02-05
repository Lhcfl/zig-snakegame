const std = @import("std");
const inputer = @import("inputer.zig");
const snake = @import("snake.zig");
const builtin = @import("builtin");
const io = @import("io.zig");
const TickPerSeconds = 16;

fn snake_worker() anyerror!void {
    try snake.init();
    while (true) {
        if (!snake.game_stoped()) {
            try snake.tick();
            snake.printWorld();
        }
        std.time.sleep(1e9 / TickPerSeconds);
    }
}

fn input_handler() anyerror!void {
    while (true) {
        const key = inputer.getch() catch |err| {
            std.log.err("Cannot get input: {}", .{err});
            std.process.exit(1);
        };
        if (snake.game_stoped()) {
            switch (key) {
                'q', 'Q' => {
                    std.process.exit(0);
                },
                else => try snake.init(),
            }
        } else {
            switch (key) {
                @intFromEnum(inputer.keys.UpArrow) => {
                    if (snake.direction != .Down) {
                        snake.direction = .Up;
                    }
                },
                @intFromEnum(inputer.keys.DownArrow) => {
                    if (snake.direction != .Up) {
                        snake.direction = .Down;
                    }
                },
                @intFromEnum(inputer.keys.LeftArrow) => {
                    if (snake.direction != .Right) {
                        snake.direction = .Left;
                    }
                },
                @intFromEnum(inputer.keys.RightArrow) => {
                    if (snake.direction != .Left) {
                        snake.direction = .Right;
                    }
                },
                'q', 'Q' => {
                    std.process.exit(0);
                },
                else => {},
            }
        }
    }
}

pub fn main() anyerror!void {
    switch (builtin.os.tag) {
        .windows => {
            // set utf-8
            _ = std.os.windows.kernel32.SetConsoleOutputCP(65001);
        },
        .linux => {
            const c = @cImport(@cInclude("ncurses.h"));
            const screen = c.initscr();
            defer _ = c.endwin();
            _ = c.raw();
            _ = c.keypad(screen, true);
            _ = c.noecho();
        },
        else => {
            std.log.err("Unsupported platform", .{});
            return;
        },
    }

    var snake_thread = try std.Thread.spawn(.{}, snake_worker, .{});
    var input_thread = try std.Thread.spawn(.{}, input_handler, .{});
    snake_thread.join();
    input_thread.join();
}
