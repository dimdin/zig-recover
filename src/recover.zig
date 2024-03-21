// Copyright © 2024 Dimitris Dinodimos.

//! Panic recover.
//! Regains control of the calling thread when the function panics or behaves undefined.

const std = @import("std");
const builtin = @import("builtin");

const Context = if (builtin.os.tag == .windows)
    std.os.windows.CONTEXT
else if (builtin.os.tag == .linux and builtin.abi == .musl)
    musl.jmp_buf
else
    std.c.ucontext_t;

threadlocal var top_ctx: ?*const Context = null;

/// Call from root source file panic handler.
/// Returns if there was no recover call in current thread.
/// Otherwise, does not return and execution continues from the current thread recover call.
pub fn panicked() void {
    if (top_ctx) |ctx| {
        setContext(ctx);
    }
}

// comptime function that extends T by combining its error set with E.
fn extErrType(T: type, E: type) type {
    if (@typeInfo(E) != .ErrorSet)
        @compileError("An error value is required.");
    const info = @typeInfo(T);
    if (info != .ErrorUnion) {
        return @Type(.{ .ErrorUnion = .{
            .error_set = E,
            .payload = T,
        } });
    }
    return @Type(.{
        .ErrorUnion = .{
            .error_set = info.ErrorUnion.error_set || E,
            .payload = info.ErrorUnion.payload,
        },
    });
}

/// Calls `func` with `args`, guarding from runtime errors.
/// Returns the `panicked_error` value when recovers from runtime error.
/// Otherwise returns the return value of calling func with args.
pub fn call(
    func: anytype,
    args: anytype,
    panicked_error: anytype,
) extErrType(@typeInfo(@TypeOf(func)).Fn.return_type.?, @TypeOf(panicked_error)) {
    const prev_ctx: ?*const Context = top_ctx;
    var ctx: Context = std.mem.zeroes(Context);
    getContext(&ctx);
    if (top_ctx != prev_ctx) {
        top_ctx = prev_ctx;
        return panicked_error;
    }
    top_ctx = &ctx;
    defer top_ctx = prev_ctx;
    return @call(.auto, func, args);
}

// windows
const CONTEXT = std.os.windows.CONTEXT;
const EXCEPTION_RECORD = std.os.windows.EXCEPTION_RECORD;
const WINAPI = std.os.windows.WINAPI;
extern "ntdll" fn RtlRestoreContext(ContextRecord: *const CONTEXT, ExceptionRecord: ?*const EXCEPTION_RECORD) callconv(WINAPI) noreturn;

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
