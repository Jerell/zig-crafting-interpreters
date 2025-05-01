const std = @import("std");
const TokenType = @import("tokentype.zig").TokenType;
const LiteralValue = @import("expressions.zig").LiteralValue;

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    literal: ?LiteralValue, // Using an optional type or variant type instead of Object
    line: usize,

    pub fn init(token_type: TokenType, lexeme: []const u8, literal: ?LiteralValue, line: usize) Token {
        return Token{
            .type = token_type,
            .lexeme = lexeme,
            .literal = literal,
            .line = line,
        };
    }

    pub fn format(self: Token, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("{} {s} {?}", .{ self.type, self.lexeme, self.literal });
    }
};
