const util = @import("w4_util.zig");
const get_enum_len = util.get_enum_len;
const ENUM_TYPE = u8;
//Every single Screen/Menu we could be on
pub const Menu = enum(ENUM_TYPE) {
    Start,
    Game,
    Options,
    Colors,
    Palette,
    PaletteColor,
    Sizes,
};
//the buttons displayed on each menu
pub const StartButtons = enum(ENUM_TYPE) {
    start,
    options,
    save,
    load,
    reset_score,
};
pub const OptionsButtons = enum(ENUM_TYPE) {
    colors,
    palette,
    sizes,
    enable_ai,
    back,
};
pub const ColorsButtons = enum(ENUM_TYPE) {
    paddle_left,
    paddle_right,
    ball,
    text,
    back,
};
pub const PaletteButtons = enum(ENUM_TYPE) {
    color1,
    color2,
    color3,
    color4,
    back,
};
pub const PaletteColorButtons = enum(ENUM_TYPE) {
    red,
    green,
    blue,
    back,
};
pub const SizesButtons = enum(ENUM_TYPE) {
    paddle_width,
    paddle_height,
    ball_size,
    back,
};
pub const menu_len = get_enum_len(Menu);
const lookup = blk: {
    var lookup_enum: [menu_len]?type = .{null} ** menu_len;
    //only have to write associated enums here! :D
    lookup_enum[@intFromEnum(Menu.Start)] = StartButtons;
    lookup_enum[@intFromEnum(Menu.Game)] = null;
    lookup_enum[@intFromEnum(Menu.Colors)] = ColorsButtons;
    lookup_enum[@intFromEnum(Menu.Options)] = OptionsButtons;
    lookup_enum[@intFromEnum(Menu.Palette)] = PaletteButtons;
    lookup_enum[@intFromEnum(Menu.PaletteColor)] = PaletteColorButtons;
    lookup_enum[@intFromEnum(Menu.Sizes)] = SizesButtons;
    break :blk lookup_enum;
};
//change above to add/remove menus/buttons
pub const Button = struct { name: []const u8, value: ENUM_TYPE };

pub fn get_buttons(menu: Menu) ?[]const Button {
    return BUTTONS[@intFromEnum(menu)];
}
inline fn get_buttons_enum(menu: Menu) ?type {
    return lookup[@intFromEnum(menu)];
}
pub fn get_menu_len(menu: Menu) usize {
    return menu_lens[@intFromEnum(menu)];
}
//below here is automated so shouldn't need to change much
const menu_lens: [get_enum_len(Menu)]usize = blk: {
    var lens: [get_enum_len(Menu)]usize = undefined;
    for (@typeInfo(Menu).@"enum".fields) |field| {
        lens[field.value] = get_enum_len(get_buttons_enum(@enumFromInt(field.value)));
    }
    break :blk lens;
};
//we need a buf of side_by_side strings and buttons with refs to those strings
//then a list of refs to slice of buttons (key=Menu,value=[]Button)
//1. put field names ino buf
//2. buf -> buttons_buf
//3. have list of button slices

//first calc lengths
const total_fields = blk: {
    var total_fields_n = 0;
    for (lookup) |t| {
        if (t) |ty| {
            const fields = @typeInfo(ty).@"enum".fields;
            total_fields_n += fields.len;
        }
    }
    break :blk total_fields_n;
};
const total_name_len = blk: {
    var total_name_len_n = 0;
    for (lookup) |t| {
        if (t) |ty| {
            const fields = @typeInfo(ty).@"enum".fields;
            for (fields) |field| {
                total_name_len_n += field.name.len;
            }
        }
    }
    break :blk total_name_len_n;
};
//then make bufs
var names_buf: [total_name_len]u8 = blk: {
    var names_buf_local: [total_name_len]u8 = undefined;
    var buf_i = 0;
    var button_i = 0;
    var menu_i = 0;
    for (lookup) |t| {
        if (t) |ty| {
            const fields = @typeInfo(ty).@"enum".fields;
            for (fields) |field| {
                const field_len = field.name.len;
                const str: []u8 = names_buf_local[buf_i..(buf_i + field_len)];
                //replace
                for (field.name, 0..) |char, i| {
                    if (char == '_') {
                        str[i] = ' ';
                    } else {
                        str[i] = char;
                    }
                }

                buf_i += field_len;
                button_i += 1;
            }
        }
        menu_i += 1;
    }
    break :blk names_buf_local;
};
var buttons_buf: [total_fields]Button = blk: {
    var buttons_buf_local: [total_fields]Button = undefined;
    var buf_i = 0;
    var button_i = 0;
    var menu_i = 0;
    for (lookup) |t| {
        if (t) |ty| {
            const fields = @typeInfo(ty).@"enum".fields;
            for (fields) |field| {
                const field_len = field.name.len;
                const str: []u8 = names_buf[buf_i..(buf_i + field_len)];
                //then make buttons with refs to those
                buttons_buf_local[button_i] = Button{ .name = str, .value = field.value };

                buf_i += field_len;
                button_i += 1;
            }
        }
        menu_i += 1;
    }
    break :blk buttons_buf_local;
};
//then make list of slices that reference the bufs
//index this with a Menu to get a slice(array) of buttons(which have names(strings) and values(value of enum))
const BUTTONS = blk: {
    var buttons: [menu_len]?[]Button = undefined;
    var button_i = 0;
    var menu_i = 0;
    for (lookup) |t| {
        if (t) |ty| {
            const fields = @typeInfo(ty).@"enum".fields;
            const buttons_begin = button_i;
            button_i += fields.len;
            buttons[menu_i] = buttons_buf[buttons_begin..button_i];
        } else {
            buttons[menu_i] = null;
        }
        menu_i += 1;
    }
    break :blk buttons;
};
