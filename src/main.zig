const w4 = @import("wasm4.zig");
const util = @import("w4_util.zig");
const std = @import("std");
const menu_mod = @import("pong_menu.zig");
const Menu = menu_mod.Menus;

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
    fn center_self(self: *Self) void {
        const middle = self.size / 2;
        self.x = @intCast(CENTER - middle);
        self.y = @intCast(CENTER - middle);
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
        w4.rect(@as(i32, @intCast(w4.SCREEN_SIZE / 2)) - @divFloor(@as(i32, @intCast(self.size)), 2), y, self.size, self.size);
    }
};
const ENUM_TYPE = u8;
//contains an enum value of type menu_type_lookup[menu]
const Cursor = ENUM_TYPE;
inline fn get_menu_fields(T: type, val: T) type {
    return @TypeOf(@field(val, @tagName(val)));
}
const DiskSave = struct {
    ball_color: ColorIndex,
    paddle_l: ColorIndex,
    paddle_r: ColorIndex,
    text: ColorIndex,
    palette: [4]u32,
    paddle_w: u8,
    paddle_h: u8,
    ball_size: u8,
    fn from_state(s: *const State) DiskSave {
        return DiskSave{
            .ball_color = s.ball.color,
            .paddle_l = s.paddle_l.color,
            .paddle_r = s.paddle_r.color,
            .text = s.text_color,
            .palette = w4.PALETTE.*,
            .paddle_w = s.paddle_l.w,
            .paddle_h = s.paddle_l.h,
            .ball_size = s.ball.size,
        };
    }
    fn to_state(self: *const DiskSave, s: *State) void {
        s.ball.color = self.ball_color;
        s.paddle_l.color = self.paddle_l;
        s.paddle_r.color = self.paddle_r;
        s.text_color = self.text;
        w4.PALETTE.* = self.palette;
        s.paddle_l.w = self.paddle_w;
        s.paddle_l.h = self.paddle_h;
        s.paddle_r.w = self.paddle_w;
        s.paddle_r.h = self.paddle_h;
        s.ball.size = self.ball_size;
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
    menu: menu_mod.Menu,
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
            .menu = menu_mod.Menu{ .cursor = 0, .current_menu = menu_mod.Menus.Start },
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
        self.menu.next();
    }
    fn prev(self: *Self) void {
        self.menu.prev();
    }
    fn go(self: *Self, menu: Menu) void {
        self.menu.go(menu);
    }
    const ColorsButtons = menu_mod.Buttons.Colors;
    fn get_color(self: *Self, button: ColorsButtons) ?*ColorIndex {
        return switch (button) {
            ColorsButtons.paddle_left => &self.paddle_l.color,
            ColorsButtons.paddle_right => &self.paddle_r.color,
            ColorsButtons.ball => &self.ball.color,
            ColorsButtons.text => &self.text_color,
            else => null,
        };
    }
    const SizesButtons = menu_mod.Buttons.Sizes;
    fn get_size(self: *const Self, button: SizesButtons) ?u8 {
        return switch (button) {
            SizesButtons.paddle_width => self.paddle_l.w,
            SizesButtons.paddle_height => self.paddle_l.h,
            SizesButtons.ball_size => self.ball.size,
            else => null,
        };
    }
    fn set_size(self: *Self, button: SizesButtons, size: u8) void {
        switch (button) {
            SizesButtons.paddle_width => {
                self.paddle_l.w = size;
                self.paddle_r.w = size;
            },
            SizesButtons.paddle_height => {
                self.paddle_l.h = size;
                self.paddle_r.h = size;
            },
            SizesButtons.ball_size => {
                self.ball.size = size;
                self.ball.center_self();
            },
            else => {},
        }
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
    fn set_draw_color(self: *const Self, selected: bool) void {
        if (selected) {
            w4.DRAW_COLORS.* = @as(u16, @intCast(self.text_color)) << 4;
        } else {
            w4.DRAW_COLORS.* = self.text_color;
        }
    }

    fn update(self: *Self) void {
        self.notif_timer -|= 1;
        if (self.notif_timer == 0) {
            self.notif_text = null;
        }
        switch (self.menu.current_menu) {
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
                    self.score_r_t = std.fmt.digits2(@intCast(self.score_r));
                }
                if (score_r) {
                    self.score_l += 1;
                    if (self.score_l > 99) {
                        self.score_l = 0;
                    }
                    self.score_l_t = std.fmt.digits2(@intCast(self.score_l));
                }
                if (score_l or score_r) {
                    w4.tone(240, 5, 100, w4.TONE_PULSE1);
                }
                if (util.is_pressed(util.get_pressed(0), w4.BUTTON_1)) {
                    self.go(.Start);
                    const temp = DiskSave.from_state(self);
                    self.paddle_l = Paddle.new(true, false);
                    self.paddle_r = Paddle.new(false, self.paddle_r.ai);
                    self.ball.center_self();
                    temp.to_state(self);
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
                    const StartButtons = menu_mod.Buttons.Start;
                    switch (@as(StartButtons, @enumFromInt(self.menu.cursor))) {
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
                //function that takes in left,right, and self
                //another for draw maybe
                if (util.is_pressed(pressed, w4.BUTTON_LEFT) or util.is_pressed(pressed, w4.BUTTON_RIGHT)) {
                    if (@as(menu_mod.Buttons.Options, @enumFromInt(self.menu.cursor)) == menu_mod.Buttons.Options.enable_ai) {
                        self.paddle_r.ai = !self.paddle_r.ai;
                    }
                }

                if (util.is_pressed(pressed, w4.BUTTON_1)) {
                    const OptionsButtons = menu_mod.Buttons.Options;
                    switch (@as(OptionsButtons, @enumFromInt(self.menu.cursor))) {
                        OptionsButtons.colors => {
                            self.go(.Colors);
                        },
                        OptionsButtons.palette => {
                            self.go(.Palette);
                        },
                        OptionsButtons.sizes => {
                            self.go(.Sizes);
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
                const color = self.get_color(@enumFromInt(self.menu.cursor));
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
                    if (self.menu.cursor < 4) {
                        self.selected_color = @truncate(self.menu.cursor);
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
                const shift: u5 = @truncate((8 * (self.menu.cursor)));
                var color: ?u8 = if (self.menu.cursor < 3) @truncate(ptr.* >> (16 - shift)) else null;
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
            Menu.Sizes => {
                const pressed = util.get_pressed(0);
                if (util.is_pressed(pressed, w4.BUTTON_DOWN)) {
                    self.next();
                }
                if (util.is_pressed(pressed, w4.BUTTON_UP)) {
                    self.prev();
                }
                const left = util.is_pressed(pressed, w4.BUTTON_LEFT);
                const right = util.is_pressed(pressed, w4.BUTTON_RIGHT);
                const size = self.get_size(@enumFromInt(self.menu.cursor));
                if (size) |s| {
                    var new_size = s;
                    if (left) {
                        new_size -|= 1;
                    }
                    if (right) {
                        new_size +|= 1;
                    }
                    self.set_size(@enumFromInt(self.menu.cursor), new_size);
                } else if (util.is_pressed(pressed, w4.BUTTON_1)) {
                    self.go(Menu.Options);
                }
            },
        }
    }

    fn draw(self: *const Self) void {
        switch (self.menu.current_menu) {
            Menu.Game => {
                self.paddle_l.draw();
                self.paddle_r.draw();
                self.ball.draw();

                w4.DRAW_COLORS.* = self.text_color;
                _ = util.text_centeredf("{s} {s}", .{ self.score_l_t, self.score_r_t }, 16);
            },
            Menu.Start, Menu.Palette => {
                w4.DRAW_COLORS.* = self.text_color;
                _ = util.text_centered("Pong!", 8);

                const buttons = menu_mod.Menu.get_buttons(self.menu.current_menu).?;
                for (buttons, 0..) |button, i| {
                    if (self.menu.cursor == button.value) {
                        w4.DRAW_COLORS.* = @as(u16, @intCast(self.text_color)) << 4;
                    } else {
                        w4.DRAW_COLORS.* = self.text_color;
                    }
                    _ = util.text_centered(button.name, @intCast(i * 8 + 24));
                }
                if (self.menu.current_menu == Menu.Palette) self.display_palette();
            },
            Menu.Options => {
                w4.DRAW_COLORS.* = self.text_color;
                _ = util.text_centered("Pong!", 8);

                const buttons = menu_mod.Menu.get_buttons(self.menu.current_menu).?;
                for (buttons, 0..) |button, i| {
                    const selected = self.menu.cursor == button.value;
                    self.set_draw_color(selected);
                    if (@as(menu_mod.Buttons.Options, @enumFromInt(i)) == menu_mod.Buttons.Options.enable_ai) {
                        const enable_ai = self.paddle_r.ai;
                        const text = if (enable_ai) "yes" else "no";
                        if (selected) {
                            _ = util.text_centeredf("\x84{s}: {s}\x85", .{ button.name, text }, @intCast(i * 8 + 24));
                        } else {
                            _ = util.text_centeredf("{s}: {s}", .{ button.name, text }, @intCast(i * 8 + 24));
                        }
                    } else {
                        _ = util.text_centered(button.name, @intCast(i * 8 + 24));
                    }
                }
                if (self.menu.current_menu == Menu.Palette) self.display_palette();
            },
            Menu.Colors => {
                w4.DRAW_COLORS.* = self.text_color;
                _ = util.text_centered("Pong!", 8);

                const buttons = menu_mod.Menu.get_buttons(self.menu.current_menu).?;
                for (buttons, 0..) |button, i| {
                    const c = self.get_color_const(@enumFromInt(button.value));
                    self.set_draw_color(self.menu.cursor == button.value);
                    const y: i32 = @intCast(i * 8 + 24);
                    if (c) |color| {
                        if (self.menu.cursor == button.value) {
                            _ = util.text_centeredf("\x84{s} {}\x85", .{ button.name, color.* }, y);
                        } else {
                            _ = util.text_centeredf("{s} {}", .{ button.name, color.* }, y);
                        }
                    } else {
                        _ = util.text_centeredf("{s}", .{button.name}, y);
                    }
                    self.display_palette();
                }
            },
            Menu.Sizes => {
                w4.DRAW_COLORS.* = self.text_color;
                self.display_palette();
                _ = util.text_centered("Pong!", 8);

                const buttons = menu_mod.Menu.get_buttons(self.menu.current_menu).?;
                for (buttons, 0..) |button, i| {
                    const size_opt = self.get_size(@enumFromInt(button.value));

                    self.set_draw_color(self.menu.cursor == button.value);
                    const y: i32 = @intCast(i * 8 + 24);
                    if (size_opt) |size| {
                        if (self.menu.cursor == button.value) {
                            _ = util.text_centeredf("\x84{s} {}\x85", .{ button.name, size }, y);
                        } else {
                            _ = util.text_centeredf("{s} {}", .{ button.name, size }, y);
                        }
                    } else {
                        _ = util.text_centeredf("{s}", .{button.name}, y);
                    }
                }
            },
            Menu.PaletteColor => {
                w4.DRAW_COLORS.* = self.text_color;
                _ = util.text_centered("Palette", 8);

                const buttons = menu_mod.Menu.get_buttons(self.menu.current_menu).?;
                for (buttons, 0..) |button, i| {
                    const ptr: *u32 = &w4.PALETTE[@intCast(self.selected_color)];
                    const shift: u5 = @truncate((8 * (2 - i)));
                    const c: ?u8 = if (i < 3) @truncate(ptr.* >> shift) else null;

                    self.set_draw_color(self.menu.cursor == button.value);
                    const y: i32 = @intCast(i * 8 + 24);
                    if (c) |color| {
                        if (self.menu.cursor == button.value) {
                            _ = util.text_centeredf("\x84{s} {X:0>2}\x85", .{ button.name, color }, y);
                        } else {
                            _ = util.text_centeredf("{s} {X:0>2}", .{ button.name, color }, y);
                        }
                    } else {
                        _ = util.text_centeredf("{s}", .{button.name}, y);
                    }
                }
                self.display_palette();
            },
        }
        if (self.notif_text) |text| {
            w4.DRAW_COLORS.* = self.text_color;
            _ = util.text_centered(text, w4.SCREEN_SIZE - (8 * 2));
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
    state = State.new();
}

export fn update() void {
    state.update();
    state.draw();
}
