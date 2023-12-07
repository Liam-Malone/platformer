const std = @import("std");
const graphics = @import("graphics.zig");
const audio = @import("audio.zig");
const player = @import("player.zig");
const map = @import("map.zig");
const platforms = @import("platforms.zig");
const c = @import("c.zig");

const Player = player.Player;
const Window = graphics.Window;

const FPS = 60;
const BACKGROUND_COLOR = graphics.Color.dark_gray;
const WINDOW_WIDTH = 800;
const WINDOW_HEIGHT = 600;
const TILE_WIDTH = 20;
const TILE_HEIGHT = 20;

var window_width: i32 = 800;
var window_height: i32 = 600;
var quit: bool = false;
var edit_enabled: bool = false;
var pause: bool = true;
var selected_id: i32 = 1;
var left_mouse_is_down = false;

fn place_at_pos(x: u32, y: u32, tilemap: *map.Tilemap) void {
    if (edit_enabled) tilemap.edit_tile(selected_id, x / (TILE_WIDTH), y / (TILE_HEIGHT));
}

fn save(tm: *map.Tilemap, allocator: std.mem.Allocator) !void {
    try tm.save(allocator);
}

pub fn main() !void {
    var window = try Window.init("ShooterGame", 0, 0, window_width, window_height);
    defer window.deinit();

    audio.open_audio(44100, 8, 2048);
    defer audio.close_audio();

    var music = audio.Music.init("assets/music/8_Bit_Nostalgia.mp3");
    defer music.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    var the_player = Player.init(20, 0, 40, 60);
    var the_map = try map.Tilemap.init(alloc, WINDOW_WIDTH, WINDOW_HEIGHT, TILE_WIDTH, TILE_HEIGHT, "assets/maps/testing.map");

    var platform_arr = [_]platforms.Platform{
        platforms.Platform.init(20, 400, 40, 20),
        platforms.Platform.init(100, 400, 40, 20),
    };

    music.play();
    music.toggle_pause();

    var render_grid = true;

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
                    'm' => music.toggle_pause(),
                    'a' => the_player.dx = -2,
                    'd' => the_player.dx = 2,
                    's' => {
                        if (event.key.keysym.mod & c.KMOD_CTRL != 0) {
                            var t = try std.Thread.spawn(.{}, save, .{ &the_map, alloc });
                            t.detach();
                        }
                    },
                    ' ' => the_player.dy = -20,
                    'e' => edit_enabled = !edit_enabled,
                    'g' => render_grid = !render_grid,
                    '0' => selected_id = 0,
                    '1' => selected_id = 1,
                    else => {},
                },
                c.SDL_KEYUP => switch (event.key.keysym.sym) {
                    'a', 'd' => the_player.dx = 0,
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

        the_player.update(&window, &platform_arr);
        window.set_render_color(BACKGROUND_COLOR);
        window.update();
        window.render();

        the_map.draw(&window, render_grid);

        for (platform_arr) |p| {
            p.draw(&window);
        }

        the_player.draw(&window);

        c.SDL_RenderPresent(window.renderer);
        c.SDL_Delay(1000 / FPS);
    }
}
