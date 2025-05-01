const std = @import("std");
const Token = @import("token.zig").Token;
const TokenType = @import("tokentype.zig").TokenType;
const LiteralValue = @import("expressions.zig").LiteralValue;
const errors = @import("errors.zig");

pub const Scanner = struct {
    source: []const u8,
    tokens: std.ArrayList(Token),
    start: usize,
    current: usize,
    line: usize,

    pub fn init(allocator: std.mem.Allocator, source: []const u8) !Scanner {
        return Scanner{
            .source = source,
            .tokens = std.ArrayList(Token).init(allocator),
            .start = 0,
            .current = 0,
            .line = 1,
        };
    }

    pub fn deinit(self: *Scanner) void {
        self.tokens.deinit();
    }

    pub fn scanTokens(self: *Scanner) ![]Token {
        while (!self.isAtEnd()) {
            self.start = self.current;
            try self.scanToken();
        }

        try self.addToken(TokenType.EOF, null);
        return self.tokens.items;
    }

    fn isAtEnd(self: *const Scanner) bool {
        return self.current >= self.source.len;
    }

    fn scanToken(self: *Scanner) !void {
        const c = self.advance();
        switch (c) {
            '(' => try self.addToken(TokenType.LEFT_PAREN, null),
            ')' => try self.addToken(TokenType.RIGHT_PAREN, null),
            '{' => try self.addToken(TokenType.LEFT_BRACE, null),
            '}' => try self.addToken(TokenType.RIGHT_BRACE, null),
            ',' => try self.addToken(TokenType.COMMA, null),
            '.' => try self.addToken(TokenType.DOT, null),
            '-' => try self.addToken(TokenType.MINUS, null),
            '+' => try self.addToken(TokenType.PLUS, null),
            ';' => try self.addToken(TokenType.SEMICOLON, null),
            '*' => try self.addToken(TokenType.STAR, null),
            '!' => try self.addToken(if (self.match('=')) TokenType.BANG_EQUAL else TokenType.BANG, null),
            '=' => try self.addToken(if (self.match('=')) TokenType.EQUAL_EQUAL else TokenType.EQUAL, null),
            '<' => try self.addToken(if (self.match('=')) TokenType.LESS_EQUAL else TokenType.LESS, null),
            '>' => try self.addToken(if (self.match('=')) TokenType.GREATER_EQUAL else TokenType.GREATER, null),
            '/' => {
                if (self.match('/')) {
                    while (self.peek() != '\n' and !self.isAtEnd()) {
                        _ = self.advance();
                    }
                } else {
                    try self.addToken(TokenType.SLASH, null);
                }
            },
            ' ', '\r', '\t' => {},
            '\n' => {
                self.line += 1;
            },
            '"' => try self.string(),

            else => {
                if (isDigit(c)) {
                    try self.number();
                } else if (isAlpha(c)) {
                    try self.identifier();
                } else {
                    errors.reportError(self.line, "unexpected character");
                }
            },
        }
    }

    fn advance(self: *Scanner) u8 {
        self.current += 1;
        return self.source[self.current - 1];
    }

    fn addToken(self: *Scanner, token_type: TokenType, literal: ?LiteralValue) !void {
        const text = self.source[self.start..self.current];
        try self.tokens.append(Token.init(token_type, text, literal, self.line));
    }

    fn match(self: *Scanner, expected: u8) bool {
        if (self.isAtEnd()) return false;
        if (self.source[self.current] != expected) return false;

        self.current += 1;
        return true;
    }

    fn peek(self: *const Scanner) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.current];
    }

    fn peekNext(self: *const Scanner) u8 {
        if (self.current + 1 >= self.source.len) return 0;
        return self.source[self.current + 1];
    }

    fn string(self: *Scanner) !void {
        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') self.line += 1;
            _ = self.advance();
        }

        if (self.isAtEnd()) {
            errors.reportError(self.line, "Unterminated string.");
            return;
        }

        // The closing "
        _ = self.advance();

        // Trim the surrounding quotes
        const value = self.source[self.start + 1 .. self.current - 1];
        try self.addToken(TokenType.STRING, LiteralValue{ .string = value });
    }

    fn number(self: *Scanner) !void {
        while (isDigit(self.peek())) {
            _ = self.advance();
        }

        // Look for a fractional part
        if (self.peek() == '.' and isDigit(self.peekNext())) {
            // Consume the "."
            _ = self.advance();

            while (isDigit(self.peek())) {
                _ = self.advance();
            }
        }

        const num_str = self.source[self.start..self.current];
        const value = std.fmt.parseFloat(f64, num_str) catch {
            errors.reportError(self.line, "Invalid number format");
            return;
        };

        try self.addToken(TokenType.NUMBER, LiteralValue{ .number = value });
    }

    fn identifier(self: *Scanner) !void {
        while (isAlphaNumeric(self.peek())) {
            _ = self.advance();
        }

        const text = self.source[self.start..self.current];
        const tokentype = identifierType(text);

        try self.addToken(tokentype, null);
    }
};

fn isDigit(char: u8) bool {
    return char >= '0' and char <= '9';
}

fn isAlpha(char: u8) bool {
    return (char >= 'a' and char <= 'z') or (char >= 'A' and char <= 'Z') or char == '_';
}

fn isAlphaNumeric(char: u8) bool {
    return isAlpha(char) or isDigit(char);
}

const keywords = std.StaticStringMap(TokenType).initComptime(.{
    .{ "and", TokenType.AND },
    .{ "class", TokenType.CLASS },
    .{ "else", TokenType.ELSE },
    .{ "false", TokenType.FALSE },
    .{ "for", TokenType.FOR },
    .{ "fun", TokenType.FUN },
    .{ "if", TokenType.IF },
    .{ "nil", TokenType.NIL },
    .{ "or", TokenType.OR },
    .{ "print", TokenType.PRINT },
    .{ "return", TokenType.RETURN },
    .{ "super", TokenType.SUPER },
    .{ "this", TokenType.THIS },
    .{ "true", TokenType.TRUE },
    .{ "var", TokenType.VAR },
    .{ "while", TokenType.WHILE },
});

fn identifierType(text: []const u8) TokenType {
    return keywords.get(text) orelse TokenType.IDENTIFIER;
}
