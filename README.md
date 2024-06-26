<h1 align="center">
    zig iter
</h1>

<div align="center">
    iterators (for zig)
</div>

---

[![Main](https://github.com/softprops/zig-iter/actions/workflows/ci.yml/badge.svg)](https://github.com/softprops/zig-iter/actions/workflows/ci.yml) ![License Info](https://img.shields.io/github/license/softprops/zig-iter) ![Release](https://img.shields.io/github/v/release/softprops/zig-iter) [![Zig Support](https://img.shields.io/badge/zig-0.13.0-black?logo=zig)](https://ziglang.org/documentation/0.13.0/)

## what's next()?

If you are coming to zig from any variety of other languages you might be asking the questions like: how can I transform this collection?, how can I filter out elements?, among other things you might be used to from where you are coming from. The answer in zig is "it depends", but you'll likely be using a for loop and allocating a copy of the collection you have on hand.

Let's use a very simple example, doubling the value of an array of elems that you may do something later with. I'll just print it out for simplicity but you'll likely be doing something more useful.

```zig
const elems = [_]i32{ 1, 2, 3 };
// 👇 conjure an allocator for the list below
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
defer _ = gpa.deinit();
const allocator = gpa.allocator();
// 👇 allocate a new list to hold the data of the transformation, DONT FORGET TO DEALLOCATE IT
var buf = try std.ArrayList(i32).initCapacity(allocator, elems.len);
defer buf.deinit();
for (elems) |elem| {
    buf.appendAssumeCapacity(elem * 2);
}
// 👇 capture a ref to the slice of data you want, DONT FORGET TO DEALLOCATE IT
const doubled = try buf.toOwnedSlice();
defer allocator.free(doubled);
// 👇 do something with it
for (doubled) |elem| {
    std.debug.print("{d}", .{elem});
}
```

The simple example above quickly becomes much more complicated as additional transformations and filtering is required.

If you are coming from another language you are used to something like `elems.map(...)`

With this library you can, _almost_ have that too. Below is an equivalent program but 
sans required additial allocations and zig's required memory deallocation. 

```zig
var elems = [_]i32 { 1, 2, 3 };
// 👇 create an interator and apply a transformation
var doubled = iter.from(elems)
    .then().map(i32, struct { fn func(n: i32) i32 { return n * 2; } }.func);
// 👇 do something with it
while (doubled.next()) |elem| {
    std.debug.print("{d}", .{elem});
}
```

I say _almost_ because 

* zig does not support closures, but it does support functions as arguments so we can emulate these to a certain degree with struct fn references
* some [changes to `usingnamespace`](https://github.com/softprops/zig-iter/issues/1) facilitate the need for an itermediatory method, we use `then()` to access and chain iterator methods. If zig brings that back in a different form. `then()` will no longer been nessessary.


The following functions create iterators

* `from(zigType)` - create an iterator for a native zig type, we're expanding the list of types supported
* `repeat(value)` - create an iterator that repeats a given value indefinitely
* `once(value)` - create an iterator that only repeats once
* `fromFn(returnType, init, func)` - create an iterator from a generator func

The following methods are available when calling `then()` on iterator types

* `map(returnType, func)` - transforms an iterator by applying `func`
* `filter(func)` - filters an iterator by testing a `func` predicate
* `take(n)` - take only the first `n` elems of an iterator
* `skip(n)` - skip the first `n` elems of an iterator
* `zip(iter)` - create an iterator yielding a tuple of iterator values
* `fold(returnType, init, func)` - reduces an iterator down to a single value

likely more to come


Note, nothing is allocated behind the scenes. If you do need to take the results and 
store the result in an allocatoed type simply do what you would do with any iterator: feed 
it values of `next()`

```zig
var elems = [_]i32 { 1, 2, 3 };
var doubled = iter.from(elems)
    .then().map(i32, struct { fn func(n: i32) i32 { return n * 2; } }.func);

// now go ahead feed the result into a list

// 👇 conjure an allocator for the list below
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
defer _ = gpa.deinit();
const allocator = gpa.allocator();
// 👇 allocate a new list to hold the data of the transformation, DONT FORGET TO DEALLOCATE IT
var buf = try std.ArrayList(i32).initCapacity(allocator, elems.len);
defer buf.deinit();
while (doubled.next()) |elem| {
    buf.appendAssumeCapacity(elem * 2);
}
// 👇 capture a ref to the slice of data you want, DONT FORGET TO DEALLOCATE IT
const copied = try buf.toOwnedSlice();
defer allocator.free(copied);
```

## examples

For more examples see the `examples` directory

## 📼 installing

Create a new exec project with `zig init`. Copy an example from the examples directory into your into `src/main.zig`

Create a `build.zig.zon` file to declare a dependency

> .zon short for "zig object notation" files are essentially zig structs. `build.zig.zon` is zigs native package manager convention for where to declare dependencies

Starting in zig 0.12.0, you can use and should prefer

```sh
zig fetch --save https://github.com/softprops/zig-iter/archive/refs/tags/v0.1.0.tar.gz
```

otherwise, to manually add it, do so as follows

```diff
.{
    .name = "my-app",
    .version = "0.1.0",
    .dependencies = .{
+       // 👇 declare dep properties
+        .iter = .{
+            // 👇 uri to download
+            .url = "https://github.com/softprops/zig-iter/archive/refs/tags/v0.1.0.tar.gz",
+            // 👇 hash verification
+            .hash = "...",
+        },
    },
}
```

> the hash below may vary. you can also depend any tag with `https://github.com/softprops/zig-iter/archive/refs/tags/v{version}.tar.gz` or current main with `https://github.com/softprops/zig-iter/archive/refs/heads/main/main.tar.gz`. to resolve a hash omit it and let zig tell you the expected value.

Add the following in your `build.zig` file

```diff
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});
    // 👇 de-reference dep from build.zig.zon`
+    const iter = b.dependency("iter", .{
+        .target = target,
+        .optimize = optimize,
+    }).module("iter");
    var exe = b.addExecutable(.{
        .name = "your-exe",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    // 👇 add the module to executable
+    exe.root_mode.addImport("iter", iter);

    b.installArtifact(exe);
}
```

## 🥹 for budding ziglings

Does this look interesting but you're new to zig and feel left out? No problem, zig is young so most us of our new are as well. Here are some resources to help get you up to speed on zig

- [the official zig website](https://ziglang.org/)
- [zig's one-page language documentation](https://ziglang.org/documentation/0.13.0/)
- [ziglearn](https://ziglearn.org/)
- [ziglings exercises](https://github.com/ratfactor/ziglings)


\- softprops 2024