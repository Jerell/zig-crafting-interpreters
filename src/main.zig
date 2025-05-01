const std = @import("std");
const Scanner = @import("lox/scanner.zig").Scanner;
const errors = @import("lox/errors.zig");
const expressions = @import("lox/expressions.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len > 2) {
        std.debug.print("Usage: jlox [script]\n", .{});
        std.process.exit(64);
    } else if (args.len == 2) {
        try runFile(args[1]); // Use args[1] for the script path
    } else {
        try runPrompt(allocator);
    }

    for (args, 0..) |arg, i| {
        std.debug.print("args[{}] = {s}\n", .{ i, arg });
    }

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // don't forget to flush!
}

pub fn runFile(path: []const u8) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();

    // Allocate memory for the contents
    var allocator = std.heap.page_allocator;
    const bytes = try allocator.alloc(u8, file_size);
    defer allocator.free(bytes);

    // Read the entire file
    _ = try file.readAll(bytes);

    try run(allocator, bytes);
    if (errors.had_error) {
        std.process.exit(65);
    }
}

fn runPrompt(allocator: std.mem.Allocator) !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    var buffer: [1024]u8 = undefined;

    while (true) {
        try stdout.writeAll("> ");
        const line = stdin.readUntilDelimiterOrEof(&buffer, '\n') catch |err| {
            std.debug.print("Error reading input: {}\n", .{err});
            continue;
        } orelse break;

        try run(allocator, line);
        errors.had_error = false;
    }
}

fn run(allocator: std.mem.Allocator, source: []const u8) !void {
    var scanner = try Scanner.init(allocator, source);
    defer scanner.deinit(); // Clean up the scanner resources

    const tokens = try scanner.scanTokens();

    // For now, just print the tokens
    for (tokens) |token| {
        std.debug.print("{any}\n", .{token});
    }
}

test "simple test" {
    _ = expressions;
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
