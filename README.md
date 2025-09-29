Zig Panic Recover
=================

Recover calls a function and regains control of the calling thread when the
function panics or behaves undefined.
Recover is licensed under the terms of the [MIT License](LICENSE).

How to use
----------

Recover `call`, calls `function` with `args`, if the function does not panic,
will return the called function's return value. If the function panics, will
return `error.Panic`.
```
const recover = @import("recover");

try recover.call(function, args);
```

Prerequisites
-------------

1. Enabled runtime safety checks, such as unreachable, index out of bounds,
overflow, division by zero, incorrect pointer alignment, etc.

2. In the root source file define panic as recover.panic or override the
default panic handler and call recover `panicked`.
```
pub const panic = recover.panic;
```
3. Excluding Windows, linking to C standard library is required.

Example
-------

Returns `error.Panic` because function division panics with runtime error
"division by zero".
```
fn division(num: u32, den: u32) u32 {
    return num / den;
}

try recover.call(division, .{1, 0});
```

Testing
-------

For recover to work for testing, you need a custom test runner with a panic
handler:
```
pub const panic = @import("recover").panic;
```

To test that `foo(0)` panics:
```
test "foo(0) panics" {
     const err = recover.call(foo, .{0});
     std.testing.expectError(error.Panic, err).
}    
```

Proper Usage
------------

- Recover is useful for testing panic and undefined behavior runtime
safety checks.
- It is **not** recommended to use recover as a general exception mechanism.
