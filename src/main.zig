const std = @import("std");
const graphics = @import("graphics.zig");
const audio = @import("audio.zig");
const player = @import("player.zig");
const map = @import("map.zig");
const c = @import("c.zig");

const Player = player.Player;
const Window = graphics.Window;

const FPS = 60;
const BACKGROUND_COLOR = graphics.Color.dark_gray;
const WINDOW_WIDTH = 800;
const WINDOW_HEIGHT = 600;
const TILE_WIDTH = 20;
const TILE_HEIGHT = 20;

var window_width: u32 = 800;
var window_height: u32 = 600;
var quit: bool = false;
var edit_enabled: bool = false;
var pause: bool = true;
var selected_id: i32 = 1;
var left_mouse_is_down = false;

fn place_at_pos(x: u32, y: u32, tilemap: *map.Tilemap) void {
    if (edit_enabled) tilemap.edit_tile(selected_id, x / (TILE_WIDTH), y / (TILE_HEIGHT));
}

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
    var the_map = try map.Tilemap.init(alloc, WINDOW_WIDTH, WINDOW_HEIGHT, TILE_WIDTH, TILE_HEIGHT);

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
                    'e' => edit_enabled = !edit_enabled,
                    '0' => selected_id = 0,
                    '1' => selected_id = 1,
                    else => {},
                },
                c.SDL_MOUSEBUTTONDOWN => switch (event.button.button) {
                    c.SDL_BUTTON_LEFT => {
                        left_mouse_is_down = true;
                    },
                    else => {},
                },
                c.SDL_MOUSEBUTTONUP => switch (event.button.button) {
                    c.SDL_BUTTON_LEFT => {
                        left_mouse_is_down = false;
                        //clicked_button = false;
                    },
                    else => {},
                },
                c.SDL_MOUSEMOTION => switch (left_mouse_is_down) {
                    true => {
                        const x = if (event.button.x > 0) @as(u32, @intCast(event.button.x)) else 0;
                        const y = if (event.button.y > 0) @as(u32, @intCast(event.button.y)) else 0;
                        place_at_pos(x, y, &the_map);
                        window.update();
                    },
                    false => {},
                },

                else => {},
            }
        }

        the_player.update();
        window.update();
        window.set_render_color(BACKGROUND_COLOR);
        window.render();

        the_map.draw(&window);
        the_player.draw(&window);

        c.SDL_RenderPresent(window.renderer);
        c.SDL_Delay(1000 / FPS);
    }
}
