const std = @import("std");
const c = @import("c.zig");

const FONT_FILE = @embedFile("DejaVuSans.ttf");

const DisplayMode = enum {
    windowed,
    fullscreen_desktop,
    fullscreen,
};

pub const Color = enum(u32) {
    white = 0xFFFFFFFF,
    purple = 0x7BF967AA,
    red = 0xFC1A17CC,
    dark_gray = 0x181818FF,
    blue = 0x0000CCFF,
    green = 0x00AA00FF,
    void = 0xFF00FFFF,

    pub fn make_sdl_color(col: Color) c.SDL_Color {
        var color = @intFromEnum(col);
        const r: u8 = @truncate((color >> (3 * 8)) & 0xFF);
        const g: u8 = @truncate((color >> (2 * 8)) & 0xFF);
        const b: u8 = @truncate((color >> (1 * 8)) & 0xFF);
        const a: u8 = @truncate((color >> (0 * 8)) & 0xFF);

        return c.SDL_Color{
            .r = r,
            .g = g,
            .b = b,
            .a = a,
        };
    }
};

pub const Window = struct {
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    w: i32,
    h: i32,
    mode: DisplayMode = DisplayMode.windowed,

    pub fn init(name: []const u8, x: u8, y: u8, w: i32, h: i32) !Window {
        if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) {
            c.SDL_Log("Unable to initialize SDL: {s}\n", c.SDL_GetError());
            return error.SDLInitializationFailed;
        }

        if (c.TTF_Init() < 0) {
            c.SDL_Log("Unable to initialize SDL: {s}\n", c.SDL_GetError());
        }

        const window = c.SDL_CreateWindow(@ptrCast(name), @intCast(x), @intCast(y), @intCast(w), @intCast(h), 0) orelse {
            c.SDL_Log("Unable to initialize SDL: {s}\n", c.SDL_GetError());
            return error.SDLInitializationFailed;
        };
        const renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED) orelse {
            c.SDL_Log("Unable to initialize SDL: {s}\n", c.SDL_GetError());
            return error.SDLInitializationFailed;
        };
        return Window{
            .window = window,
            .renderer = renderer,
            .w = w,
            .h = h,
        };
    }

    pub fn deinit(self: *Window) void {
        defer c.SDL_Quit();
        defer c.TTF_Quit();
        defer c.SDL_DestroyWindow(@ptrCast(self.window));
        defer c.SDL_DestroyRenderer(self.renderer);
    }

    pub fn set_fullscreen(self: *Window, fullscreen_type: u32) void {
        switch (fullscreen_type) {
            0 => {
                _ = c.SDL_SetWindowFullscreen(self.window, 0);
                self.mode = DisplayMode.windowed;
            },
            1 => {
                _ = c.SDL_SetWindowFullscreen(self.window, c.SDL_WINDOW_FULLSCREEN);
                self.mode = DisplayMode.fullscreen;
            },
            2 => {
                _ = c.SDL_SetWindowFullscreen(self.window, c.SDL_WINDOW_FULLSCREEN_DESKTOP);
                self.mode = DisplayMode.fullscreen_desktop;
            },
            else => {},
        }
    }

    pub fn toggle_fullscreen(self: *Window) void {
        switch (self.mode) {
            DisplayMode.fullscreen => {
                self.set_fullscreen(0);
            },
            DisplayMode.fullscreen_desktop => {
                self.set_fullscreen(1);
            },
            DisplayMode.windowed => {
                self.set_fullscreen(2);
            },
        }
    }

    fn window_size(self: *Window) void {
        var w: c_int = undefined;
        var h: c_int = undefined;
        _ = c.SDL_GetWindowSize(self.window, @ptrCast(&w), @ptrCast(&h));
        self.w = @intCast(w);
        self.h = @intCast(h);
    }
    pub fn update(self: *Window) void {
        window_size(self);
    }
    pub fn set_render_color(self: *Window, color: Color) void {
        const col = Color.make_sdl_color(color);
        _ = c.SDL_SetRenderDrawColor(self.renderer, col.r, col.g, col.b, col.a);
    }
    pub fn draw_rect(self: *Window, rect: c.SDL_Rect) void {
        _ = c.SDL_RenderDrawRect(self.renderer, &rect);
    }
    pub fn fill_rect(self: *Window, rect: c.SDL_Rect) void {
        _ = c.SDL_RenderFillRect(self.renderer, &rect);
    }
    pub fn render(self: *Window) void {
        _ = c.SDL_RenderClear(self.renderer);
    }
};
