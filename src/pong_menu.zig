const menu = @import("menu.zig");

const ENUM_TYPE = u8;
//Every single Screen/Menu we could be on
pub const Menus = enum(ENUM_TYPE) {
    Start,
    Game,
    Options,
    Colors,
    Palette,
    PaletteColor,
    Sizes,
};
//the buttons displayed on each menu
pub const Buttons = .{
    .Start = enum(ENUM_TYPE) {
        start,
        options,
        save,
        load,
        reset_score,
    },
    .Options = enum(ENUM_TYPE) {
        colors,
        palette,
        sizes,
        enable_ai,
        back,
    },
    .Colors = enum(ENUM_TYPE) {
        paddle_left,
        paddle_right,
        ball,
        text,
        back,
    },
    .Palette = enum(ENUM_TYPE) {
        color1,
        color2,
        color3,
        color4,
        back,
    },
    .PaletteColor = enum(ENUM_TYPE) {
        red,
        green,
        blue,
        back,
    },
    .Sizes = enum(ENUM_TYPE) {
        paddle_width,
        paddle_height,
        ball_size,
        back,
    },
};
pub const Menu: type = menu.menus(
    ENUM_TYPE,
    Menus,
    Buttons,
);
