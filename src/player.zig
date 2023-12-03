const std = @import("std");
const graphics = @import("graphics.zig");
const platforms = @import("platforms.zig");
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

    pub fn init(x: i32, y: i32, w: i32, h: i32) Player {
        return Player{
            .x = x,
            .y = y,
            .w = w,
            .h = h,
        };
    }

    pub fn update(self: *Player, window: *graphics.Window, platform_arr: []platforms.Platform) void {
        const newx = self.x + self.dx;
        const newy = self.y + self.dy;
        if (newx > 0 and newx + self.w < window.w) self.x = newx;
        if ((newy < self.y) or (newy > self.y and !self.on_platform(platform_arr) and newy + self.h < window.h)) self.y = newy;

        if (self.dy < 5) self.dy += 1;
    }

    fn on_platform(self: *Player, platform_arr: []platforms.Platform) bool {
        for (platform_arr) |p| {
            if (self.x + self.w >= p.x and self.x <= p.x + p.w and self.y + self.h + self.dy >= p.y) return true;
        }
        return false;
    }

    pub fn collide(self: *Player, x: i32, y: i32, w: i32, h: i32) bool {
        if (self.x >= x and self.x + self.w <= x + w and self.y >= y and self.y + self.h <= y + h) return true;
        return false;
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
