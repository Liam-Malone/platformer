const graphics = @import("graphics.zig");

pub const Platform = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    pub fn init(x: i32, y: i32, w: u32, h: u32) Platform {
        return Platform{
            .x = x,
            .y = y,
            .w = w,
            .h = h,
        };
    }
};
