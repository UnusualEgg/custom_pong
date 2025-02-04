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
    y: u8,
    color: ColorIndex,
    w: u8,
    h: u8,
    const Self = @This();
    fn new(left: bool) Self {
        return Paddle{
            .left = left,
            .y = 0,
            .w = 10,
            .h = 40,
            .color = 4,
        };
    }
    fn update(self: *Self) void {
        const gamepad: u8 = @as(*u8, @ptrFromInt(@intFromPtr(w4.GAMEPAD1) + @intFromBool(!self.left))).*;
        if (gamepad & w4.BUTTON_UP != 0) {
            if (self.y > 0) {
                self.y -= 1;
            }
        }
        if (gamepad & w4.BUTTON_DOWN != 0) {
            if (self.y + self.h < w4.SCREEN_SIZE) {
                self.y += 1;
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
    vx: i2,
    vy: i2,
    size: u8,
    color: ColorIndex,
    const Self = @This();
    fn new() Self {
        const size = 4;
        const middle = size / 2;
        return Ball{
            .x = CENTER - middle,
            .y = CENTER - middle - 20,
            .vx = -1,
            .vy = 1,
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
            if (ball_bottom >= paddle_top and ball_top <= paddle_bottom) {
                self.vx *= -1;
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
};
const State = struct {
    paddle_l: Paddle,
    paddle_r: Paddle,
    ball: Ball,
    score_l: u16 = 0,
    score_r: u16 = 0,
    const Self = @This();
    fn new() Self {
        return State{
            .paddle_l = Paddle.new(true),
            .paddle_r = Paddle.new(false),
            .ball = Ball.new(),
        };
    }
    fn update(self: *Self) void {
        self.ball.update();
        self.paddle_l.update();
        self.paddle_r.update();
        const score_l = self.ball.bounce(&self.paddle_l);
        const score_r = self.ball.bounce(&self.paddle_r);
        if (score_l) {
            self.score_r += 1;
        }
        if (score_r) {
            self.score_l += 1;
        }
        if (score_l or score_r) {
            w4.tone(240, 5, 100, w4.TONE_PULSE1);
        }
    }
    fn draw(self: *const Self) void {
        self.paddle_l.draw();
        self.paddle_r.draw();
        self.ball.draw();
        util.text_centeredf("{d:0>2} {d:0<2}", .{ self.score_l, self.score_r }, 16);
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
