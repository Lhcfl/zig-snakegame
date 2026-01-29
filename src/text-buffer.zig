const std = @import("std");
const TextBuffer = @This();

buf: []u8 = undefined,
idx: usize = 0,
size: usize,

pub fn init(size: usize, allocator: std.mem.Allocator) !TextBuffer {
    return TextBuffer{
        .buf = try allocator.alloc(u8, size),
        .idx = 0,
        .size = size,
    };
}

pub fn deinit(self: *TextBuffer, allocator: std.mem.Allocator) void {
    allocator.free(self.buf);
}

pub fn clear(self: *TextBuffer) void {
    self.idx = 0;
    @memset(self.buf, 0);
}

pub fn print(self: *TextBuffer, comptime fmt: []const u8, args: anytype) !void {
    const buf = try std.fmt.bufPrint(self.buf[self.idx..], fmt, args);
    self.idx += buf.len;
}
