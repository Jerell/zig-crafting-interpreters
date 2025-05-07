const std = @import("std");
const lox = @import("lox");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);

    var had_error: bool = false;

    if (args.len > 2) {
        std.debug.print("Usage: jlox [script]\n", .{});
        std.process.exit(64);
    } else if (args.len == 2) {
        had_error = runFile(allocator, args[1]) catch |err| {
            std.debug.print("Error running file: {any}\n", .{err});
            std.process.exit(70);
        };
    } else {
        // Pass the arena allocator down
        runPrompt(allocator) catch |err| {
            std.debug.print("Error running prompt: {any}\n", .{err});
            std.process.exit(70);
        };
    }

    if (had_error) {
        std.process.exit(65); // Indicate data format error (syntax error)
    }
}

/// Executes a block of Lox source code.
/// Returns true if a Lox runtime/syntax error occurred.
fn run(
    allocator: std.mem.Allocator,
    source: []const u8,
    interpreter: *lox.Interpreter,
    writer: anytype,
) !bool {
    var scanner = try lox.Scanner.init(allocator, source);
    const tokens = try scanner.scanTokens();

    var parser = lox.Parser.init(allocator, tokens);
    const maybe_statements = parser.parse();

    if (parser.hadError) {
        // Syntax errors already reported by the parser
        return true; // Indicate syntax error occurred
    }

    if (maybe_statements) |statements| {
        interpreter.interpret(statements, writer) catch |err| {
            // This catch is if interpret itself is fallible beyond what execute handles.
            _ = err; // Error already reported by interpreter.reportRuntimeError
            return true;
        };
        // After interpretation, you might check a flag on the interpreter
        // if (interpreter.hadRuntimeError) return true;
    } else {
        // Parsing failed for a reason other than syntax errors (e.g. internal parser issue)
        // or parseStatements() returns null on syntax error too.
        // If parser.hadError is false here, it's an unexpected null from parser.
        std.debug.print("Parsing completed, but no statements were generated (AST is null).\n", .{});
    }

    return false;
}

/// Runs a script file. Returns true if a Lox runtime/syntax error occurred.
fn runFile(allocator: std.mem.Allocator, path: []const u8) !bool {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const bytes = try file.readToEndAlloc(allocator, std.math.maxInt(usize));

    var interpreter = try lox.Interpreter.init(allocator);
    const stdout_writer = std.io.getStdOut().writer();

    return run(allocator, bytes, &interpreter, stdout_writer);
}

/// Runs the interactive prompt (REPL).
fn runPrompt(allocator: std.mem.Allocator) !void {
    var interpreter = try lox.Interpreter.init(allocator);

    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    var input_buffer = std.ArrayList(u8).init(allocator);
    defer input_buffer.deinit(); // Still need to deinit ArrayList buffer itself

    while (true) {
        try stdout.writeAll("> ");
        input_buffer.clearRetainingCapacity();
        try stdin.streamUntilDelimiter(input_buffer.writer(), '\n', null);

        const had_line_error = run(allocator, input_buffer.items, &interpreter, stdout) catch |err| blk: {
            // This catch handles errors from scanning/parsing within run()
            std.debug.print("Error processing line: {any}\n", .{err});
            break :blk true;
        };

        if (had_line_error) {
            // Error was already reported by parser or interpreter
            // For REPL, we just continue to the next line.
        }
    }
}
