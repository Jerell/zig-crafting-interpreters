const std = @import("std");
pub var had_error: bool = false;

pub fn reportError(line: usize, message: []const u8) void {
    report(line, "", message);
}

pub fn report(line: usize, where_: []const u8, message: []const u8) void {
    const stderr = std.io.getStdErr().writer();
    stderr.print("[line {d}] Error{s}: {s}\n", .{ line, where_, message }) catch {};
    had_error = true;
}
