// Copyright © 2024 Dimitris Dinodimos.

//! Panic recover.
//! Regains control of the calling thread when the function panics or behaves
//! undefined.

const std = @import("std");
const builtin = @import("builtin");

const is_windows: bool = (builtin.os.tag == .windows);

const Context = if (is_windows)
    std.os.windows.CONTEXT
else
    c.jmp_buf;

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

// comptime function that extends T by combining its error set with
// `error.Panic`
fn ExtErrType(T: type) type {
    const E = error{Panic};
    const info = @typeInfo(T);
    if (info != .error_union) {
        return E!T;
    }
    return (info.error_union.error_set || E)!(info.error_union.payload);
}

// comptime function that returns the return type of function `func`
fn ReturnType(func: anytype) type {
    const ti = @typeInfo(@TypeOf(func));
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

const windows = struct {
    const CONTEXT = std.os.windows.CONTEXT;
    const EXCEPTION_RECORD = std.os.windows.EXCEPTION_RECORD;
    const RtlCaptureContext = std.os.windows.ntdll.RtlCaptureContext;
    extern "ntdll" fn RtlRestoreContext(
        ContextRecord: *const CONTEXT,
        ExceptionRecord: ?*const EXCEPTION_RECORD,
    ) callconv(.winapi) noreturn;
};

const c = if (is_windows)
{} else struct {
    const setjmp_h = @cImport(@cInclude("setjmp.h"));
    const jmp_buf = setjmp_h.jmp_buf;
    extern "c" fn setjmp(env: *jmp_buf) c_int;
    extern "c" fn longjmp(env: *const jmp_buf, val: c_int) noreturn;
};

inline fn getContext(ctx: *Context) void {
    if (is_windows) {
        windows.RtlCaptureContext(ctx);
    } else {
        _ = c.setjmp(ctx);
    }
}

inline fn setContext(ctx: *const Context) noreturn {
    if (is_windows) {
        windows.RtlRestoreContext(ctx, null);
    } else {
        c.longjmp(ctx, 1);
    }
}

/// Panic handler that if there is a recover call in current thread continues
/// from recover call. Otherwise calls the default panic.
/// Install at root source file using:
/// ```
/// pub const panic = @import("recover").panic;
/// ```
pub const panic: type = std.debug.FullPanic(
    struct {
        pub fn panic(
            msg: []const u8,
            first_trace_addr: ?usize,
        ) noreturn {
            panicked();
            std.debug.defaultPanic(msg, first_trace_addr);
        }
    }.panic,
);
