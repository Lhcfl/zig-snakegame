pub const keys = enum(i32) {
    LeftArrow = 37,
    UpArrow = 38,
    RightArrow = 39,
    DownArrow = 40,
};

pub fn getch() anyerror!i32 {
    const builtin = @import("builtin");
    return switch (builtin.os.tag) {
        .windows => @import("win/getch.zig").getch_win(),
        .linux => @import("linux/getch.zig").getch(),
        else => error.PlatformNotSupported,
    };
}
