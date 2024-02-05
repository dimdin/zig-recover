Zig Panic Recover
=================

Recover calls a function and regains control of the calling thread when the function panics or behaves undefined.
Recover is licensed under the terms of the [MIT License](LICENSE).

How to use
----------

Recover `call`, calls `function` with `args`, if the function does not panic, will return the called function's return value. If the function panics, will return the provided `error.Value`.
```
const recover = @import("recover");

try recover.call(function, args, error.Value);
```

Example
-------

Returns error.Panic because function division panics with runtime error "division by zero".
```
fn division(num: u32, den: u32) u32 {
    return num / den;
}

try recover.call(division, .{1, 0}, error.Panic);
```

Prerequisites
-------------

- Enabled runtime safety checks, such as unreachable, index out of bounds, overflow, division by zero, incorrect pointer alignment, etc.

- In the root source file override the default panic handler and call recover `panicked`.
```
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    recover.panicked();
    std.builtin.default_panic(msg, error_return_trace, ret_addr);
}
```
- Excluding Windows, linking to C standard library is required.

Proper Usage
------------

- Proper use of recover is only for testing panic and undefined behavior runtime safety checks.
- It is **not** recommended to use recover as a general exception mechanism.
