const std = @import("std");
const os = std.os;
const c = @cImport(@cInclude("ncurses.h"));

pub fn getch() anyerror!i32 {
    std.time.sleep(1 * std.time.ns_per_ms);
    const ch = c.getch();
    return switch (ch) {
        260 => 37,
        259 => 38,
        261 => 39,
        258 => 40,
        else => ch,
    };
}
