const std = @import("std");
const assert = @import("std").debug.assert;
const Token = @import("token.zig").Token;
const TokenType = @import("tokentype.zig").TokenType;
const ast = @import("expressions.zig");
const errors = @import("errors.zig");

pub const Parser = struct {
    tokens: []const Token,
    current: usize,
    allocator: std.mem.Allocator,
    hadError: bool,

    pub fn init(allocator: std.mem.Allocator, tokens: []Token) Parser {
        assert(tokens.len > 0 and tokens[tokens.len - 1].type == TokenType.EOF);
        return Parser{
            .tokens = tokens,
            .current = 0,
            .allocator = allocator,
            .hadError = false,
        };
    }

    fn expression(self: *Parser) !ast.Expr {
        return self.equality();
    }

    fn equality(self: *Parser) !*ast.Expr {
        var expr_ptr = try self.comparison();
        errdefer self.allocator.destroy(expr_ptr);

        while (self.match(&.{ TokenType.BANG_EQUAL, TokenType.EQUAL_EQUAL })) {
            const operator_token = self.previous();
            const right_ptr = try self.comparison();
            errdefer self.allocator.destroy(right_ptr);

            const new_binary_expr_ptr = try self.allocator.create(ast.Expr);

            new_binary_expr_ptr.* = ast.Expr{
                .binary = ast.Binary{
                    .left = expr_ptr,
                    .operator = operator_token,
                    .right = right_ptr,
                },
            };
            expr_ptr = new_binary_expr_ptr;
        }
        return expr_ptr;
    }

    // Placeholder for comparison - should also return !*ast.Expr
    fn comparison(self: *Parser) !*ast.Expr {
        // TODO: Implement comparison parsing logic similar to equality
        // It will call term() and handle <, <=, >, >= operators
        // For now, let's return a dummy literal to make equality compile
        const literal_node = try self.allocator.create(ast.Expr);
        literal_node.* = ast.Expr{
            .literal = ast.Literal{ .value = ast.LiteralValue.nil },
        };
        return literal_node;
        // return error.ParseError; // Or return an error
    }

    fn match(self: *Parser, types: []const TokenType) bool {
        for (types) |ttype| {
            if (self.check(ttype)) {
                _ = self.advance(); // Consume the token
                return true;
            }
        }
        return false;
    }

    fn check(self: *const Parser, ttype: TokenType) bool {
        if (self.isAtEnd()) return false;
        return self.peek().token_type == ttype;
    }

    fn advance(self: *Parser) Token {
        if (!self.isAtEnd()) {
            self.current += 1;
        }
        return self.previous();
    }

    fn isAtEnd(self: *const Parser) bool {
        return self.peek().token_type == TokenType.EOF;
    }

    fn peek(self: *const Parser) Token {
        return self.tokens[self.current];
    }

    fn previous(self: *const Parser) Token {
        // Should only be called after advance() ensures current > 0
        return self.tokens[self.current - 1];
    }

    fn consume(self: *Parser, ttype: TokenType, message: []const u8) !Token {
        if (self.check(ttype)) {
            return self.advance();
        }
        return self.reportParseError(self.peek(), message);
    }

    fn reportParseError(self: *Parser, token: Token, message: []const u8) ParseError {
        self.hadError = true;
        errors.reportTokenError(token, message);
        return ParseError.ExpectedToken;
    }
};

pub fn reportTokenError(token: Token, message: []const u8) void {
    if (token.token_type == .EOF) {
        errors.reportError(token.line, " at end", message);
    } else {
        // This might require allocation if you want the lexeme in the message.
        // Keep it simple for now, or pass an allocator if needed.
        // const msg_prefix = std.fmt.allocPrint(allocator, " at '{s}'", .{token.lexeme}) catch " at token";
        // defer allocator.free(msg_prefix); // If allocated
        errors.reportError(token.line, " near token", message); // Simplified
    }
}

const ParseError = error{
    ExpectedToken,
    UnexpectedToken,
    ExpectedExpression,
};
