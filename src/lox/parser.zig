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

    fn expression(self: *Parser) (ParseError || error{OutOfMemory})!*ast.Expr {
        return self.equality();
    }

    fn equality(self: *Parser) (ParseError || error{OutOfMemory})!*ast.Expr {
        var expr_ptr = try self.comparison();

        while (self.match(&.{ TokenType.BANG_EQUAL, TokenType.EQUAL_EQUAL })) {
            const operator_token = self.previous();
            const right_ptr = try self.comparison();

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

    fn comparison(self: *Parser) (ParseError || error{OutOfMemory})!*ast.Expr {
        var expr_ptr = try self.term();

        while (self.match(&.{
            TokenType.GREATER,
            TokenType.GREATER_EQUAL,
            TokenType.LESS,
            TokenType.LESS_EQUAL,
        })) {
            const operator_token = self.previous();
            const right_ptr = try self.term();

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

    fn term(self: *Parser) (ParseError || error{OutOfMemory})!*ast.Expr {
        var expr_ptr = try self.factor();

        while (self.match(&.{ TokenType.MINUS, TokenType.PLUS })) {
            const operator_token = self.previous();
            const right_ptr = try self.factor();

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

    fn factor(self: *Parser) (ParseError || error{OutOfMemory})!*ast.Expr {
        var expr_ptr = try self.unary();

        while (self.match(&.{ TokenType.SLASH, TokenType.STAR })) {
            const operator_token = self.previous();
            const right_ptr = try self.unary();

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

    fn unary(self: *Parser) (ParseError || error{OutOfMemory})!*ast.Expr {
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

    fn primary(self: *Parser) (ParseError || error{OutOfMemory})!*ast.Expr {
        if (self.match(&.{TokenType.FALSE})) {
            const node_ptr = try self.allocator.create(ast.Expr);
            node_ptr.* = ast.Expr{
                .literal = ast.Literal{ .value = ast.LiteralValue{ .boolean = false } },
            };
            return node_ptr;
        }

        if (self.match(&.{TokenType.TRUE})) {
            const node_ptr = try self.allocator.create(ast.Expr);
            node_ptr.* = ast.Expr{
                .literal = ast.Literal{ .value = ast.LiteralValue{ .boolean = true } },
            };
            return node_ptr;
        }

        if (self.match(&.{TokenType.NIL})) {
            const node_ptr = try self.allocator.create(ast.Expr);
            node_ptr.* = ast.Expr{
                .literal = ast.Literal{ .value = ast.LiteralValue.nil },
            };
            return node_ptr;
        }

        if (self.match(&.{TokenType.NUMBER})) {
            const literal_value = self.previous().literal.?;
            std.debug.assert(literal_value == .number);
            const node_ptr = try self.allocator.create(ast.Expr);
            node_ptr.* = ast.Expr{
                .literal = ast.Literal{ .value = ast.LiteralValue{ .number = literal_value.number } },
            };
            return node_ptr;
        }

        if (self.match(&.{TokenType.STRING})) {
            const literal_value = self.previous().literal.?;
            std.debug.assert(literal_value == .string);
            const node_ptr = try self.allocator.create(ast.Expr);
            node_ptr.* = ast.Expr{
                .literal = ast.Literal{ .value = ast.LiteralValue{ .string = literal_value.string } },
            };
            return node_ptr;
        }

        if (self.match(&.{TokenType.LEFT_PAREN})) {
            const inner_expr = try self.expression();
            _ = try self.consume(TokenType.RIGHT_PAREN, "Expect ')' after expression.");

            const grouping_node_ptr = try self.allocator.create(ast.Expr);
            grouping_node_ptr.* = ast.Expr{
                .grouping = ast.Grouping{ .expression = inner_expr },
            };
            return grouping_node_ptr;
        }

        return self.reportParseError(self.peek(), "Expect expression.");
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
        return self.peek().type == ttype;
    }

    fn advance(self: *Parser) Token {
        if (!self.isAtEnd()) {
            self.current += 1;
        }
        return self.previous();
    }

    fn isAtEnd(self: *const Parser) bool {
        return self.peek().type == TokenType.EOF;
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
        reportTokenError(self.allocator, token, message);
        return ParseError.ExpectedToken;
    }

    fn synchronize(self: *Parser) void {
        self.advance();

        while (!self.isAtEnd()) {
            if (self.previous().type == TokenType.SEMICOLON) {
                return;
            }
            switch (self.peek().type) {
                TokenType.CLASS, TokenType.FUN, TokenType.VAR, TokenType.FOR, TokenType.IF, TokenType.WHILE, TokenType.PRINT, TokenType.RETURN => return,
            }

            self.advance();
        }
    }

    pub fn parse(self: *Parser) ?*ast.Expr {
        const expr = self.expression() catch {
            // If expression() propagates an error (e.g. ExpectedExpression from primary)
            // self.hadError should already be true via reportParseError.
            // Return null to indicate failure.
            return null;
        };
        // Also return null if syntax errors were reported even if expression() returned something.
        if (self.hadError) return null;
        return expr;
    }
};

pub fn reportTokenError(
    allocator: std.mem.Allocator,
    token: Token,
    message: []const u8,
) void {
    if (token.type == .EOF) {
        errors.report(token.line, " at end", message);
    } else {
        const msg_prefix = std.fmt.allocPrint(allocator, " at '{s}'", .{token.lexeme}) catch " at token";
        defer allocator.free(msg_prefix);
        errors.report(token.line, msg_prefix, message);
    }
}

const ParseError = error{
    ExpectedToken,
    UnexpectedToken,
    ExpectedExpression,
};
