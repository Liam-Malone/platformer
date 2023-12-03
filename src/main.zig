const std = @import("std");
const graphics = @import("graphics.zig");
const audio = @import("audio.zig");
const player = @import("player.zig");
const c = @import("c.zig");

const Player = player.Player;
const Window = graphics.Window;

const FPS = 60;
const BACKGROUND_COLOR = graphics.Color.dark_gray;
const WINDOW_WIDTH = 800;
const WINDOW_HEIGHT = 600;

var window_width: u32 = 800;
var window_height: u32 = 600;
var quit: bool = false;
var pause = false;
pub fn main() !void {
    var window = try Window.init("ShooterGame", 0, 0, window_width, window_height);
    defer window.deinit();

    audio.open_audio(44100, 8, 2048);
    defer audio.close_audio();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    var the_player = Player.init(100, 100, 40, 60);

    while (!quit) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    quit = true;
                },
                c.SDL_KEYDOWN => switch (event.key.keysym.sym) {
                    'q' => {
                        quit = true;
                    },
                    ' ' => {
                        the_player.dy = -10;
                    },
                    else => {},
                },
                else => {},
            }
        }

        the_player.update();
        window.update();
        window.set_render_color(BACKGROUND_COLOR);
        window.render();

        the_player.draw(&window);

        c.SDL_RenderPresent(window.renderer);
        c.SDL_Delay(1000 / FPS);
    }
}
