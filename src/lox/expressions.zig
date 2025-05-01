const std = @import("std");
const io = std.io;
const TokenType = @import("tokentype.zig").TokenType;
const Token = @import("token.zig").Token;

pub const Expr = union(enum) {
    binary: Binary,
    unary: Unary,
    literal: Literal,
    grouping: Grouping,
    // variable: Variable,

    // pub fn evaluate(self: *Expr, env: *Environment) !LiteralValue {
    //     switch (self.*) {
    //         .binary => |*binary| return binary.evaluate(env),
    //         .unary => |*unary| return unary.evaluate(env),
    //         .literal => |*literal| return literal.evaluate(env),
    //         .grouping => |*grouping| return grouping.evaluate(env),
    //     }
    // }

    pub fn print(self: Expr, writer: anytype) anyerror!void {
        switch (self) {
            .binary => |binary| return binary.print(writer),
            .unary => |unary| return unary.print(writer),
            .literal => |literal| return literal.print(writer),
            .grouping => |grouping| return grouping.print(writer),
            // .variable => |variable| return variable.print(writer),
        }
    }

    pub fn deinit(self: *Expr, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .binary => |*binary| binary.deinit(allocator),
            .unary => |*unary| unary.deinit(allocator),
            .literal => |*literal| literal.deinit(allocator),
            .grouping => |*grouping| grouping.deinit(allocator),
            // .variable => |*variable| variable.deinit(allocator),
        }
    }
};

pub const Binary = struct {
    left: *Expr,
    operator: Token,
    right: *Expr,

    pub fn print(self: Binary, writer: anytype) anyerror!void {
        try writer.print("({s} ", .{self.operator.lexeme});
        try self.left.print(writer);
        try writer.print(" ", .{});
        try self.right.print(writer);
        try writer.print(")", .{});
    }

    pub fn deinit(self: *Binary, allocator: std.mem.Allocator) void {
        self.left.deinit(allocator);
        allocator.destroy(self.left);
        self.right.deinit(allocator);
        allocator.destroy(self.right);
    }
};

pub const Unary = struct {
    operator: Token,
    right: *Expr,

    pub fn print(self: Unary, writer: anytype) anyerror!void {
        try writer.print("({s} ", .{self.operator.lexeme});
        try self.right.print(writer);
        try writer.print(")", .{});
    }

    pub fn deinit(self: *Unary, allocator: std.mem.Allocator) void {
        self.right.deinit(allocator);
        allocator.destroy(self.right);
    }
};

pub const Literal = struct {
    value: LiteralValue,

    pub fn print(self: Literal, writer: anytype) anyerror!void {
        switch (self.value) {
            .number => |n| try writer.print("{}", .{n}),
            .string => |s| try writer.print("\"{s}\"", .{s}),
            .boolean => |b| try writer.print("{}", .{b}),
            .nil => try writer.print("nil", .{}),
        }
    }

    pub fn deinit(self: *Literal, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }
};

pub const LiteralValue = union(enum) {
    number: f64,
    string: []const u8,
    boolean: bool,
    nil,
};

pub const Grouping = struct {
    expression: *Expr,

    pub fn print(self: Grouping, writer: anytype) anyerror!void {
        try writer.print("(group ", .{});
        try self.expression.print(writer);
        try writer.print(")", .{});
    }

    pub fn deinit(self: *Grouping, allocator: std.mem.Allocator) void {
        self.expression.deinit(allocator);
        allocator.destroy(self.expression);
    }
};

// pub const Variable = struct {
//     name: Token,
//
//     pub fn print(self: Variable) anyerror!void {
//         try writer.print("{}", .{self.name.lexeme});
//     }
//
//     pub fn deinit(self: *Variable, allocator: std.mem.Allocator) void {
//         _ = self;
//         _ = allocator;
//     }
// };

test "AST Printer test" {
    // 1. Get an allocator (using GeneralPurposeAllocator for tests)
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit(); // Ensure allocator resources are freed
    const allocator = gpa.allocator();

    // 2. Allocate nodes on the heap and wrap them in Expr unions

    // Allocate Literal(123)
    const literal123_ptr = try allocator.create(Expr);
    literal123_ptr.* = Expr{
        .literal = Literal{
            .value = LiteralValue{ .number = 123.0 }, // Use f64 literal
        },
    };
    // No defer destroy here, it will be cleaned up by the parent node's deinit

    // Allocate Unary(-)
    const unary_ptr = try allocator.create(Expr);
    unary_ptr.* = Expr{
        .unary = Unary{
            .operator = Token.init(TokenType.MINUS, "-", null, 1),
            .right = literal123_ptr, // Assign the pointer
        },
    };
    // No defer destroy here

    // Allocate Literal(45.67)
    const literal4567_ptr = try allocator.create(Expr);
    literal4567_ptr.* = Expr{ .literal = Literal{
        .value = LiteralValue{ .number = 45.67 },
    } };
    // No defer destroy here

    // Allocate Grouping
    const grouping_ptr = try allocator.create(Expr);
    grouping_ptr.* = Expr{
        .grouping = Grouping{
            .expression = literal4567_ptr, // Assign the pointer
        },
    };
    // No defer destroy here

    // Allocate Binary(*)
    const binary_ptr = try allocator.create(Expr);
    binary_ptr.* = Expr{
        .binary = Binary{
            .left = unary_ptr, // Assign the pointer
            .operator = Token.init(TokenType.STAR, "*", null, 1),
            .right = grouping_ptr, // Assign the pointer
        },
    };
    // Defer destroy for the root of the expression tree
    // The deinit method will recursively destroy children
    defer binary_ptr.deinit(allocator);
    defer allocator.destroy(binary_ptr);

    // 3. Prepare a writer (e.g., writing to a buffer for testing)
    var buffer: [1024]u8 = undefined;
    var fixed_buffer_stream = std.io.fixedBufferStream(&buffer);
    const writer = fixed_buffer_stream.writer();

    // 4. Call print on the root expression
    try binary_ptr.print(writer); // Call print on the Expr pointer

    // 5. Get the result and assert
    const result = fixed_buffer_stream.getWritten();
    const expected = "(* (- 1.23e2) (group 4.567e1))";

    try std.testing.expectEqualStrings(expected, result);
}
