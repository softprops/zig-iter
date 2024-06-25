/// Given a type which conforms to defining a fn next() which returns the next element
/// in an iteration or null and a const type Elem which repersents the type returned by next
/// we can derive a number of useful functions for transforming a collection of sorts into
/// a new collection modified for the purposes of a client application
///
/// Specfically a this library operates on a set of signatures that looks like the following
///
/// ```zig
/// const Elem = ...;
/// pub fn next(self: *@This()) ?Elem {...}
/// ```
const std = @import("std");
const testing = std.testing;

fn Repeat(comptime T: type) type {
    return struct {
        value: T,

        usingnamespace Methods(@This());

        const Elem = T;

        pub fn init(value: T) @This() {
            return .{ .value = value };
        }
        pub fn next(self: *@This()) ?Elem {
            return self.value;
        }
    };
}

/// returns an interator yield a provided value indefinitely
pub fn repeat(value: anytype) Repeat(@TypeOf(value)) {
    return Repeat(@TypeOf(value)).init(value);
}

test repeat {
    var iter = repeat(@as(i32, 1));
    for (0..10) |_| {
        try std.testing.expectEqual(1, iter.next());
    }
}

fn Once(comptime T: type) type {
    return struct {
        value: T,
        done: bool = false,
        const Elem = T;
        pub fn init(value: T) @This() {
            return .{ .value = value };
        }
        pub fn next(self: *@This()) ?Elem {
            if (self.done) {
                return null;
            }
            self.done = true;
            return self.value;
        }
    };
}

/// create a iterator that runs once and returns a provided value
pub fn once(value: anytype) Once(@TypeOf(value)) {
    return Once(@TypeOf(value)).init(value);
}

test once {
    var iter = once(@as(i32, 1));
    try std.testing.expectEqual(1, iter.next());
    for (0..10) |_| {
        try std.testing.expectEqual(null, iter.next());
    }
}

pub fn Skip(comptime T: type) type {
    return struct {
        wrapped: T,
        n: usize,
        usingnamespace Methods(@This());
        const Elem = T.Elem;

        pub fn init(wrapped: T, n: usize) @This() {
            return .{ .wrapped = wrapped, .n = n };
        }

        pub fn next(self: *@This()) ?Elem {
            while (self.n > 0) : (self.n -= 1) {
                _ = self.wrapped.next();
            }
            return self.wrapped.next();
        }
    };
}

test Skip {
    var iter = from([_]i32{ 1, 2, 3, 4, 5 }).skip(2);
    try std.testing.expectEqual(3, iter.next());
    try std.testing.expectEqual(4, iter.next());
    try std.testing.expectEqual(5, iter.next());
    try std.testing.expectEqual(null, iter.next());
}

pub fn Take(comptime T: type) type {
    return struct {
        wrapped: T,
        n: usize,
        usingnamespace Methods(@This());
        const Elem = T.Elem;

        pub fn init(wrapped: T, n: usize) @This() {
            return .{ .wrapped = wrapped, .n = n };
        }
        pub fn next(self: *@This()) ?Elem {
            if (self.n > 0) {
                const elem = self.wrapped.next();
                self.n -= 1;
                return elem;
            }
            return null;
        }
    };
}

test Take {
    var iter = from([_]i32{ 1, 2, 3, 4, 5 }).take(2);
    try std.testing.expectEqual(1, iter.next());
    try std.testing.expectEqual(2, iter.next());
    try std.testing.expectEqual(null, iter.next());
}

fn From(comptime T: type) type {
    // todo support and adapt to anything that's conceptually traversable. arrays, slices, ect
    const info = @typeInfo(T);
    // element type
    const E = switch (info) {
        .Pointer => |v| blk: {
            switch (v.size) {
                .Slice => break :blk v.child,
                .One => break :blk v.child,
                else => |otherwise| {
                    std.debug.print("failed to resolve len for {any}", .{otherwise});
                    unreachable;
                },
            }
        },
        .Array => |v| v.child,
        else => @compileError("unsupported type " ++ @typeName(T)),
    };

    return struct {
        wrapped: T,
        // assumptive
        n: usize,
        len: usize,

        usingnamespace Methods(@This());
        const Elem = E;

        pub fn init(wrapped: T) @This() {
            // resolve len
            const L: usize = switch (info) {
                .Pointer => |v| blk: {
                    switch (v.size) {
                        .Slice => break :blk @intCast(wrapped.len),
                        .One => break :blk 1,
                        else => |otherwise| {
                            std.debug.print("failed to resolve len for {any}", .{otherwise});
                            unreachable;
                        },
                    }
                },
                .Array => |v| @intCast(v.len),
                else => @compileError("failed to resolve len from " ++ @typeName(T)),
            };
            return .{ .wrapped = wrapped, .n = 0, .len = L };
        }
        pub fn next(self: *@This()) ?Elem {
            if (self.n < self.len) {
                const elem = self.wrapped[self.n];
                self.n += 1;
                return elem;
            }
            return null;
        }
    };
}

/// derives an interator from a given type where supported
pub fn from(src: anytype) From(@TypeOf(src)) {
    return From(@TypeOf(src)).init(src);
}

// todo: cover more expectable types
test from {
    var iter = from([_]u8{ 1, 2, 3 });

    try std.testing.expectEqual(1, iter.next());
    try std.testing.expectEqual(2, iter.next());
    try std.testing.expectEqual(3, iter.next());
    try std.testing.expectEqual(null, iter.next());
}

pub fn Filter(comptime T: type) type {
    // todo check f is a single arg fn that returns a bool
    return struct {
        wrapped: T,
        pred: fn (T.Elem) bool,
        usingnamespace Methods(@This());
        const Elem = T.Elem;
        pub fn init(wrapped: T, pred: fn (T.Elem) bool) @This() {
            return .{ .wrapped = wrapped, .pred = pred };
        }

        pub fn next(self: *@This()) ?Elem {
            if (self.wrapped.next()) |elem| {
                if (self.pred(elem)) {
                    return elem;
                } else {
                    return self.next();
                }
            } else {
                return null;
            }
        }
    };
}

test Filter {
    comptime {
        var iter = from([_]i32{ 1, 2, 3 }).filter(struct {
            fn func(n: i32) bool {
                return n > 1;
            }
        }.func);
        try std.testing.expectEqual(2, iter.next());
        try std.testing.expectEqual(3, iter.next());
        try std.testing.expectEqual(null, iter.next());
    }
}

pub fn Map(comptime T: type, comptime F: type) type {
    return struct {
        wrapped: T,
        func: F,
        usingnamespace Methods(@This());
        const Elem = switch (@typeInfo(F)) {
            .Fn => |v| if (v.return_type) |t| t else void,
            else => @compileError("expected a fn type but given a " ++ @typeName(F)),
        };

        pub fn init(wrapped: T, func: F) @This() {
            return .{ .wrapped = wrapped, .func = func };
        }

        pub fn next(self: *@This()) ?Elem {
            if (self.wrapped.next()) |elem| {
                return self.func(elem);
            } else {
                return null;
            }
        }
    };
}

test Map {
    comptime {
        var iter = from([_]i32{ 1, 2, 3 }).map(struct {
            fn func(n: i32) i32 {
                return n * 2;
            }
        }.func);

        try std.testing.expectEqual(2, iter.next());
        try std.testing.expectEqual(4, iter.next());
        try std.testing.expectEqual(6, iter.next());
        try std.testing.expectEqual(null, iter.next());
    }
}

fn Methods(comptime T: type) type {
    // check assumptions
    return struct {
        /// skip the first n elements of the iterator
        pub fn skip(self: T, n: usize) Skip(T) {
            return Skip(T).init(self, n);
        }

        /// take only the first n elements of the iterator
        pub fn take(self: T, n: usize) Take(T) {
            return Take(T).init(self, n);
        }

        /// transform all elements of T into a new item
        pub fn map(self: T, func: anytype) Map(T, @TypeOf(func)) {
            return Map(T, @TypeOf(func)).init(self, func);
        }

        /// filter out any elements which don't match a predicate func
        pub fn filter(self: T, func: fn (T.Elem) bool) Filter(T) {
            return Filter(T).init(self, func);
        }
    };
}
