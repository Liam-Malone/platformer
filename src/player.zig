const std = @import("std");
const graphics = @import("graphics.zig");
const c = @import("c.zig");

pub const Player = struct {
    x: i32,
    y: i32,
    w: u32,
    h: u32,
    dx: i32 = 0,
    dy: i32 = 0,
    hp: u8 = 10,
    hb_col: graphics.Color = graphics.Color.red,

    pub fn init(x: i32, y: i32, w: u32, h: u32) Player {
        return Player{
            .x = x,
            .y = y,
            .w = w,
            .h = h,
        };
    }

    pub fn update(self: *Player) void {
        self.x += self.dx;
        self.y += self.dy;

        if (self.dy < 9) self.dy += 1;
    }
    pub fn draw(self: *Player, window: *graphics.Window) void {
        window.set_render_color(self.hb_col);
        window.draw_rect(c.SDL_Rect{
            .x = @intCast(self.x),
            .y = @intCast(self.y),
            .w = @intCast(self.w),
            .h = @intCast(self.h),
        });
    }
};
