const std = @import("std");
const iter = @import("iter");

pub fn main() !void {
    // from
    {
        var it = iter.from([_]i32{ 1, 2, 3 });
        while (it.next()) |next| {
            std.debug.print("from {d}\n", .{next});
        }
    }

    // once
    {
        var it = iter.once(@as(i32, 1));
        while (it.next()) |next| {
            std.debug.print("once {d}\n", .{next});
        }
    }

    // take
    {
        var it = iter.from([_]i32{ 1, 2, 3 }).then().take(2);
        while (it.next()) |next| {
            std.debug.print("take {d}\n", .{next});
        }
    }

    // skip
    {
        var it = iter.from([_]i32{ 1, 2, 3 }).then().skip(1);
        while (it.next()) |next| {
            std.debug.print("skip {d}\n", .{next});
        }
    }

    // repeat
    {
        var it = iter.repeat(@as(i32, 1)).then().take(2);
        while (it.next()) |next| {
            std.debug.print("repeat {d}\n", .{next});
        }
    }

    // filter
    {
        var it = iter.from([_]i32{ 1, 2, 3 }).then().filter(struct {
            fn func(n: i32) bool {
                return n > 3;
            }
        }.func);
        while (it.next()) |next| {
            std.debug.print("filter {d}\n", .{next});
        }
    }

    // map
    {
        var it = iter.from([_]i32{ 1, 2, 3 }).then().map(i32, struct {
            fn func(n: i32) i32 {
                return n * 2;
            }
        }.func);
        while (it.next()) |next| {
            std.debug.print("map {d}\n", .{next});
        }
    }

    // zip
    {
        var it = iter.from([_]i32{ 1, 2, 3 }).then().zip(iter.from([_]i32{ 4, 5 }));
        while (it.next()) |next| {
            std.debug.print("zip {any}\n", .{next});
        }
    }

    // fold
    {
        const sum = iter.from([_]i32{ 1, 2, 3 }).then().fold(i32, 0, struct {
            fn func(elem: i32, state: i32) i32 {
                return state + elem;
            }
        }.func);
        std.debug.print("fold {any}\n", .{sum});
    }

    // combo
    {
        const timesTwo = struct {
            fn func(n: i32) i32 {
                return n * 2;
            }
        }.func;
        const even = struct {
            fn func(n: i32) bool {
                return @mod(n, 2) == 0;
            }
        }.func;
        var it = iter.from([_]i32{ 1, 2, 3 })
            .then().map(i32, timesTwo)
            .then().filter(even)
            .then().take(1);
        while (it.next()) |next| {
            std.debug.print("combo {d}\n", .{next});
        }
    }
}
