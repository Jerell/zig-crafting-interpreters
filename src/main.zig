const std = @import("std");
const lox = @import("lox");

pub fn main() !void {
    // Use an ArenaAllocator for the entire process (parsing, AST, etc.)
    // This simplifies cleanup significantly, especially on error paths.
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit(); // Frees all memory allocated by the arena at once
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    // No need to free args individually, arena takes care of it

    var had_error: bool = false;

    if (args.len > 2) {
        std.debug.print("Usage: jlox [script]\n", .{});
        std.process.exit(64);
    } else if (args.len == 2) {
        // Pass the arena allocator down
        had_error = runFile(allocator, args[1]) catch |err| {
            // Handle file system or other fatal errors from runFile
            std.debug.print("Error running file: {any}\n", .{err});
            std.process.exit(70); // Indicate internal software error
        };
    } else {
        // Pass the arena allocator down
        runPrompt(allocator) catch |err| {
            // Handle fatal errors from runPrompt
            std.debug.print("Error running prompt: {any}\n", .{err});
            std.process.exit(70);
        };
        // REPL errors are handled line-by-line, don't exit process
    }

    // Exit with appropriate code if errors occurred during script execution
    if (had_error) {
        std.process.exit(65); // Indicate data format error (syntax error)
    }
}

// Runs a script file. Returns true if a Lox runtime/syntax error occurred.
fn runFile(allocator: std.mem.Allocator, path: []const u8) !bool {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const bytes = try file.readToEndAlloc(allocator, std.math.maxInt(usize));

    var interpreter = try lox.Interpreter.init(allocator);

    interpreter.interpret(bytes) catch |err| {
        // Handle fatal errors from interpret itself (rare?)
        std.debug.print("Fatal Interpreter Error: {any}\n", .{err});
        return true; // Indicate error
    };

    // Return interpreter.hadRuntimeError || interpreter.hadSyntaxError (if flags exist)
    // For now, let's assume interpret handles reporting, main handles exit codes based on file vs repl
    return false; // Placeholder - need better error propagation
}

// Runs the interactive prompt (REPL).
fn runPrompt(allocator: std.mem.Allocator) !void {
    var interpreter = try lox.Interpreter.init(allocator);

    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    var input_buffer = std.ArrayList(u8).init(allocator);
    defer input_buffer.deinit(); // Still need to deinit ArrayList buffer itself

    while (true) {
        try stdout.writeAll("> ");
        // Read line into a dynamic buffer using the allocator
        try stdin.streamUntilDelimiter(input_buffer.writer(), '\n', null);

        interpreter.interpret(input_buffer.items) catch |err| {
            // Handle fatal errors from interpret itself (rare?)
            std.debug.print("Fatal Interpreter Error: {any}\n", .{err});
            // Decide whether to break or continue REPL
        };

        input_buffer.clearRetainingCapacity();
    }
}
