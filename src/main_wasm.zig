const std = @import("std");
const zjb = @import("zjb");
const alloc = std.heap.wasm_allocator;
const GameOfLife = @import("./lib.zig").GameOfLife;

fn log(v: anytype) void {
    zjb.global("console").call("log", .{v}, void);
}
fn logStr(str: []const u8) void {
    const handle = zjb.string(str);
    defer handle.release();
    zjb.global("console").call("log", .{handle}, void);
}

pub const panic = zjb.panic;
export fn main() void {
    zjb.global("console").call("log", .{zjb.constString("Hello from Zig")}, void);

    const cell_size = 30; 
    const cell_size_i32: i32 = @intCast(cell_size); 
    var gol = GameOfLife.init(alloc, 7, 7) catch |e| zjb.throwError(e);

    var glider = [_][]const u8{
        &.{0, 1, 0},
        &.{0, 0, 1},
        &.{1, 1, 1},
    };

    gol.set_grid_start(&glider);
    for (0..gol.height) |row_index| {
        const row_start = row_index * gol.width;
        const row_end = row_start + gol.width;
        const obj = zjb.u8ArrayView(gol.grid.items[row_start..row_end]);
        defer obj.release();
        log(obj);
    }

    zjb.global("console").call("log", .{zjb.constString("Next step")}, void);
    gol.step() catch |e| zjb.throwError(e);
    for (0..gol.height) |row_index| {
        const row_start = row_index * gol.width;
        const row_end = row_start + gol.width;
        const obj = zjb.u8ArrayView(gol.grid.items[row_start..row_end]);
        defer obj.release();
        log(obj);
    }

    logStr("\n============================= html canvas example =============================");
    {
        const canvas = zjb.global("document").call("getElementById", .{zjb.constString("canvas")}, zjb.Handle);
        defer canvas.release();

        const canvas_width: i32 = @intCast(cell_size * gol.width);
        const canvas_height: i32 = @intCast(cell_size * gol.height);
        canvas.set("width", canvas_width);
        canvas.set("height", canvas_height);

        const context = canvas.call("getContext", .{zjb.constString("2d")}, zjb.Handle);
        defer context.release();

        const live_color = zjb.constString("#16191d"); 
        const dead_color = zjb.constString("#f8f9fa"); 

        context.set("fillStyle", dead_color);
        const canvas_start: i32 = 0;
        const canvas_end: i32 = 0;
        context.call("fillRect", .{ canvas_start, canvas_end, canvas_width, canvas_height }, void);

        context.set("fillStyle", live_color);

        for (0..gol.height) |row_index| {
            const row_px: i32 = @intCast(row_index * cell_size);
            for (0..gol.width) |col_index| {
                const col_val = gol.grid.items[row_index * gol.width + col_index];
                if (col_val == 1) {
                    const col_px: i32 = @intCast(col_index * cell_size);
                    context.call("fillRect", .{ col_px, row_px, cell_size_i32, cell_size_i32 }, void);
                }
            }
        }
    }
    
    // {
    //     const formatted = std.fmt.allocPrint(alloc, "Runtime string: current timestamp {d}", .{zjb.global("Date").call("now", .{}, f32)}) catch |e| zjb.throwError(e);
    //     defer alloc.free(formatted);

    //     const str = zjb.string(formatted);
    //     defer str.release();

    //     zjb.global("console").call("log", .{str}, void);
    // }

    // logStr("\n============================= Array View Example =============================");
    // {
    //     var arr = [_]u8{ 1, 2, 3 };
    //     const obj = zjb.u8ArrayView(&arr);
    //     defer obj.release();

    //     logStr("View of Zig u8 array from Javascript, with its length");
    //     log(obj);
    //     log(obj.get("length", f64)); // 3

    //     arr[0] = 4;
    //     logStr("Changes from Zig are visible in Javascript");
    //     log(obj);

    //     obj.indexSet(1, 5);
    //     logStr("Changes from Javascript are visible in Zig");
    //     log(obj);

    //     logStr("Unless wasm's memory grows, which causes the ArrayView to be invalidated.");
    //     _ = @wasmMemoryGrow(0, 1);
    //     arr[0] = 5;
    //     log(obj);
    //     log(obj.get("length", f64)); // 0
    // }

    // logStr("\n============================= Data View Examples =============================");
    // logStr("dataView allows extraction of numbers from WASM's memory.");
    // {
    //     const arr = [_]u16{ 1, 2, 3 };
    //     const obj = zjb.dataView(&arr);
    //     defer obj.release();

    //     logStr("dataView works for arrays.");
    //     log(obj);
    //     log(obj.call("getUint16", .{ @sizeOf(u16) * 0, true }, f32));
    //     log(obj.call("getUint16", .{ @sizeOf(u16) * 1, true }, f32));
    //     log(obj.call("getUint16", .{ @sizeOf(u16) * 2, true }, f32));
    // }

    // {
    //     const S = extern struct {
    //         a: u16,
    //         b: u16,
    //         c: u32,
    //     };
    //     const s = S{ .a = 1, .b = 2, .c = 3 };
    //     const obj = zjb.dataView(&s);
    //     defer obj.release();

    //     logStr("dataView also works for structs, make sure they're extern!");
    //     log(obj);
    //     log(obj.call("getUint16", .{ @offsetOf(S, "a"), true }, f32));
    //     log(obj.call("getUint16", .{ @offsetOf(S, "b"), true }, f32));
    //     log(obj.call("getUint32", .{ @offsetOf(S, "c"), true }, f32));
    // }

    // logStr("\n============================= Maps and index getting/setting =============================");
    // {
    //     const obj = zjb.global("Map").new(.{});
    //     defer obj.release();

    //     const myI32: i32 = 0;
    //     obj.indexSet(myI32, 0);
    //     const myI64: i64 = 0;
    //     obj.indexSet(myI64, 1);

    //     obj.set("Hello", obj.indexGet(myI64, f64));

    //     const str = zjb.string("some_key");
    //     defer str.release();
    //     obj.indexSet(str, 2);

    //     log(obj);
    // }


    // logStr("\n============================= Exporting functions (press a key for a callback) =============================");
    // zjb.global("document").call("addEventListener", .{ zjb.constString("keydown"), zjb.fnHandle("keydownCallback", keydownCallback) }, void);

    // logStr("\n============================= Handle vs ConstHandle =============================");
    // {
    //     logStr("zjb.global and zjb.constString add their ConstHandle on first use, and remember for subsiquent uses.  They can't be released.");
    //     logStr("While zjb.string and Handle return values must be released after being used or they'll leak.");
    //     logStr("See that some string remain in handles, while others have been removed after use.");
    //     const handles = zjb.global("zjb").get("_handles", zjb.Handle);
    //     defer handles.release();
    //     log(handles);
    // }

    // logStr("\n============================= Testing for unreleased handles =============================");
    // logStr("\nIt's good to do this often.  Assert that the count is <= the number of handles you'll keep stored in long term state.");
    // std.debug.assert(zjb.unreleasedHandleCount() == 0);
}

// fn keydownCallback(event: zjb.Handle) callconv(.C) void {
//     defer event.release();

//     zjb.global("console").call("log", .{ zjb.constString("From keydown callback, event:"), event }, void);
// }

// var value: i32 = 0;
// fn incrementAndGet(increment: i32) callconv(.C) i32 {
//     value += increment;
//     return value;
// }

// var test_var: f32 = 1337.7331;
// fn checkTestVar() callconv(.C) f32 {
//     return test_var;
// }

// fn setTestVar() callconv(.C) f32 {
//     test_var = 42.24;
//     return test_var;
// }

// comptime {
//     zjb.exportFn("incrementAndGet", incrementAndGet);

//     zjb.exportGlobal("test_var", &test_var);
//     zjb.exportFn("checkTestVar", checkTestVar);
//     zjb.exportFn("setTestVar", setTestVar);
// }
