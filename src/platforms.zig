const graphics = @import("graphics.zig");
const c = @import("c.zig");

pub const Platform = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    tex: graphics.Color = graphics.Color.green,

    pub fn init(x: i32, y: i32, w: i32, h: i32) Platform {
        return Platform{
            .x = x,
            .y = y,
            .w = w,
            .h = h,
        };
    }

    pub fn draw(self: *const Platform, window: *graphics.Window) void {
        window.set_render_color(self.tex);
        window.fill_rect(c.SDL_Rect{
            .x = @intCast(self.x),
            .y = @intCast(self.y),
            .w = @intCast(self.w),
            .h = @intCast(self.h),
        });
    }
};
