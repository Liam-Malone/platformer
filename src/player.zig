const std = @import("std");
const graphics = @import("graphics.zig");
const c = @import("c.zig");

pub const Player = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    dx: i32 = 0,
    dy: i32 = 0,
    hp: u8 = 10,
    hb_col: graphics.Color = graphics.Color.red,
    tex: ?*c.SDL_Texture,

    pub fn init(x: i32, y: i32, w: i32, h: i32, tex: ?*c.SDL_Texture) Player {
        return Player{
            .x = x,
            .y = y,
            .w = w,
            .h = h,
            .tex = tex,
        };
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
