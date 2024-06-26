/// Given a type which conforms to defining a `fn next()` which returns the next element
/// in an iteration or null and a const type `Elem` which represents the type returned by `next`
/// we can derive a number of useful functions for transforming a collection of sorts into
/// a new collection modified for the purposes of a client application
///
/// Specifically this library operates on a set of signatures that looks like the following
///
/// ```zig
/// // the type returned by next
/// const Elem = ...;
/// // the next elem in this iterator
/// pub fn next(self: *@This()) ?Elem { ... }
/// // chains this with additional an iterator transformation
/// pub fn then(self: @This()) Iter(@This()) { .. }
/// ```
const std = @import("std");
const testing = std.testing;

fn Repeat(comptime T: type) type {
    return struct {
        value: T,

        pub const Elem = T;

        fn init(value: T) @This() {
            return .{ .value = value };
        }

        pub fn next(self: *@This()) ?Elem {
            return self.value;
        }

        //usingnamespace Iter(@This());
        pub fn then(self: @This()) Iter(@This()) {
            return Iter(@This()){ .value = self };
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
        fn init(value: T) @This() {
            return .{ .value = value };
        }
        pub fn next(self: *@This()) ?Elem {
            if (self.done) {
                return null;
            }
            self.done = true;
            return self.value;
        }

        //usingnamespace Iter(@This());
        pub fn then(self: @This()) Iter(@This()) {
            return Iter(@This()){ .value = self };
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

fn Skip(comptime T: type) type {
    return struct {
        wrapped: T,
        n: usize,

        const Elem = T.Elem;

        fn init(wrapped: T, n: usize) @This() {
            return .{ .wrapped = wrapped, .n = n };
        }

        pub fn next(self: *@This()) ?Elem {
            while (self.n > 0) : (self.n -= 1) {
                if (self.wrapped.next() == null) {
                    return null;
                }
            }
            return self.wrapped.next();
        }

        //usingnamespace Iter(@This());
        pub fn then(self: @This()) Iter(@This()) {
            return Iter(@This()){ .value = self };
        }
    };
}

test Skip {
    var iter = from([_]i32{ 1, 2, 3, 4, 5 }).then().skip(2);
    try std.testing.expectEqual(3, iter.next());
    try std.testing.expectEqual(4, iter.next());
    try std.testing.expectEqual(5, iter.next());
    try std.testing.expectEqual(null, iter.next());
}

fn Take(comptime T: type) type {
    return struct {
        wrapped: T,
        n: usize,

        const Elem = T.Elem;

        fn init(wrapped: T, n: usize) @This() {
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
        //usingnamespace Iter(@This());
        pub fn then(self: @This()) Iter(@This()) {
            return Iter(@This()){ .value = self };
        }
    };
}

test Take {
    var iter = from([_]i32{ 1, 2, 3, 4, 5 }).then().take(2);
    try std.testing.expectEqual(1, iter.next());
    try std.testing.expectEqual(2, iter.next());
    try std.testing.expectEqual(null, iter.next());
}

fn Zip(comptime T: type, comptime W: type) type {
    return struct {
        wrapped: T,
        other: W,
        const Elem = struct { T.Elem, W.Elem };

        fn init(wrapped: T, other: W) @This() {
            return .{ .wrapped = wrapped, .other = other };
        }

        pub fn next(self: *@This()) ?Elem {
            if (self.wrapped.next()) |elem1| {
                if (self.other.next()) |elem2| {
                    return .{ elem1, elem2 };
                }
            }
            return null;
        }

        //usingnamespace Iter(@This());
        pub fn then(self: @This()) Iter(@This()) {
            return Iter(@This()){ .value = self };
        }
    };
}

test Zip {
    var iter = from([_]i32{ 1, 2, 3 }).then().zip(repeat(@as(i32, 4)));
    try std.testing.expectEqual(.{ 1, 4 }, iter.next());
    try std.testing.expectEqual(.{ 2, 4 }, iter.next());
    try std.testing.expectEqual(.{ 3, 4 }, iter.next());
    try std.testing.expectEqual(null, iter.next());
}

/// creates an iterator from a native zig type
fn From(comptime T: type) type {
    // todo support and adapt to anything that's conceptually traversable. arrays, slices, ect
    // resolve Elem type
    const info = @typeInfo(T);
    const E = switch (info) {
        .Pointer => |v| blk: {
            switch (v.size) {
                .Slice => break :blk v.child,
                .One => {
                    switch (@typeInfo(v.child)) {
                        .Pointer => |cv| break :blk cv.child,
                        .Array => |cv| break :blk cv.child,
                        else => @compileError("failed to resolve child of child type for type " ++ @typeName(v.child)),
                    }
                },
                else => @compileError("failed to resolve child type for type " ++ @typeName(T)),
            }
        },
        .Array => |v| v.child,
        else => @compileError("unsupported iterator type " ++ @typeName(T)),
    };

    return struct {
        wrapped: T,
        // assumptive
        n: usize,
        len: usize,

        const Elem = E;

        fn init(wrapped: T) @This() {
            // resolve len
            const L: usize = switch (info) {
                .Pointer => |v| blk: {
                    switch (v.size) {
                        .Slice => break :blk @intCast(wrapped.len),
                        .One => break :blk {
                            switch (@typeInfo(v.child)) {
                                .Pointer => |cv| break :blk @intCast(cv.len),
                                .Array => |cv| break :blk @intCast(cv.len),
                                else => @compileError("failed to resolve len for type " ++ @typeName(v.child)),
                            }
                        },
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
        //usingnamespace Iter(@This());
        pub fn then(self: @This()) Iter(@This()) {
            return Iter(@This()){ .value = self };
        }
    };
}

/// derives an iterator from a given type where supported
/// current supported types are arrays and slices
pub fn from(src: anytype) From(@TypeOf(src)) {
    return From(@TypeOf(src)).init(src);
}

test from {
    var iter = from([_]u8{ 1, 2, 3 });

    try std.testing.expectEqual(1, iter.next());
    try std.testing.expectEqual(2, iter.next());
    try std.testing.expectEqual(3, iter.next());
    try std.testing.expectEqual(null, iter.next());
}

test "from str" {
    var iter = from("abc");

    try std.testing.expectEqual(97, iter.next());
    try std.testing.expectEqual(98, iter.next());
    try std.testing.expectEqual(99, iter.next());
    try std.testing.expectEqual(null, iter.next());
}

test "from slice" {
    var data = [_]i32{ 1, 2, 3 };
    var iter = from(data[1..]);

    try std.testing.expectEqual(2, iter.next());
    try std.testing.expectEqual(3, iter.next());
    try std.testing.expectEqual(null, iter.next());
}

fn Filter(comptime T: type) type {
    return struct {
        wrapped: T,
        pred: *const fn (T.Elem) bool,

        const Elem = T.Elem;
        fn init(wrapped: T, pred: *const fn (T.Elem) bool) @This() {
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

        //usingnamespace Iter(@This());
        pub fn then(self: @This()) Iter(@This()) {
            return Iter(@This()){ .value = self };
        }
    };
}

test Filter {
    var iter = from([_]i32{ 1, 2, 3 }).then().filter(struct {
        fn func(n: i32) bool {
            return n > 1;
        }
    }.func);
    try std.testing.expectEqual(2, iter.next());
    try std.testing.expectEqual(3, iter.next());
    try std.testing.expectEqual(null, iter.next());
}

fn Map(comptime T: type, comptime F: type) type {
    return struct {
        wrapped: T,
        func: *const fn (T.Elem) F,

        const Elem = F;

        fn init(wrapped: T, func: *const fn (T.Elem) F) @This() {
            return .{ .wrapped = wrapped, .func = func };
        }

        pub fn next(self: *@This()) ?Elem {
            if (self.wrapped.next()) |elem| {
                return self.func(elem);
            } else {
                return null;
            }
        }

        //usingnamespace Iter(@This());
        pub fn then(self: @This()) Iter(@This()) {
            return Iter(@This()){ .value = self };
        }
    };
}

test Map {
    var iter = from([_]i32{ 1, 2, 3 }).then().map(i32, struct {
        fn func(n: i32) i32 {
            return n * 2;
        }
    }.func);

    try std.testing.expectEqual(2, iter.next());
    try std.testing.expectEqual(4, iter.next());
    try std.testing.expectEqual(6, iter.next());
    try std.testing.expectEqual(null, iter.next());
}

fn Function(comptime T: type) type {
    return struct {
        state: ?T,
        func: *const fn (T) ?T,

        const Elem = T;

        fn init(initial: T, func: *const fn (T) ?T) @This() {
            return .{ .state = initial, .func = func };
        }

        pub fn next(self: *@This()) ?Elem {
            if (self.state) |state| {
                self.state = self.func(state);
                return self.state;
            }
            return null;
        }

        //usingnamespace Iter(@This());
        pub fn then(self: @This()) Iter(@This()) {
            return Iter(@This()){ .value = self };
        }
    };
}

/// returns an interator that generates its next state based on the result of applying
/// a state to a func with a provided initial state
///
/// note: the reason why the intial state is needed is to provide access to information needed
/// to compute the next state. zig doesn't currently support closures so it would not otherwise
/// be possible to access outter scope information from within func
/// if your func does not actually need state, simply use a dummy value.
pub fn fromFn(comptime T: type, initial: T, func: *const fn (T) ?T) Function(T) {
    return Function(T).init(initial, func);
}

test fromFn {
    var it = fromFn(i32, 0, struct {
        fn func(state: i32) ?i32 {
            return switch (state) {
                3 => null, // stop after 3
                else => state + 1, // increment state by one
            };
        }
    }.func);
    try std.testing.expectEqual(1, it.next());
    try std.testing.expectEqual(2, it.next());
    try std.testing.expectEqual(3, it.next());
    try std.testing.expectEqual(null, it.next());
}

fn Fold(comptime T: type, comptime R: type) type {
    return struct {
        wrapped: T,
        state: R,
        func: *const fn (T.Elem, R) R,

        const Elem = R;

        fn init(wrapped: T, initial: R, func: *const fn (T.Elem, R) R) @This() {
            return .{ .wrapped = wrapped, .state = initial, .func = func };
        }

        fn get(self: *@This()) R {
            while (self.wrapped.next()) |elem| {
                self.state = self.func(elem, self.state);
            }
            return self.state;
        }
    };
}

test Fold {
    const sum = from([_]i32{ 1, 2, 3 }).then().fold(i32, 0, struct {
        fn func(elem: i32, state: i32) i32 {
            return state + elem;
        }
    }.func);
    try std.testing.expectEqual(6, sum);
}

/// provides transformation funcs
fn Iter(comptime T: type) type {
    // check assumptions
    return struct {
        value: T,

        /// skip the first n elements of the iterator
        pub fn skip(self: @This(), n: usize) Skip(T) {
            return Skip(T).init(self.value, n);
        }

        /// take only the first n elements of the iterator
        pub fn take(self: @This(), n: usize) Take(T) {
            return Take(T).init(self.value, n);
        }

        /// transform all elements of T into a new item
        pub fn map(self: @This(), comptime F: type, func: *const fn (T.Elem) F) Map(T, F) {
            return Map(T, F).init(self.value, func);
        }

        /// filter out any elements which don't match a predicate func
        pub fn filter(self: @This(), func: fn (T.Elem) bool) Filter(T) {
            return Filter(T).init(self.value, func);
        }

        /// zip two iterators together
        pub fn zip(self: @This(), other: anytype) Zip(T, @TypeOf(other)) {
            return Zip(T, @TypeOf(other)).init(self.value, other);
        }

        pub fn fold(self: @This(), comptime R: type, init: R, func: *const fn (T.Elem, R) R) R {
            var folder = Fold(T, R).init(self.value, init, func);
            return folder.get();
        }
    };
}
