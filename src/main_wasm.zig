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

var global_gol: *GameOfLife = undefined;
var global_canvas_context: *zjb.Handle = undefined;
const cell_size = 30; 
const cell_size_i32: i32 = @intCast(cell_size); 

pub const panic = zjb.panic;
export fn main() void {
    zjb.global("console").call("log", .{zjb.constString("Hello from Zig")}, void);

    var gol = alloc.create(GameOfLife) catch unreachable;
    gol.* = GameOfLife.init(alloc, 7, 7) catch |e| zjb.throwError(e);
    // defer gol.deinit();
    global_gol = gol;

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

    const canvas = zjb.global("document").call("getElementById", .{zjb.constString("canvas")}, zjb.Handle);
    defer canvas.release();

    const canvas_width: i32 = @intCast(cell_size * gol.width);
    const canvas_height: i32 = @intCast(cell_size * gol.height);
    canvas.set("width", canvas_width);
    canvas.set("height", canvas_height);

    var context = canvas.call("getContext", .{zjb.constString("2d")}, zjb.Handle);
    global_canvas_context = &context;
    // defer context.release();
    canvas_render(&context, gol);

    const button_next_step = zjb.global("document").call("getElementById", .{zjb.constString("canvas-next-step")}, zjb.Handle);
    defer button_next_step.release();
    button_next_step.call("addEventListener", .{ zjb.constString("click"), zjb.fnHandle("clickCallback", clickCallback) }, void);
}

fn clickCallback(event: zjb.Handle) callconv(.C) void {
    zjb.global("console").call("log", .{ zjb.constString("From keydown callback, event:"), event }, void);
    defer event.release();

    global_gol.step() catch |e| {
        logStr("GameOfLife.step failed");
        zjb.throwError(e);
    };
    canvas_render(global_canvas_context, global_gol);
}

fn canvas_render(context: *const zjb.Handle, gol: *const GameOfLife) void {
    const canvas_width: i32 = @intCast(cell_size * gol.width);
    const canvas_height: i32 = @intCast(cell_size * gol.height);

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
