const std = @import("std");
const builtin = @import("builtin");

pub fn output(str: []const u8) void {
    if (builtin.os.tag == .linux) {
        const c = @cImport(@cInclude("ncurses.h"));
        const c_str: [*c]const u8 = @ptrCast(str);
        _ = c.addnstr(c_str, @intCast(str.len));
    } else {
        std.debug.print("{s}", .{str});
    }
}

pub fn moveTo00() void {
    if (builtin.os.tag == .linux) {
        const c = @cImport(@cInclude("ncurses.h"));
        _ = c.move(0, 0);
    } else {
        std.debug.print("\x1B[2J\x1B[H", .{});
    }
}

pub fn refresh() void {
    if (builtin.os.tag == .linux) {
        const c = @cImport(@cInclude("ncurses.h"));
        _ = c.refresh();
    }
}
