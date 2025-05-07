const std = @import("std");
const Scanner = @import("scanner.zig").Scanner;
const Parser = @import("parser.zig").Parser;
const ast_expr = @import("expressions.zig");
const ast_stmt = @import("statements.zig");

pub const Interpreter = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Interpreter {
        return Interpreter{
            .allocator = allocator,
        };
    }

    pub fn interpret(
        self: *Interpreter,
        statements: []*ast_stmt.Stmt,
        writer: anytype,
    ) !void {
        for (statements) |stmt_ptr| {
            stmt_ptr.execute(self.allocator, writer) catch |runtime_err| {
                self.reportRuntimeError(runtime_err, writer);
                // For now, stop on the first runtime error.
                // The book's Lox.runtimeError sets a flag and might not throw.
                return; // Or return the error: return runtime_err;
            };
        }
    }

    fn reportRuntimeError(self: *Interpreter, err: anyerror, writer: anytype) void {
        _ = self; // Mark unused for now
        writer.print("Runtime Error: {any}\n", .{err}) catch |e| {
            std.debug.print("Failed to write runtime error: {any}, Original error: {any}\n", .{ e, err });
        };
    }
};
