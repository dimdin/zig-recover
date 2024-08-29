// Copyright © 2024 Dimitris Dinodimos.

const std = @import("std");
const recover = @import("recover");
const assert = std.debug.assert;

fn assertion(value: bool) void {
    assert(value);
}

fn inc(val: u8) u8 {
    return val + 1;
}

fn div1by(val: u16) u16 {
    return 1 / val;
}

fn at(s: []const u8, i: usize) u8 {
    return s[i];
}

pub const panic = recover.panic;

fn tests() void {
    {
        // assert(true);
        const res = recover.call(assertion, .{true});
        assert(res != error.Panic);
        assert(res catch unreachable == {});
    }
    {
        // assert(false);   unreachable
        const res = recover.call(assertion, .{false});
        assert(res == error.Panic);
    }
    {
        // inc(1);          1+1
        const res = recover.call(inc, .{1});
        assert(res != error.Panic);
        assert(res catch unreachable == 2);
    }
    {
        // inc(255);        overflow
        const res = recover.call(inc, .{255});
        assert(res == error.Panic);
    }
    {
        // div1by(1);       1/1
        const res = recover.call(div1by, .{1});
        assert(res != error.Panic);
        assert(res catch unreachable == 1);
    }
    {
        // div1by(0);       division by zero
        const res = recover.call(div1by, .{0});
        assert(res == error.Panic);
    }
    {
        // at("hi", 1);     "hi"[1]
        const res = recover.call(at, .{ "hi", 1 });
        assert(res != error.Panic);
        assert(res catch unreachable == 'i');
    }
    {
        // at("hi", 2);     index out of bounds
        const res = recover.call(at, .{ "hi", 2 });
        assert(res == error.Panic);
    }
}

pub fn main() !void {
    const thread = try std.Thread.spawn(.{}, tests, .{});
    defer thread.join();
    tests();
}
