const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 1. Create the Module for the library
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        // Add dependencies for the library itself here if needed later
        // .imports = &.{ ... },
    });

    // 2. Create the static library *from* the module
    const lib = b.addStaticLibrary(.{
        .name = "crafting-interpreters",
        .root_module = lib_mod, // Pass the module here
        // No need for target/optimize here, they are in the module
    });

    b.installArtifact(lib);

    // 3. Create the Module for the executable
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // 4. Add the library module as an import to the executable module
    exe_mod.addImport("lox", lib_mod); // <-- This replaces exe.addModule

    // 5. Create the executable *from* the module
    const exe = b.addExecutable(.{
        .name = "crafting-interpreters",
        .root_module = exe_mod, // Pass the module here
        // No need for target/optimize here, they are in the module
    });

    // 6. Link the library artifact (still necessary for symbols)
    exe.linkLibrary(lib);

    // DELETE the old way:
    // exe.addModule("lox", lib.root_module);

    b.installArtifact(exe);

    // --- Rest of your build script (run steps, test steps) ---
    // Note: Test steps should also be updated to use .root_module

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Update test steps
    const lib_unit_tests = b.addTest(.{
        .name = "crafting-interpreters-lib-test", // Optional: distinct name
        .root_module = lib_mod, // Use the library module
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .name = "crafting-interpreters-exe-test", // Optional: distinct name
        .root_module = exe_mod, // Use the executable module
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
