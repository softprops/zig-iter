const std = @import("std");
const iter = @import("iter");

pub fn main() !void {
    {
        var it = iter.from([_]i32{ 1, 2, 3 });
        while (it.next()) |next| {
            std.debug.print("{d}\n", .{next});
        }
    }

    {
        var it = iter.once(@as(i32, 1));
        while (it.next()) |next| {
            std.debug.print("{d}\n", .{next});
        }
    }

    // {
    //     var it = iter.repeat(@as(i32, 1));
    //     while (it.next()) |next| {
    //         std.debug.print("{d}\n", .{next});
    //     }
    // }
}
