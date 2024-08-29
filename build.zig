// Copyright © 2024 Dimitris Dinodimos.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const root_source_file = b.path("src/recover.zig");
    const link_libc = if (target.result.os.tag != .windows) true else null;
    const recover_module = b.addModule("recover", .{
        .root_source_file = root_source_file,
        .link_libc = link_libc,
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
    const test_source_file = b.path("src/test.zig");
    const exe = b.addExecutable(.{
        .name = "test-recover",
        .root_source_file = test_source_file,
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("recover", recover_module);
    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("test", "Run tests");
    run_step.dependOn(&run_exe.step);

    // check:
    const exe_check = b.addExecutable(.{
        .name = "test-recover",
        .root_source_file = test_source_file,
        .target = target,
        .optimize = optimize,
    });
    exe_check.root_module.addImport("recover", recover_module);
    const check_step = b.step("check", "Check if compiles");
    check_step.dependOn(&exe_check.step);
}
