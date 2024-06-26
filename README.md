<h1 align="center">
    zig iter
</h1>

<div align="center">
    zig iterators
</div>

---

[![Main](https://github.com/softprops/zig-iter/actions/workflows/ci.yml/badge.svg)](https://github.com/softprops/zig-iter/actions/workflows/ci.yml) ![License Info](https://img.shields.io/github/license/softprops/zig-iter) ![Release](https://img.shields.io/github/v/release/softprops/zig-iter) [![Zig Support](https://img.shields.io/badge/zig-0.13.0-black?logo=zig)](https://ziglang.org/documentation/0.13.0/)

If you are coming to zig from any variety of other languages you might be asking the questions like: how can I transform this collection?, how can I filter out elements?, among other things you might be used to from where you are coming from. The answer in zig is "it depends", but you'll likely be using a for loop and allocating a copy of the collection you have on hand.

Let's use a very simple example, doubling the value of an array of elems that you may do something later with. I'll just print it out for simplicity but you'll likely be doing something more useful.

```zig
var elems = [_]i32 { 1, 2, 3 };
var buf = try std.ArrayList(i32).initCapacity(allocator, elems.len);
def buf.deinit();
for (elem) |elem| {
    buf.appendAssumeCapacity(elem * 2);
}
var doubled = doubled.toOwnedSlice();
defer allocator.free(doubled);
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
var doubled = iter.from(elems).next().map(struct { fn func(n: i32) i32 { n * 2 } }.func);
while (doubled.next()) |elem| {
    std.debug.print("{d}", .{elem});
}
```

I say _almost_ because 

* zig does not support closures, but it does support functions as arguments so we can emulate these to a certain degree
* some [changes to `usingnamespace`](https://github.com/softprops/zig-iter/issues/1) facilitate the need for an itermediatory method, we use `next()` to access and chain iterator methods. If zig brings that back in a different form. `next()` will no longer been nessessary.



## examples

See examples directory

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