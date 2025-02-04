const std = @import("std");
const size = 1024;
var format_buffer: [size]u8 = undefined;

pub var a = std.heap.FixedBufferAllocator.init(&format_buffer);
