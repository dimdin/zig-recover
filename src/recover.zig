// Copyright © 2024 Dimitris Dinodimos.

//! Panic recover.
//! Regains control of the calling thread when the function panics or behaves
//! undefined.

const std = @import("std");
const builtin = @import("builtin");

const Context = if (builtin.os.tag == .windows)
    std.os.windows.CONTEXT
else if (builtin.os.tag == .linux and builtin.abi == .musl)
    musl.jmp_buf
else
    std.c.ucontext_t;

threadlocal var top_ctx: ?*const Context = null;

/// Returns if there was no recover call in current thread.
/// Otherwise, does not return and execution continues from the current thread
/// recover call.
/// Call from root source file panic handler.
pub fn panicked() void {
    if (top_ctx) |ctx| {
        setContext(ctx);
    }
}

// returns true if zig is using the old names of types
fn OLD() bool {
    comptime {
        const zig_version = @import("builtin").zig_version;
        const version = std.SemanticVersion{
            .major = 0,
            .minor = 14,
            .patch = 0,
            .pre = "dev",
        };
        return zig_version.order(version) == .lt;
    }
}

// comptime function that extends T by combining its error set with error.Panic
fn ExtErrType(T: type) type {
    const E = error{Panic};

    if (OLD()) {
        const info = @typeInfo(T);
        if (info != .ErrorUnion) {
            return E!T;
        }
        return (info.ErrorUnion.error_set || E)!(info.ErrorUnion.payload);
    }

    const info = @typeInfo(T);
    if (info != .error_union) {
        return E!T;
    }
    return (info.error_union.error_set || E)!(info.error_union.payload);
}

// comptime function that returns the return type of function `func`
fn ReturnType(func: anytype) type {
    const ti = @typeInfo(@TypeOf(func));
    if (OLD()) {
        return ti.Fn.return_type.?;
    }
    return ti.@"fn".return_type.?;
}

/// Calls `func` with `args`, guarding from runtime errors.
/// Returns `error.Panic` when recovers from runtime error.
/// Otherwise returns the return value of func.
pub fn call(
    func: anytype,
    args: anytype,
) ExtErrType(ReturnType(func)) {
    const prev_ctx: ?*const Context = top_ctx;
    var ctx: Context = std.mem.zeroes(Context);
    getContext(&ctx);
    if (top_ctx != prev_ctx) {
        top_ctx = prev_ctx;
        return error.Panic;
    }
    top_ctx = &ctx;
    defer top_ctx = prev_ctx;
    return @call(.auto, func, args);
}

// windows
const CONTEXT = std.os.windows.CONTEXT;
const EXCEPTION_RECORD = std.os.windows.EXCEPTION_RECORD;
const WINAPI = std.os.windows.WINAPI;
extern "ntdll" fn RtlRestoreContext(
    ContextRecord: *const CONTEXT,
    ExceptionRecord: ?*const EXCEPTION_RECORD,
) callconv(WINAPI) noreturn;

// darwin, bsd, gnu linux
extern "c" fn setcontext(ucp: *const std.c.ucontext_t) noreturn;

// linux musl
const musl = struct {
    const jmp_buf = @cImport(@cInclude("setjmp.h")).jmp_buf;
    extern fn setjmp(env: *jmp_buf) c_int;
    extern fn longjmp(env: *const jmp_buf, val: c_int) noreturn;
};

inline fn getContext(ctx: *Context) void {
    if (builtin.os.tag == .windows) {
        std.os.windows.ntdll.RtlCaptureContext(ctx);
    } else if (builtin.os.tag == .linux and builtin.abi == .musl) {
        _ = musl.setjmp(ctx);
    } else {
        _ = std.debug.getContext(ctx);
    }
}

inline fn setContext(ctx: *const Context) noreturn {
    if (builtin.os.tag == .windows) {
        RtlRestoreContext(ctx, null);
    } else if (builtin.os.tag == .linux and builtin.abi == .musl) {
        musl.longjmp(ctx, 1);
    } else {
        setcontext(ctx);
    }
}

/// Panic handler that if there is a recover call in current thread continues
/// from recover call. Otherwise calls the default panic.
/// Install at root source file as `pub const panic = @import("recover").panic;`
pub fn panic(
    msg: []const u8,
    error_return_trace: ?*std.builtin.StackTrace,
    ret_addr: ?usize,
) noreturn {
    panicked();
    if (@hasDecl(std.builtin, "default_panic")) {
        std.builtin.default_panic(msg, error_return_trace, ret_addr);
    } else {
        std.debug.defaultPanic(msg, error_return_trace, ret_addr);
    }
}
