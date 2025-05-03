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

    fn comparison(self: *Parser) !*ast.Expr {
        var expr_ptr = try self.term();

        while (self.match(&.{
            TokenType.GREATER,
            TokenType.GREATER_EQUAL,
            TokenType.LESS,
            TokenType.LESS_EQUAL,
        })) {
            const operator_token = self.previous();
            const right_ptr = try self.term();
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

    fn term(self: *Parser) !*ast.Expr {
        var expr_ptr = try self.factor();

        while (self.match(&.{ TokenType.MINUS, TokenType.PLUS })) {
            const operator_token = self.previous();
            const right_ptr = try self.factor();
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

    fn factor(self: *Parser) !*ast.Expr {
        var expr_ptr = try self.unary();

        while (self.match(&.{ TokenType.SLASH, TokenType.STAR })) {
            const operator_token = self.previous();
            const right_ptr = try self.unary();
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
    }

    fn unary(self: *Parser) !*ast.Expr {
        if (self.match(&.{ TokenType.BANG, TokenType.MINUS })) {
            const operator_token = self.previous();
            const right_ptr = try self.unary();

            const new_unary_expr_ptr = try self.allocator.create(ast.Expr);

            new_unary_expr_ptr.* = ast.Expr{
                .unary = ast.Unary{
                    .operator = operator_token,
                    .right = right_ptr,
                },
            };
            return new_unary_expr_ptr;
        }
        return self.primary();
    }

    fn primary(self: *Parser) !*ast.Expr {
        const new_primary_expr_ptr = try self.allocator.create(ast.Expr);

        if (self.match(&.{TokenType.FALSE})) {
            new_primary_expr_ptr.* = ast.Expr{
                .literal = ast.Literal{
                    .value = ast.LiteralValue{ .boolean = false },
                },
            };
        }

        if (self.match(&.{TokenType.TRUE})) {
            new_primary_expr_ptr.* = ast.Expr{
                .literal = ast.Literal{
                    .value = ast.LiteralValue{ .boolean = true },
                },
            };
        }

        if (self.match(&.{TokenType.NIL})) {
            new_primary_expr_ptr.* = ast.Expr{
                .literal = ast.Literal{
                    .value = ast.LiteralValue.nil,
                },
            };
        }

        if (self.match(&.{TokenType.NUMBER})) {
            new_primary_expr_ptr.* = ast.Expr{
                .literal = ast.Literal{
                    .value = ast.LiteralValue{
                        .number = self.previous().literal,
                    },
                },
            };
        }

        if (self.match(&.{TokenType.STRING})) {
            new_primary_expr_ptr.* = ast.Expr{
                .literal = ast.Literal{
                    .value = ast.LiteralValue{
                        .string = self.previous().literal,
                    },
                },
            };
        }

        if (self.match(&.{TokenType.LEFT_PAREN})) {
            new_primary_expr_ptr.* = self.expression();
            self.consume(TokenType.RIGHT_PAREN, "Expect ')' after expression.");
        }

        return new_primary_expr_ptr;
    }

    fn match(self: *Parser, types: []const TokenType) bool {
        for (types) |ttype| {
            if (self.check(ttype)) {
                _ = self.advance();
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
