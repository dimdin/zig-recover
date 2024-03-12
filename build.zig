// Copyright © 2024 Dimitris Dinodimos.

const std = @import("std");

pub fn build(b: *std.Build) void {
    b.top_level_steps = .{};

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const root_source_file = .{ .path = "src/recover.zig" };

    const recover_module = b.addModule("recover", .{
        .root_source_file = root_source_file,
        .link_libc = if (target.result.os.tag != .windows) true else null,
    });

    // docs:
    const doc_tests = b.addStaticLibrary(.{
        .name = "recover",
        .root_source_file = root_source_file,
        .target = target,
        .optimize = optimize,
    });
    const install_docs = b.addInstallDirectory(.{
        .source_dir = doc_tests.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Generate documentation");
    docs_step.dependOn(&install_docs.step);

    // test:
    const exe = b.addExecutable(.{
        .name = "test-recover",
        .root_source_file = .{ .path = "src/test.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("recover", recover_module);
    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("test", "Run tests");
    run_step.dependOn(&run_exe.step);

    // clean:
    const clean_step = b.step("clean", "Clean up");
    clean_step.dependOn(&b.addRemoveDirTree(b.install_path).step);
    if (@import("builtin").os.tag != .windows) {
        clean_step.dependOn(&b.addRemoveDirTree(b.pathFromRoot("zig-cache")).step);
    }

    // all: docs test
    const all_step = b.step("all", "Generate documentation and run tests");
    b.default_step = all_step;
    all_step.dependOn(docs_step);
    all_step.dependOn(run_step);
}
