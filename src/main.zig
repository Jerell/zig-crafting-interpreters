// src/main.zig
const std = @import("std");
const lox = @import("lox"); // Import the "lox" module defined in build.zig

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

    // Read the entire file using the provided allocator
    const bytes = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    // Arena will free 'bytes' automatically when main returns

    return run(allocator, bytes); // Return the error status from run
}

// Runs the interactive prompt (REPL).
fn runPrompt(allocator: std.mem.Allocator) !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    var input_buffer = std.ArrayList(u8).init(allocator);
    defer input_buffer.deinit(); // Still need to deinit ArrayList buffer itself

    while (true) {
        try stdout.writeAll("> ");
        // Read line into a dynamic buffer using the allocator
        try stdin.streamUntilDelimiter(input_buffer.writer(), '\n', null);

        // Run the line, ignore return value (error reported inside run)
        _ = run(allocator, input_buffer.items) catch |err| {
            // Handle fatal errors during the execution of a single line
            std.debug.print("Runtime error: {any}\n", .{err});
            // Continue the REPL loop
        };

        // Reset buffer for next line, but keep allocated memory
        input_buffer.clearRetainingCapacity();

        // Reset the global error flag for the next line in REPL mode
        // (This is still using the global flag, ideally run would return it)
        // lox.errors.had_error = false; // If you keep the global flag
    }
}

// Executes a block of Lox source code.
// Returns true if a Lox runtime/syntax error occurred.
fn run(allocator: std.mem.Allocator, source: []const u8) !bool {
    _ = allocator;
    _ = source;
    // 1. Scan
    // Scanner doesn't allocate nodes, just the token list.
    // We can use a temporary allocator or the main arena. Arena is fine.
    // var scanner = try lox.Scanner.init(allocator, source);
    // Scanner owns the ArrayList, needs deinit if not using Arena for tokens
    // If Scanner uses the passed allocator (arena), deferring deinit might double-free.
    // Let's assume Scanner *copies* tokens or uses the passed allocator correctly.
    // If Scanner uses the passed allocator for its list, no deinit needed with Arena.
    // Let's modify Scanner.init to just use the allocator, and remove its deinit.
    // **Action Required: Modify Scanner.init to use allocator, remove Scanner.deinit**
    // (Or keep Scanner.deinit and use a separate allocator for it)

    // const tokens = try scanner.scanTokens(); // Returns []Token slice

    // 2. Parse
    // var parser = lox.Parser.init(allocator, tokens); // Pass the arena allocator
    // Parser itself doesn't need deinit if it just borrows tokens and uses
    // the passed allocator for the AST.

    // const statements = parser.parse() catch |err| {
    //     // Handle fundamental parsing errors (e.g., allocation failed in parser)
    //     // These are different from Lox syntax errors reported via parser.hadError
    //     std.debug.print("Internal Parser Error: {any}\n", .{err});
    //     return true; // Indicate an error occurred
    // };
    // // Arena will free the 'statements' slice and all AST nodes automatically.
    //
    // // Check for Lox syntax errors reported during parsing
    // if (parser.hadError) {
    //     return true; // Indicate syntax errors occurred
    // }
    //
    // // 3. TODO: Interpret
    // std.debug.print("Parsing successful. AST:\n", .{});
    // // You'll need a way to print statements/expressions if you want to see the AST
    // // For example:
    // // for (statements) |stmt| {
    // //    try lox.printAst(stmt, std.io.getStdOut().writer()); // Assuming you add printAst
    // //    try std.io.getStdOut().writer().writeAll("\n");
    // // }
    // _ = statements; // Keep statements alive until end of scope for Arena
    //
    return false; // No Lox errors occurred
}
