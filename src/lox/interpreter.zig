const std = @import("std");
const Scanner = @import("scanner.zig").Scanner;
const Parser = @import("parser.zig").Parser;
const ast = @import("expressions.zig");

pub const Interpreter = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Interpreter {
        return Interpreter{
            .allocator = allocator,
        };
    }

    pub fn interpret(self: *Interpreter, source: []const u8) !void {
        var scanner = try Scanner.init(self.allocator, source);
        const tokens = try scanner.scanTokens();

        var parser = Parser.init(self.allocator, tokens);
        const maybe_ast_root = parser.parse();

        if (parser.hadError) {
            return;
        }

        if (maybe_ast_root) |ast_root| {
            const result = ast_root.evaluate(self.allocator) catch |err| {
                self.reportRuntimeError(err);
                return;
            };
            var writer = std.io.getStdOut().writer();
            try writer.print("{any}\n", .{result});
        } else {
            // Handle null AST if necessary
        }
    }

    fn reportRuntimeError(self: *Interpreter, err: anyerror) void {
        // TODO: Implement runtime error reporting
        _ = self;
        std.debug.print("Runtime Error Placeholder: {any}\n", .{err});
    }
};
