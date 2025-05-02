// src/root.zig
const std = @import("std");

pub usingnamespace @import("lox/token.zig");
pub usingnamespace @import("lox/tokentype.zig");
pub usingnamespace @import("lox/expressions.zig");
pub usingnamespace @import("lox/scanner.zig");
pub usingnamespace @import("lox/parser.zig");
pub usingnamespace @import("lox/errors.zig");

test "placeholder library test" {
    // This test belongs to the library artifact
    try std.testing.expect(true);
}
