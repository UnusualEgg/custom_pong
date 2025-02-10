const w4 = @import("wasm4.zig");
const util = @import("w4_util.zig");
const std = @import("std");

const smiley = [8]u8{
    0b11000011,
    0b10000001,
    0b00100100,
    0b00100100,
    0b00000000,
    0b00100100,
    0b10011001,
    0b11000011,
};
const Color = u24;
const ColorIndex = u4;
const Paddle = struct {
    left: bool,
    y: i16,
    color: ColorIndex,
    w: u8,
    h: u8,
    ai: bool,
    const Self = @This();
    fn new(left: bool, ai: bool) Self {
        return Paddle{
            .left = left,
            .y = 0,
            .w = 10,
            .h = 40,
            .color = 4,
            .ai = ai,
        };
    }
    fn update(self: *Self, ball_y: i32) void {
        if (self.ai) {
            self.y = @as(i16, @truncate(ball_y)) - (self.h / 2);
            if (self.y + self.h > w4.SCREEN_SIZE) {
                self.y = @intCast(w4.SCREEN_SIZE - self.h);
            }
            if (self.y < 0) {
                self.y = 0;
            }
            return;
        }
        const gamepad: u8 = @as(*u8, @ptrFromInt(@intFromPtr(w4.GAMEPAD1) + @intFromBool(!self.left))).*;
        const speed: u8 = if (util.is_pressed(gamepad, w4.BUTTON_2)) 3 else 1;
        if (gamepad & w4.BUTTON_UP != 0) {
            self.y -|= speed;
            if (self.y < 0) {
                self.y = 0;
            }
        }
        if (gamepad & w4.BUTTON_DOWN != 0) {
            if (self.y + self.h < w4.SCREEN_SIZE) {
                self.y += speed;
            }
        }
    }
    fn draw(self: *const Self) void {
        w4.DRAW_COLORS.* = self.color;
        const x: i32 = if (self.left) 0 else @intCast(w4.SCREEN_SIZE - self.w);
        w4.rect(x, self.y, self.w, self.h);
    }
};
const CENTER = w4.SCREEN_SIZE / 2;
const Ball = struct {
    x: i32,
    y: i32,
    vx: i3,
    vy: i3,
    size: u8,
    color: ColorIndex,
    const Self = @This();
    fn new() Self {
        const size = 4;
        const middle = size / 2;
        const speed = 2;
        return Ball{
            .x = CENTER - middle,
            .y = CENTER - middle - 20,
            .vx = -speed,
            .vy = speed,
            .size = size,
            .color = 4,
        };
    }
    fn update(self: *Self) void {
        const oldy = self.y;
        self.x += self.vx;
        self.y += self.vy;
        if (self.y < 0 or self.y + self.size > w4.SCREEN_SIZE) {
            self.y = oldy;
            self.vy *= -1;
        }
    }
    fn bounce(self: *Self, paddle: *const Paddle) bool {
        const middle = self.size / 2;
        const center: i32 = @intCast(CENTER - middle);
        //TODO mkae a ball_top bottom side and same for paddle
        const ball_top = self.y;
        const ball_bottom = self.y + self.size;
        const ball_side =
            if (paddle.left) self.x else self.x + self.size;
        const paddle_top = paddle.y;
        const paddle_bottom = paddle.y + paddle.h;
        const paddle_side = if (paddle.left) paddle.w else w4.SCREEN_SIZE - paddle.w;
        const can_collide = if (paddle.left) ball_side < paddle_side else ball_side > paddle_side;
        if (can_collide) {
            self.vx *= -1;
            if (ball_bottom >= paddle_top and ball_top <= paddle_bottom) {
                self.x += self.vx;
                return false;
            } else {
                //then reset and give point
                self.x = center;
                self.y = center;
                return true;
            }
        }
        return false;
    }
    fn draw(self: *const Self) void {
        w4.DRAW_COLORS.* = self.color;
        w4.rect(self.x, self.y, self.size, self.size);
    }
    fn display(self: *const Self, y: comptime_int) void {
        w4.DRAW_COLORS.* = self.color;
        w4.rect(w4.SCREEN_SIZE / 2, y, self.size, self.size);
    }
};
const ENUM_TYPE = u8;
//Every single Screen/Menu we could be on
const Menu = enum(ENUM_TYPE) {
    Start,
    Game,
    Options,
    Colors,
    Palette,
    PaletteColor,
};
//static array maybe idk
const StartButtons = enum(ENUM_TYPE) {
    start,
    options,
    save,
    load,
    reset_score,
};
const OptionsButtons = enum(ENUM_TYPE) {
    colors,
    palette,
    enable_ai,
    back,
};
const ColorsButtons = enum(ENUM_TYPE) {
    paddle_left,
    paddle_right,
    ball,
    text,
    back,
};
const PaletteButtons = enum(ENUM_TYPE) {
    color1,
    color2,
    color3,
    color4,
    back,
};
const PaletteColorButtons = enum(ENUM_TYPE) {
    red,
    green,
    blue,
    back,
};
const Button = struct { name: []const u8, value: ENUM_TYPE };
const Buttons = struct {
    start: [get_enum_len(StartButtons)]Button,
    options: [get_enum_len(OptionsButtons)]Button,
    colors: [get_enum_len(ColorsButtons)]Button,
    palette: [get_enum_len(PaletteButtons)]Button,
    palette_color: [get_enum_len(PaletteColorButtons)]Button,
    fn new() Buttons {
        return Buttons{
            .start = gen_buttons(StartButtons),
            .options = gen_buttons(OptionsButtons),
            .colors = gen_buttons(ColorsButtons),
            .palette = gen_buttons(PaletteButtons),
            .palette_color = gen_buttons(PaletteColorButtons),
        };
    }
};

var BUTTONS: Buttons = undefined;
fn get_buttons(menu: Menu) ?[]const Button {
    return switch (menu) {
        .Start => &BUTTONS.start,
        .Options => &BUTTONS.options,
        .Colors => &BUTTONS.colors,
        .Palette => &BUTTONS.palette,
        .PaletteColor => &BUTTONS.palette_color,
        else => null,
    };
}
var alloc_buf: [128]u8 = undefined;
var fb_alloc = std.heap.FixedBufferAllocator.init(&alloc_buf);
var alloc = fb_alloc.allocator();
fn gen_buttons(t: type) [get_enum_len(t)]Button {
    var buttons: [get_enum_len(t)]Button = undefined;

    const fields = @typeInfo(t).@"enum".fields;
    inline for (fields, 0..) |field, i| {
        if (std.mem.indexOf(u8, field.name, "_") != null) {
            if (alloc.alloc(u8, field.name.len)) |output| {
                _ = std.mem.replace(u8, field.name, "_", " ", output);
                buttons[i] = Button{ .name = output, .value = @intCast(field.value) };
            } else |_| {
                buttons[i] = Button{ .name = "[NO SPACE!]", .value = @intCast(field.value) };
            }
        } else {
            buttons[i] = Button{ .name = field.name, .value = @intCast(field.value) };
        }
    }
    return buttons;
}
//contains bugtons
const Cursor = ENUM_TYPE;
inline fn get_menu_fields(T: type, val: T) type {
    return @TypeOf(@field(val, @tagName(val)));
}
fn get_enum_len(t: type) usize {
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
}
inline fn get_buttons_enum(menu: Menu) type {
    return switch (menu) {
        .Game => void,
        .Start => StartButtons,
        .Colors => ColorsButtons,
        .Options => OptionsButtons,
        .Palette => PaletteButtons,
        .PaletteColor => PaletteColorButtons,
    };
}
const menu_lens: [get_enum_len(Menu)]usize = blk: {
    var lens: [get_enum_len(Menu)]usize = undefined;
    for (@typeInfo(Menu).@"enum".fields) |field| {
        lens[field.value] = get_enum_len(get_buttons_enum(@enumFromInt(field.value)));
    }
    break :blk lens;
};
fn get_menu_len(menu: Menu) usize {
    return menu_lens[@intFromEnum(menu)];
}
const DiskSave = struct {
    ball_color: ColorIndex,
    paddle_l: ColorIndex,
    paddle_r: ColorIndex,
    text: ColorIndex,
    palette: [4]u32,
    fn from_state(s: *const State) DiskSave {
        return DiskSave{
            .ball_color = s.ball.color,
            .paddle_l = s.paddle_l.color,
            .paddle_r = s.paddle_r.color,
            .text = s.text_color,
            .palette = w4.PALETTE.*,
        };
    }
    fn to_state(self: *const DiskSave, s: *State) void {
        s.ball.color = self.ball_color;
        s.paddle_l.color = self.paddle_l;
        s.paddle_r.color = self.paddle_r;
        s.text_color = self.text;
        w4.PALETTE.* = self.palette;
    }
    fn save(self: *const DiskSave) void {
        const bytes = w4.diskw(@ptrCast(self), @sizeOf(DiskSave));
        util.tracef("wrote {} bytes", .{bytes});
    }
    fn load() DiskSave {
        var d: DiskSave = undefined;
        const bytes = w4.diskr(@ptrCast(&d), @sizeOf(DiskSave));
        util.tracef("read {} bytes", .{bytes});
        return d;
    }
};
const State = struct {
    paddle_l: Paddle,
    paddle_r: Paddle,
    ball: Ball,
    score_l: u16 = 0,
    score_r: u16 = 0,
    score_l_t: [2]u8 = .{ '0', '0' },
    score_r_t: [2]u8 = .{ '0', '0' },
    menu: Menu = .Start,
    cursor: Cursor = @intFromEnum(StartButtons.start),
    selected_color: u2 = 0,
    text_color: ColorIndex = 4,
    notif_text: ?[]const u8 = null,
    notif_timer: u8 = 0,
    const Self = @This();
    fn new() Self {
        return State{
            .paddle_l = Paddle.new(true, false),
            .paddle_r = Paddle.new(false, false),
            .ball = Ball.new(),
        };
    }
    fn save(self: *const Self) void {
        DiskSave.from_state(self).save();
    }
    fn load(self: *Self) void {
        DiskSave.load().to_state(self);
    }
    fn display(self: *Self, text: []const u8) void {
        self.notif_text = text;
        const secs = 2;
        self.notif_timer = 60 * secs;
    }
    fn display_palette(self: *const Self) void {
        for (1..5) |i| {
            w4.DRAW_COLORS.* = @intCast(i);
            const x: i32 = @intCast(i - 1);
            const height = 20;
            const y = w4.SCREEN_SIZE - height;
            w4.rect(x * (w4.SCREEN_SIZE / 4), y, w4.SCREEN_SIZE / 4, height);
        }
        self.ball.display(w4.SCREEN_SIZE / 2 + 8);
        self.paddle_l.draw();
        self.paddle_r.draw();
    }
    fn next(self: *Self) void {
        if (self.menu == .Game) return;

        const len = get_menu_len(self.menu);
        var curs = self.cursor;
        if (curs + 1 == len) {
            curs = 0;
        } else {
            curs = curs + 1;
        }
        self.cursor = curs;
    }
    fn prev(self: *Self) void {
        if (self.menu == .Game) return;
        const len = get_menu_len(self.menu);
        var curs = self.cursor;
        if (curs == 0) {
            curs = @truncate(len - 1);
        } else {
            curs = curs - 1;
        }
        self.cursor = curs;
    }
    fn get_color(self: *Self, button: ColorsButtons) ?*ColorIndex {
        return switch (button) {
            ColorsButtons.paddle_left => &self.paddle_l.color,
            ColorsButtons.paddle_right => &self.paddle_r.color,
            ColorsButtons.ball => &self.ball.color,
            ColorsButtons.text => &self.text_color,
            else => null,
        };
    }
    fn get_color_const(self: *const Self, button: ColorsButtons) ?*const ColorIndex {
        return switch (button) {
            ColorsButtons.paddle_left => &self.paddle_l.color,
            ColorsButtons.paddle_right => &self.paddle_r.color,
            ColorsButtons.ball => &self.ball.color,
            ColorsButtons.text => &self.text_color,
            else => null,
        };
    }
    fn go(self: *Self, menu: Menu) void {
        self.menu = menu;
        self.cursor = 0;
    }

    fn update(self: *Self) void {
        self.notif_timer -|= 1;
        if (self.notif_timer == 0) {
            self.notif_text = null;
        }
        switch (self.menu) {
            Menu.Game => {
                self.ball.update();
                self.paddle_l.update(self.ball.y);
                self.paddle_r.update(self.ball.y);
                const score_l = self.ball.bounce(&self.paddle_l);
                const score_r = self.ball.bounce(&self.paddle_r);
                if (score_l) {
                    self.score_r += 1;
                    if (self.score_r > 99) {
                        self.score_r = 0;
                    }
                    self.score_r_t = std.fmt.digits2(self.score_r);
                }
                if (score_r) {
                    self.score_l += 1;
                    if (self.score_l > 99) {
                        self.score_l = 0;
                    }
                    self.score_l_t = std.fmt.digits2(self.score_l);
                }
                if (score_l or score_r) {
                    w4.tone(240, 5, 100, w4.TONE_PULSE1);
                }
                if (util.is_pressed(util.get_pressed(0), w4.BUTTON_1)) {
                    self.go(.Start);
                    self.paddle_l = Paddle.new(true, false);
                    self.paddle_r = Paddle.new(false, self.paddle_r.ai);
                    self.ball = Ball.new();
                }
            },
            Menu.Start => {
                const pressed = util.get_pressed(0);
                if (util.is_pressed(pressed, w4.BUTTON_DOWN)) {
                    self.next();
                }
                if (util.is_pressed(pressed, w4.BUTTON_UP)) {
                    self.prev();
                }

                if (util.is_pressed(pressed, w4.BUTTON_1)) {
                    switch (@as(StartButtons, @enumFromInt(self.cursor))) {
                        StartButtons.start => {
                            self.go(.Game);
                        },
                        StartButtons.options => {
                            self.go(.Options);
                        },
                        StartButtons.save => {
                            self.save();
                            self.display("Saved!");
                        },
                        StartButtons.load => {
                            self.load();
                            self.display("Loaded!");
                        },
                        StartButtons.reset_score => {
                            self.score_l = 0;
                            self.score_l_t = .{ '0', '0' };
                            self.score_r = 0;
                            self.score_r_t = .{ '0', '0' };
                        },
                    }
                }
            },
            Menu.Options => {
                const pressed = util.get_pressed(0);
                if (util.is_pressed(pressed, w4.BUTTON_DOWN)) {
                    self.next();
                }
                if (util.is_pressed(pressed, w4.BUTTON_UP)) {
                    self.prev();
                }
                if (util.is_pressed(pressed, w4.BUTTON_LEFT) or util.is_pressed(pressed, w4.BUTTON_RIGHT)) {
                    if (@as(OptionsButtons, @enumFromInt(self.cursor)) == OptionsButtons.enable_ai) {
                        self.paddle_r.ai = !self.paddle_r.ai;
                    }
                }

                if (util.is_pressed(pressed, w4.BUTTON_1)) {
                    switch (@as(OptionsButtons, @enumFromInt(self.cursor))) {
                        OptionsButtons.colors => {
                            self.go(.Colors);
                        },
                        OptionsButtons.palette => {
                            self.go(.Palette);
                        },
                        OptionsButtons.back => {
                            self.go(.Start);
                        },
                        else => {},
                    }
                }
            },
            Menu.Colors => {
                const pressed = util.get_pressed(0);
                if (util.is_pressed(pressed, w4.BUTTON_DOWN)) {
                    self.next();
                }
                if (util.is_pressed(pressed, w4.BUTTON_UP)) {
                    self.prev();
                }
                const left = util.is_pressed(pressed, w4.BUTTON_LEFT);
                const right = util.is_pressed(pressed, w4.BUTTON_RIGHT);
                const color = self.get_color(@enumFromInt(self.cursor));
                if (color) |c| {
                    if (left) {
                        if (c.* == 0) c.* = 4 else c.* -%= 1;
                    }
                    if (right) {
                        c.* +%= 1;
                    }
                    if (c.* > 4) {
                        c.* = 0;
                    }
                } else {
                    if (util.is_pressed(pressed, w4.BUTTON_1)) {
                        self.go(Menu.Options);
                    }
                }
            },
            Menu.Palette => {
                const pressed = util.get_pressed(0);
                if (util.is_pressed(pressed, w4.BUTTON_DOWN)) {
                    self.next();
                }
                if (util.is_pressed(pressed, w4.BUTTON_UP)) {
                    self.prev();
                }
                if (util.is_pressed(pressed, w4.BUTTON_1)) {
                    if (self.cursor < 4) {
                        self.selected_color = @truncate(self.cursor);
                        self.go(.PaletteColor);
                    } else {
                        self.go(.Options);
                    }
                }
            },
            Menu.PaletteColor => {
                const pressed = util.get_pressed(0);
                const held = w4.GAMEPAD1.*;
                if (util.is_pressed(pressed, w4.BUTTON_DOWN)) {
                    self.next();
                }
                if (util.is_pressed(pressed, w4.BUTTON_UP)) {
                    self.prev();
                }
                const slow = util.is_pressed(held, w4.BUTTON_1);
                const slow_or_held = if (slow) pressed else held;
                const left = util.is_pressed(slow_or_held, w4.BUTTON_LEFT);
                const right = util.is_pressed(slow_or_held, w4.BUTTON_RIGHT);
                const ptr: *u32 = &w4.PALETTE[@intCast(self.selected_color)];
                const shift: u5 = @truncate((8 * (self.cursor)));
                var color: ?u8 = if (self.cursor < 3) @truncate(ptr.* >> (16 - shift)) else null;
                if (color) |*c| {
                    if (left) {
                        c.* -%= 1;
                    }
                    if (right) {
                        c.* +%= 1;
                    }
                    if (left or right) {
                        util.tracef("{X:0>2} w/ shift {}", .{ c.*, shift });
                        const mask = (@as(u24, 0xff0000) >> shift);
                        ptr.* &= ~mask;
                        util.tracef("mask {X:0>6}", .{~mask});
                        const combo: u24 = (@as(u24, c.*) << (16 - shift));
                        ptr.* |= combo;
                        util.tracef("ored{X:0>6} now {X:0>6}", .{ combo, ptr.* });
                    }
                } else {
                    if (util.is_pressed(pressed, w4.BUTTON_1)) {
                        self.go(Menu.Palette);
                    }
                }
            },
        }
    }
    fn draw(self: *const Self) void {
        switch (self.menu) {
            Menu.Game => {
                self.paddle_l.draw();
                self.paddle_r.draw();
                self.ball.draw();

                w4.DRAW_COLORS.* = self.text_color;
                util.text_centeredf("{s} {s}", .{ self.score_l_t, self.score_r_t }, 16);
            },
            Menu.Start, Menu.Palette => {
                w4.DRAW_COLORS.* = self.text_color;
                util.text_centered("Pong!", 8);

                const buttons = get_buttons(self.menu).?;
                for (buttons, 0..) |button, i| {
                    if (self.cursor == button.value) {
                        w4.DRAW_COLORS.* = @as(u16, @intCast(self.text_color)) << 4;
                    } else {
                        w4.DRAW_COLORS.* = self.text_color;
                    }
                    util.text_centered(button.name, @intCast(i * 8 + 24));
                }
                if (self.menu == Menu.Palette) self.display_palette();
            },
            Menu.Options => {
                w4.DRAW_COLORS.* = self.text_color;
                util.text_centered("Pong!", 8);

                const buttons = get_buttons(self.menu).?;
                for (buttons, 0..) |button, i| {
                    const selected = self.cursor == button.value;
                    if (selected) {
                        w4.DRAW_COLORS.* = @as(u16, @intCast(self.text_color)) << 4;
                    } else {
                        w4.DRAW_COLORS.* = self.text_color;
                    }
                    if (@as(OptionsButtons, @enumFromInt(i)) == OptionsButtons.enable_ai) {
                        const enable_ai = self.paddle_r.ai;
                        const text = if (enable_ai) "yes" else "no";
                        if (selected) {
                            util.text_centeredf("\x84{s}: {s}\x85", .{ button.name, text }, @intCast(i * 8 + 24));
                        } else {
                            util.text_centeredf("{s}: {s}", .{ button.name, text }, @intCast(i * 8 + 24));
                        }
                    } else {
                        util.text_centered(button.name, @intCast(i * 8 + 24));
                    }
                }
                if (self.menu == Menu.Palette) self.display_palette();
            },
            Menu.Colors => {
                w4.DRAW_COLORS.* = self.text_color;
                util.text_centered("Pong!", 8);

                const buttons = get_buttons(self.menu).?;
                for (buttons, 0..) |button, i| {
                    const c = self.get_color_const(@enumFromInt(button.value));
                    if (self.cursor == button.value) {
                        w4.DRAW_COLORS.* = @as(u16, @intCast(self.text_color)) << 4;
                    } else {
                        w4.DRAW_COLORS.* = self.text_color;
                    }
                    const y: i32 = @intCast(i * 8 + 24);
                    if (c) |color| {
                        if (self.cursor == button.value) {
                            util.text_centeredf("\x84{s} {}\x85", .{ button.name, color.* }, y);
                        } else {
                            util.text_centeredf("{s} {}", .{ button.name, color.* }, y);
                        }
                    } else {
                        util.text_centeredf("{s}", .{button.name}, y);
                    }
                    self.display_palette();
                }
            },
            Menu.PaletteColor => {
                w4.DRAW_COLORS.* = self.text_color;
                util.text_centered("Palette", 8);

                const buttons = get_buttons(self.menu).?;
                for (buttons, 0..) |button, i| {
                    const ptr: *u32 = &w4.PALETTE[@intCast(self.selected_color)];
                    const shift: u5 = @truncate((8 * (2 - i)));
                    const c: ?u8 = if (i < 3) @truncate(ptr.* >> shift) else null;

                    if (self.cursor == button.value) {
                        w4.DRAW_COLORS.* = @as(u16, @intCast(self.text_color)) << 4;
                    } else {
                        w4.DRAW_COLORS.* = self.text_color;
                    }
                    const y: i32 = @intCast(i * 8 + 24);
                    if (c) |color| {
                        if (self.cursor == button.value) {
                            util.text_centeredf("\x84{s} {X:0>2}\x85", .{ button.name, color }, y);
                        } else {
                            util.text_centeredf("{s} {X:0>2}", .{ button.name, color }, y);
                        }
                    } else {
                        util.text_centeredf("{s}", .{button.name}, y);
                    }
                }
                self.display_palette();
            },
        }
        if (self.notif_text) |text| {
            w4.DRAW_COLORS.* = self.text_color;
            util.text_centered(text, w4.SCREEN_SIZE - (8 * 2));
        }
    }
};
var state: State = undefined;

export fn start() void {
    w4.PALETTE.* = .{
        0x002b59,
        0x005f8c,
        0x00b9be,
        0x9ff4e5,
    };
    BUTTONS = Buttons.new();
    state = State.new();
}

export fn update() void {
    state.update();
    state.draw();
}
