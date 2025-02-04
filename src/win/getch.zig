const std = @import("std");
const c_windows = @cImport({
    @cInclude("windows.h");
});

pub const GetchError = error{
    CannotGetStdHandle,
    ReadNotOk,
};

pub fn getch_win() GetchError!i32 {
    const stdin = std.os.windows.GetStdHandle(std.os.windows.STD_INPUT_HANDLE) catch {
        return GetchError.CannotGetStdHandle;
    };
    var input_record: c_windows.INPUT_RECORD = undefined;
    var _num_events_read: std.os.windows.DWORD = undefined;
    while (true) {
        const ok = c_windows.ReadConsoleInputW(stdin, &input_record, 1, &_num_events_read);
        if (ok == 0) {
            return GetchError.ReadNotOk;
        }
        if (input_record.EventType != c_windows.KEY_EVENT) {
            continue;
        }
        if (input_record.Event.KeyEvent.bKeyDown != 0) {
            continue;
        }
        return input_record.Event.KeyEvent.wVirtualKeyCode;
    }
}
