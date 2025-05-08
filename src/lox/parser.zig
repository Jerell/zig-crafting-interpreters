const std = @import("std");
const assert = @import("std").debug.assert;
const Token = @import("token.zig").Token;
const TokenType = @import("tokentype.zig").TokenType;
const ast_expr = @import("expressions.zig");
const ast_stmt = @import("statements.zig");
const errors = @import("errors.zig");

pub const Parser = struct {
    tokens: []const Token,
    current: usize,
    allocator: std.mem.Allocator,
    hadError: bool,

    pub fn init(allocator: std.mem.Allocator, tokens: []const Token) Parser {
        assert(tokens.len > 0 and tokens[tokens.len - 1].type == TokenType.EOF);
        return Parser{
            .tokens = tokens,
            .current = 0,
            .allocator = allocator,
            .hadError = false,
        };
    }

    fn expression(self: *Parser) ParseError!*ast_expr.Expr {
        return self.equality();
    }

    fn equality(self: *Parser) ParseError!*ast_expr.Expr {
        var expr_ptr = try self.comparison();

        while (self.match(&.{ TokenType.BANG_EQUAL, TokenType.EQUAL_EQUAL })) {
            const operator_token = self.previous();
            const right_ptr = try self.comparison();

            const new_binary_expr_ptr = try self.allocator.create(ast_expr.Expr);

            new_binary_expr_ptr.* = ast_expr.Expr{
                .binary = ast_expr.Binary{
                    .left = expr_ptr,
                    .operator = operator_token,
                    .right = right_ptr,
                },
            };
            expr_ptr = new_binary_expr_ptr;
        }
        return expr_ptr;
    }

    fn comparison(self: *Parser) ParseError!*ast_expr.Expr {
        var expr_ptr = try self.term();

        while (self.match(&.{
            TokenType.GREATER,
            TokenType.GREATER_EQUAL,
            TokenType.LESS,
            TokenType.LESS_EQUAL,
        })) {
            const operator_token = self.previous();
            const right_ptr = try self.term();

            const new_binary_expr_ptr = try self.allocator.create(ast_expr.Expr);

            new_binary_expr_ptr.* = ast_expr.Expr{
                .binary = ast_expr.Binary{
                    .left = expr_ptr,
                    .operator = operator_token,
                    .right = right_ptr,
                },
            };
            expr_ptr = new_binary_expr_ptr;
        }
        return expr_ptr;
    }

    fn term(self: *Parser) ParseError!*ast_expr.Expr {
        var expr_ptr = try self.factor();

        while (self.match(&.{ TokenType.MINUS, TokenType.PLUS })) {
            const operator_token = self.previous();
            const right_ptr = try self.factor();

            const new_binary_expr_ptr = try self.allocator.create(ast_expr.Expr);

            new_binary_expr_ptr.* = ast_expr.Expr{
                .binary = ast_expr.Binary{
                    .left = expr_ptr,
                    .operator = operator_token,
                    .right = right_ptr,
                },
            };
            expr_ptr = new_binary_expr_ptr;
        }
        return expr_ptr;
    }

    fn factor(self: *Parser) ParseError!*ast_expr.Expr {
        var expr_ptr = try self.unary();

        while (self.match(&.{ TokenType.SLASH, TokenType.STAR })) {
            const operator_token = self.previous();
            const right_ptr = try self.unary();

            const new_binary_expr_ptr = try self.allocator.create(ast_expr.Expr);

            new_binary_expr_ptr.* = ast_expr.Expr{
                .binary = ast_expr.Binary{
                    .left = expr_ptr,
                    .operator = operator_token,
                    .right = right_ptr,
                },
            };
            expr_ptr = new_binary_expr_ptr;
        }

        return expr_ptr;
    }

    fn unary(self: *Parser) ParseError!*ast_expr.Expr {
        if (self.match(&.{ TokenType.BANG, TokenType.MINUS })) {
            const operator_token = self.previous();
            const right_ptr = try self.unary();

            const new_unary_expr_ptr = try self.allocator.create(ast_expr.Expr);

            new_unary_expr_ptr.* = ast_expr.Expr{
                .unary = ast_expr.Unary{
                    .operator = operator_token,
                    .right = right_ptr,
                },
            };
            return new_unary_expr_ptr;
        }
        return self.primary();
    }

    fn primary(self: *Parser) ParseError!*ast_expr.Expr {
        if (self.match(&.{TokenType.FALSE})) {
            const node_ptr = try self.allocator.create(ast_expr.Expr);
            node_ptr.* = ast_expr.Expr{
                .literal = ast_expr.Literal{ .value = ast_expr.LiteralValue{ .boolean = false } },
            };
            return node_ptr;
        }

        if (self.match(&.{TokenType.TRUE})) {
            const node_ptr = try self.allocator.create(ast_expr.Expr);
            node_ptr.* = ast_expr.Expr{
                .literal = ast_expr.Literal{ .value = ast_expr.LiteralValue{ .boolean = true } },
            };
            return node_ptr;
        }

        if (self.match(&.{TokenType.NIL})) {
            const node_ptr = try self.allocator.create(ast_expr.Expr);
            node_ptr.* = ast_expr.Expr{
                .literal = ast_expr.Literal{ .value = ast_expr.LiteralValue.nil },
            };
            return node_ptr;
        }

        if (self.match(&.{TokenType.NUMBER})) {
            const literal_value = self.previous().literal.?;
            std.debug.assert(literal_value == .number);
            const node_ptr = try self.allocator.create(ast_expr.Expr);
            node_ptr.* = ast_expr.Expr{
                .literal = ast_expr.Literal{ .value = ast_expr.LiteralValue{ .number = literal_value.number } },
            };
            return node_ptr;
        }

        if (self.match(&.{TokenType.STRING})) {
            const literal_value = self.previous().literal.?;
            std.debug.assert(literal_value == .string);
            const node_ptr = try self.allocator.create(ast_expr.Expr);
            node_ptr.* = ast_expr.Expr{
                .literal = ast_expr.Literal{ .value = ast_expr.LiteralValue{ .string = literal_value.string } },
            };
            return node_ptr;
        }

        if (self.match(&.{TokenType.LEFT_PAREN})) {
            const inner_expr = try self.expression();
            _ = try self.consume(TokenType.RIGHT_PAREN, "Expect ')' after expression.");

            const grouping_node_ptr = try self.allocator.create(ast_expr.Expr);
            grouping_node_ptr.* = ast_expr.Expr{
                .grouping = ast_expr.Grouping{ .expression = inner_expr },
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
        _ = self.advance();

        while (!self.isAtEnd()) {
            if (self.previous().type == TokenType.SEMICOLON) {
                return;
            }
            switch (self.peek().type) {
                TokenType.CLASS, TokenType.FUN, TokenType.VAR, TokenType.FOR, TokenType.IF, TokenType.WHILE, TokenType.PRINT, TokenType.RETURN => return,
                else => {},
            }

            _ = self.advance();
        }
    }

    pub fn parse(self: *Parser) ?[]*ast_stmt.Stmt {
        var statements = std.ArrayList(*ast_stmt.Stmt).init(self.allocator);

        while (!self.isAtEnd()) {
            const stmt_ptr = self.declaration() catch |err| {
                if (err == error.OutOfMemory) {
                    self.hadError = true;
                    std.debug.print("Out of memory during parsing.\n", .{});
                    return null;
                }
                self.synchronize();
                continue;
            };

            statements.append(stmt_ptr) catch |oom_err| {
                self.hadError = true;
                std.debug.print("Failed to append statement to list: {any}\n", .{oom_err});
                return null;
            };
        }

        if (self.hadError) {
            return null;
        }

        return statements.toOwnedSlice() catch |oom_err| {
            self.hadError = true;
            std.debug.print("Failed to finalize statement list: {any}\n", .{oom_err});
            return null;
        };
    }

    fn statement(self: *Parser) ParseError!*ast_stmt.Stmt {
        if (self.match(&.{TokenType.PRINT})) {
            return self.printStatement();
        }
        return self.expressionStatement();
    }

    fn printStatement(self: *Parser) ParseError!*ast_stmt.Stmt {
        const value = try self.expression();
        _ = try self.consume(TokenType.SEMICOLON, "Expect ';' after print value");

        const stmt_node_ptr = try self.allocator.create(ast_stmt.Stmt);
        stmt_node_ptr.* = ast_stmt.Stmt{
            .print = ast_stmt.PrintStmt{
                .expression = value,
            },
        };
        return stmt_node_ptr;
    }

    fn expressionStatement(self: *Parser) ParseError!*ast_stmt.Stmt {
        const expr = try self.expression();
        _ = try self.consume(TokenType.SEMICOLON, "Expect ';' after expression");

        const stmt_node_ptr = try self.allocator.create(ast_stmt.Stmt);
        stmt_node_ptr.* = ast_stmt.Stmt{
            .expression = ast_stmt.ExpressionStmt{
                .expression = expr,
            },
        };
        return stmt_node_ptr;
    }

    fn declaration(self: *Parser) ParseError!*ast_stmt.Stmt {
        if (self.match(&.{TokenType.VAR})) {
            return self.varDeclaration();
        }
        return self.statement();
    }

    fn varDeclaration(self: *Parser) ParseError!*ast_stmt.Stmt {
        const name_token = try self.consume(TokenType.IDENTIFIER, "Expect variable name");

        var initializer: ?*ast_expr.Expr = null;
        if (self.match(&.{TokenType.EQUAL})) {
            initializer = try self.expression();
        }

        _ = try self.consume(TokenType.SEMICOLON, "Expect ';' after variable declaration");

        const stmt_node_ptr = try self.allocator.create(ast_stmt.Stmt);
        stmt_node_ptr.* = ast_stmt.Stmt{
            .var_decl = ast_stmt.VarDeclStmt{
                .name = name_token,
                .initializer = initializer,
            },
        };
        return stmt_node_ptr;
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
    OutOfMemory,
};
