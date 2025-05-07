const std = @import("std");
const ast_expr = @import("expressions.zig");

pub const Stmt = union(enum) {
    expression: ExpressionStmt,
    print: PrintStmt,

    pub fn execute(
        self: *Stmt,
        allocator: std.mem.Allocator,
        writer: anytype,
    ) anyerror!void {
        switch (self.*) {
            .expression => |*stmt_variant| try stmt_variant.execute(allocator, writer),
            .print => |*stmt_variant| try stmt_variant.execute(allocator, writer),
        }
    }
};

pub const ExpressionStmt = struct {
    expression: *ast_expr.Expr,

    pub fn execute(
        self: *ExpressionStmt,
        allocator: std.mem.Allocator,
        writer: anytype,
    ) anyerror!void {
        _ = writer;
        _ = try self.expression.evaluate(allocator);
    }
};

pub const PrintStmt = struct {
    expression: *ast_expr.Expr,

    pub fn execute(
        self: *PrintStmt,
        allocator: std.mem.Allocator,
        writer: anytype,
    ) anyerror!void {
        const value = try self.expression.evaluate(allocator);

        switch (value) {
            .number => |n| try writer.print("{d}\n", .{n}),
            .string => |s| try writer.print("{s}\n", .{s}),
            .boolean => |b| try writer.print("{}\n", .{b}),
            .nil => try writer.print("nil\n", .{}),
        }
    }
};
