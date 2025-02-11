const w4 = @import("wasm4.zig");
const std = @import("std");

//colors
const draw_colors_array: *[4]u4 = @ptrCast(w4.DRAW_COLORS);
pub fn set_drawc(index: u2, color_index: u3) void {
    const shift: u4 = @as(u4, index) * 4;
    const mask = ~(@as(u16, 0b1111) << shift);
    const color = @as(u16, color_index) << shift;
    w4.DRAW_COLORS.* = color | (w4.DRAW_COLORS.* & mask);
}
pub fn set_drawc1(color: u3) void {
    set_drawc(0, color);
}
pub fn set_drawc2(color: u3) void {
    set_drawc(1, color);
}
pub fn set_drawc3(color: u3) void {
    set_drawc(2, color);
}
pub fn set_drawc4(color: u3) void {
    set_drawc(3, color);
}

//gamepad
var old_gamepad: [4]u8 = .{ 0, 0, 0, 0 };
pub fn get_pressed(gamepad_index: u2) u8 {
    const gamepad: u8 = @as(*u8, @ptrFromInt(@intFromPtr(w4.GAMEPAD1) + gamepad_index)).*;
    const pressed = (gamepad ^ 0) & (~old_gamepad[gamepad_index]);
    old_gamepad[gamepad_index] = gamepad;
    return pressed;
}
pub fn is_pressed(gamepad: u8, button: u8) bool {
    return gamepad & button != 0;
}
pub fn is_released(gamepad: u8, button: u8) bool {
    var released = false;
    if (is_pressed(old_gamepad, button) and !is_pressed(gamepad, button)) {
        released = true;
    }
    old_gamepad = gamepad;
    return released;
}

const w4_alloc = @import("w4_alloc.zig");
//printing
pub fn format(comptime fmt: []const u8, args: anytype, input_buf: *?[]u8) []const u8 {
    input_buf.* = null;
    //var buf2: [buf_size]u8 = .{0} ** buf_size;
    const error_text = "[ERROR][bufPrint]no space left!";
    const alloc_error_text = "[ERROR][ALLOC]no space left!";
    const buf_size: usize = @intCast(std.fmt.count(fmt, args));
    const buf: []u8 = w4_alloc.a.allocator().alloc(u8, buf_size) catch {
        return alloc_error_text;
    };
    const out = std.fmt.bufPrint(buf, fmt, args) catch {
        return error_text;
    };
    input_buf.* = buf;
    return out;
}
pub fn printf(comptime fmt: []const u8, args: anytype, x: i32, y: i32) void {
    var buf: ?[]u8 = null;
    const out = format(fmt, args, &buf);
    defer if (buf) |ptr| {
        w4_alloc.a.allocator().free(ptr);
    };
    w4.text(out, x, y);
}
pub fn tracef(comptime fmt: []const u8, args: anytype) void {
    var buf: ?[]u8 = null;
    const out = format(fmt, args, &buf);
    defer if (buf) |ptr| {
        w4_alloc.a.allocator().free(ptr);
    };
    w4.trace(out);
}

pub fn text_centered(text: []const u8, y: i32) void {
    const width = text.len * 8;
    const x: i32 = @as(i32, @intCast((w4.SCREEN_SIZE - width) / 2));
    w4.text(text, x, y);
}
pub fn text_centeredf(comptime fmt: []const u8, args: anytype, y: i32) void {
    var buf: ?[]u8 = null;
    const out = format(fmt, args, &buf);
    defer if (buf) |ptr| {
        w4_alloc.a.allocator().free(ptr);
    };
    text_centered(out, y);
}
//mine
pub fn get_enum_len(opt: ?type) usize {
    if (opt) |t| {
        switch (@typeInfo(t)) {
            .@"enum" => |e| {
                return e.fields.len;
            },
            .void => {
                return 0;
            },
            else => {
                @compileError("get_enum_len on something other than enum");
            },
        }
    } else {
        return 0;
    }
}
