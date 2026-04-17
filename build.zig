// SPDX-FileCopyrightText: © 2024 Dimitris Dinodimos
// SPDX-License-Identifier: MIT

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const target_windows = target.result.os.tag == .windows;
    const translate_c = b.addTranslateC(.{
        .root_source_file = b.path("src/c.h"),
        .target = target,
        .optimize = optimize,
    });
    const recover_module = b.addModule("recover", .{
        .root_source_file = b.path("src/recover.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = if (target_windows) null else true,
        .imports = if (target_windows)
            &.{}
        else
            &.{
                .{
                    .name = "c",
                    .module = translate_c.createModule(),
                },
            },
    });

    // docs:
    const doc_tests = b.addLibrary(.{
        .name = "recover",
        .linkage = .static,
        .root_module = recover_module,
    });
    const install_docs = b.addInstallDirectory(.{
        .source_dir = doc_tests.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Generate documentation");
    docs_step.dependOn(&install_docs.step);

    // test:
    const test_module = b.createModule(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_module.addImport("recover", recover_module);
    const exe = b.addExecutable(.{
        .name = "test-recover",
        .root_module = test_module,
    });
    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("test", "Run tests");
    run_step.dependOn(&run_exe.step);

    // check:
    const exe_check = b.addExecutable(.{
        .name = "test-recover",
        .root_module = test_module,
    });
    exe_check.root_module.addImport("recover", recover_module);
    const check_step = b.step("check", "Check if compiles");
    check_step.dependOn(&exe_check.step);
}
