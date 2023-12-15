const std = @import("std");
const map = @import("map.zig");
const c = @import("c.zig");

// BEGIN ENUMS
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
// END ENUMS

// BEGIN STRUCTS
const Camera = struct {
    x: i32 = 0,
    y: i32 = 0,
    w: i32 = SCREEN_WIDTH,
    h: i32 = SCREEN_HEIGHT,
    dx: i32 = 0,
    dy: i32 = 0,
};

const Music = struct {
    music: *c.Mix_Music,
    playing: bool = false,
    paused: bool = false,

    pub fn init(path: [*c]const u8) ?Music {
        if (load(path)) |mm| {
            return Music{
                .music = mm,
            };
        } else {
            std.debug.print("could not find/load music\n", .{});
        }
        return null;
    }
    pub fn deinit(self: *Music) void {
        c.Mix_FreeMusic(self.music);
    }

    fn load(path: [*c]const u8) ?*c.Mix_Music {
        return c.Mix_LoadMUS(path);
    }
    pub fn play(self: *Music) void {
        switch (c.Mix_PlayingMusic() == 0) {
            true => {
                _ = c.Mix_PlayMusic(self.music, -1);
                self.playing = true;
                return;
            },
            false => {
                if (c.Mix_PausedMusic() == 1) _ = c.Mix_ResumeMusic();
                self.paused = false;
                return;
            },
        }
    }
    pub fn toggle_pause(self: *Music) void {
        switch (self.playing) {
            true => {
                if (self.paused) {
                    _ = c.Mix_ResumeMusic();
                    self.paused = false;
                } else {
                    _ = c.Mix_PauseMusic();
                    self.paused = true;
                }
                return;
            },
            false => {
                return;
            },
        }
    }
    pub fn halt(self: *Music) void {
        if (self.playing) _ = c.Mix_HaltMusic;
    }
};

const Player = struct {
    x: i32 = (SCREEN_WIDTH / 2) - 80,
    y: i32 = (SCREEN_HEIGHT / 2) - 80,
    w: c_int = 80,
    h: c_int = 80,
    dx: i32 = 0,
    dy: i32 = 0,
};

const SoundEffect = struct {
    effect: ?*c.Mix_Chunk,
    timestamp: i64,

    pub fn init(path: []const u8) SoundEffect {
        std.debug.print("\ntrying path: {s}\n", .{path});
        return SoundEffect{
            .effect = load(@ptrCast(path)),
            .timestamp = std.time.milliTimestamp(),
        };
    }
    pub fn deinit(self: *SoundEffect) void {
        c.Mix_FreeChunk(self.effect);
    }
    fn load(path: [*c]const u8) ?*c.Mix_Chunk {
        if (c.Mix_LoadWAV(path) == null) {
            std.debug.print("failed:\n {s}\n", .{c.Mix_GetError()});
        }
        return c.Mix_LoadWAV(path);
    }

    pub fn play(self: *SoundEffect) void {
        _ = c.Mix_PlayChannel(-1, self.effect, 0);
    }
};

const Vec2 = struct {
    x: i32,
    y: i32,
    mag: i32,

    fn normal_vec(self: *Vec2) Vec2 {
        return Vec2{
            .x = @divFloor(self.x, self.mag),
            .y = @divFloor(self.x, self.mag),
        };
    }
};
// END STRUCTS

// BEGIN CONSTANTS
const FPS = 60;
const FRAME_DELAY = 1000 / FPS;
const BACKGROUND_COLOR = Color.dark_gray;
const SCREEN_WIDTH = 1200;
const SCREEN_HEIGHT = 800;
const TILE_WIDTH = 32;
const TILE_HEIGHT = 32;
// END CONSTANTS

//BEGIN FUNCTIONS

fn collide(rect_a: *const c.SDL_Rect, rect_b: *const c.SDL_Rect) bool {
    return c.SDL_HasIntersection(rect_a, rect_b) != 0;
}

fn direct_cam_toward_player(player: *Player, cam: *Camera) void {
    const xmid = @divFloor(cam.w, 2);
    const ymid = @divFloor(cam.h, 2);
    const dx = (player.x + player.w) - (cam.x + xmid);
    const dy = (player.y + player.h) - (cam.y + ymid);
    if (cam.x + dx > 0) cam.x += dx;
    if (cam.y + dy > 0) cam.y += dy;
}
fn place_at_pos(x: u32, y: u32, tilemap: *map.Tilemap, id: u8) void {
    tilemap.edit_tile(id, x / (TILE_WIDTH), y / (TILE_HEIGHT));
}

fn save(tm: *map.Tilemap, allocator: std.mem.Allocator) !void {
    try tm.save(allocator);
}

fn set_fullscreen(window: *c.SDL_Window, fullscreen_type: u32) void {
    switch (fullscreen_type) {
        0 => {
            _ = c.SDL_SetWindowFullscreen(window, 0);
        },
        1 => {
            _ = c.SDL_SetWindowFullscreen(window, c.SDL_SCREEN_FULLSCREEN);
        },
        2 => {
            _ = c.SDL_SetWindowFullscreen(window, c.SDL_SCREEN_FULLSCREEN_DESKTOP);
        },
        else => {},
    }
}

fn set_render_color(renderer: *c.SDL_Renderer, color: Color) void {
    const col = Color.make_sdl_color(color);
    _ = c.SDL_SetRenderDrawColor(renderer, col.r, col.g, col.b, col.a);
}

//*****************//
//  *** TODO ***   //
//                 //
//    FIX THIS     //
//    COS I AM     //
//    BRAINDEAD    //
//*****************//
fn vcollide_player_with_tiles(p: *Player, tm: *map.Tilemap) bool {
    if (p.y < 0 or p.y > SCREEN_HEIGHT) return false;
    if (p.dy == 0) {
        const x_idx: usize = @intCast(@divFloor(p.x, TILE_WIDTH));
        const y_idx: usize = @intCast(@divFloor(p.y + p.h, TILE_HEIGHT));
        if (p.y + p.h >= tm.map[y_idx][x_idx].y and tm.map[y_idx][x_idx].collides) {
            return true;
        } else if (p.y + p.h >= tm.map[y_idx][x_idx + 1].x and tm.map[y_idx][x_idx + 1].collides) {
            return true;
        }

        return false;
    }
    switch (p.dy > 0) {
        true => {
            const x_idx: usize = @intCast(@divFloor(p.x, TILE_WIDTH));
            const y_idx: usize = @intCast(@divFloor(p.y + p.h + p.dy, TILE_HEIGHT));
            if (p.y + p.h + p.dy >= tm.map[y_idx][x_idx].y and tm.map[y_idx][x_idx].collides) {
                if (p.dy > 0) p.dy = 0;
                return true;
            } else if (p.y + p.h >= tm.map[y_idx][x_idx + 1].x and tm.map[y_idx][x_idx + 1].collides) {
                return true;
            }

            return false;
        },
        false => {
            const x_idx: usize = @intCast(@divFloor(p.x, TILE_WIDTH));
            const y_idx: usize = @intCast(@divFloor(if (p.y + p.dy > 0) p.y + p.dy else p.y, TILE_HEIGHT));
            if (p.y + p.dy <= tm.map[y_idx][x_idx].y + tm.map[y_idx][x_idx].h and tm.map[y_idx][x_idx].collides) {
                if (p.dy < 0) p.dy = 0;
                return true;
            } else if (p.y + p.dy <= tm.map[y_idx][x_idx + 1].y + tm.map[y_idx][x_idx + 1].h and tm.map[y_idx][x_idx + 1].collides) {
                return true;
            }

            return false;
        },
    }
}
fn hcollide_player_with_tiles(p: *Player, tm: *map.Tilemap) bool {
    if (p.x < 0 or p.x > SCREEN_WIDTH) return false;
    if (p.dx == 0) {
        const x_idx: usize = @intCast(@divFloor(p.x, TILE_WIDTH));
        const y_idx: usize = @intCast(@divFloor(p.y + p.h, TILE_HEIGHT));
        if (p.x + p.w >= tm.map[y_idx - 1][x_idx].x and tm.map[y_idx - 1][x_idx].collides) {
            return true;
        } else if (p.x + p.w >= tm.map[y_idx - 1][x_idx + 1].x and tm.map[y_idx - 1][x_idx + 1].collides) {
            return true;
        }
        return false;
    }
    switch (p.dx > 0) {
        true => {
            const x_idx: usize = @intCast(@divFloor(p.x + p.w + p.dx, TILE_WIDTH));
            const y_idx: usize = @intCast(@divFloor(p.y + p.h, TILE_HEIGHT));
            if (p.x + p.w + p.dx >= tm.map[y_idx - 1][x_idx].x and tm.map[y_idx - 1][x_idx].collides) {
                if (p.dx > 0) p.dx = 0;
                return true;
            } else if (p.x + p.w >= tm.map[y_idx - 1][x_idx + 1].x and tm.map[y_idx - 1][x_idx + 1].collides) {
                return true;
            }
            return false;
        },
        false => {
            const x_idx: usize = @intCast(@divFloor(if (p.x + p.dx > 0) p.x + p.dx else p.x, TILE_HEIGHT));
            const y_idx: usize = @intCast(@divFloor(p.y + p.h, TILE_HEIGHT));
            if (p.x + p.dx <= tm.map[y_idx - 1][x_idx].x + tm.map[y_idx - 1][x_idx].w and tm.map[y_idx - 1][x_idx].collides) {
                if (p.dx < 0) p.dx = 0;
                return true;
            } else if (p.x + p.dx <= tm.map[y_idx - 1][x_idx + 1].x + tm.map[y_idx - 1][x_idx + 1].w and tm.map[y_idx - 1][x_idx + 1].collides) {
                return true;
            }
            return false;
        },
    }
}
// END FUNCTIONS

pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) {
        c.SDL_Log("Unable to initialize SDL: {s}\n", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }

    if (c.TTF_Init() < 0) {
        c.SDL_Log("Unable to initialize SDL_TTF: {s}\n", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }

    var window: *c.SDL_Window = c.SDL_CreateWindow("2d-Roguelike", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, SCREEN_WIDTH, SCREEN_HEIGHT, 0) orelse {
        c.SDL_Log("Unable to initialize SDL: {s}\n", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    var renderer: *c.SDL_Renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED) orelse {
        c.SDL_Log("Unable to initialize SDL: {s}\n", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    if (c.Mix_OpenAudio(44100, c.MIX_DEFAULT_FORMAT, 8, 2048) < 0) {
        c.SDL_Log("SDL_mixer could not initialize! SDL_mixer Error: %s\n", c.Mix_GetError());
    }

    var music: ?Music = Music.init("assets/music/8_Bit_Nostalgia.mp3");
    defer if (music != null) music.?.deinit();

    defer c.SDL_Quit();
    defer c.TTF_Quit();
    defer c.SDL_DestroyWindow(window);
    defer c.SDL_DestroyRenderer(renderer);
    defer c.Mix_Quit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    var player_tex: ?*c.SDL_Texture = c.IMG_LoadTexture(renderer, "assets/textures/player.png");
    defer c.SDL_DestroyTexture(player_tex);
    var player = Player{};

    var tmap = try map.Tilemap.init(
        alloc,
        SCREEN_WIDTH,
        SCREEN_HEIGHT,
        TILE_WIDTH,
        TILE_HEIGHT,
        "assets/maps/simple_map.map",
    );

    const floor = c.IMG_LoadTexture(renderer, "assets/textures/floor.png");
    defer c.SDL_DestroyTexture(floor);
    const wall = c.IMG_LoadTexture(renderer, "assets/textures/wall.png");
    defer c.SDL_DestroyTexture(wall);

    var camera = Camera{};

    var frame_start: u32 = undefined;
    var frame_time: u32 = undefined;

    var map_tex_used: ?*c.SDL_Texture = null;
    var map_edit_enabled: bool = false;

    var left_mouse_is_down: bool = false;
    var tile_id_selected: u8 = 0;
    var render_grid = true;

    var debug_view = false;
    var quit = false;

    while (!quit) {
        frame_start = c.SDL_GetTicks();
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
                    'm' => music.?.toggle_pause(),
                    'a' => player.dx = -2,
                    'd' => player.dx = 2,
                    's' => {
                        if (map_edit_enabled) {
                            if (event.key.keysym.mod & c.KMOD_CTRL != 0) {
                                var t = try std.Thread.spawn(.{}, save, .{ &tmap, alloc });
                                t.detach();
                            }
                        }
                    },
                    ' ' => player.dy = -20,
                    'e' => map_edit_enabled = !map_edit_enabled,
                    'g' => render_grid = !render_grid,
                    '0' => tile_id_selected = 0,
                    '1' => tile_id_selected = 1,
                    '2' => tile_id_selected = 2,
                    '3' => tile_id_selected = 3,
                    c.SDLK_F3 => debug_view = !debug_view,
                    else => {},
                },
                c.SDL_KEYUP => switch (event.key.keysym.sym) {
                    'a', 'd' => player.dx = 0,
                    else => {},
                },
                c.SDL_MOUSEBUTTONDOWN => switch (event.button.button) {
                    c.SDL_BUTTON_LEFT => {
                        left_mouse_is_down = true;
                        const x = if (event.button.x + camera.x > 0) @as(u32, @intCast(event.button.x + camera.x)) else 0;
                        const y = if (event.button.y + camera.y > 0) @as(u32, @intCast(event.button.y + camera.y)) else 0;
                        if (map_edit_enabled) place_at_pos(x, y, &tmap, tile_id_selected);
                    },
                    else => {},
                },
                c.SDL_MOUSEBUTTONUP => switch (event.button.button) {
                    c.SDL_BUTTON_LEFT => {
                        left_mouse_is_down = false;
                    },
                    else => {},
                },
                c.SDL_MOUSEMOTION => switch (left_mouse_is_down) {
                    true => {
                        const x = if (event.button.x + camera.x > 0) @as(u32, @intCast(event.button.x + camera.x)) else 0;
                        const y = if (event.button.y + camera.y > 0) @as(u32, @intCast(event.button.y + camera.y)) else 0;
                        if (map_edit_enabled) place_at_pos(x, y, &tmap, tile_id_selected);
                    },
                    false => {},
                },

                else => {},
            }
        }

        set_render_color(renderer, Color.dark_gray);
        _ = c.SDL_RenderClear(renderer);

        direct_cam_toward_player(&player, &camera);

        for (tmap.map) |row| {
            for (row) |tile| {
                const x_to_cam = tile.x - camera.x;
                const y_to_cam = tile.y - camera.y;
                switch (tile.id) {
                    .Wall => {
                        map_tex_used = wall;
                    },
                    .Floor => {
                        map_tex_used = floor;
                    },
                }
                _ = c.SDL_RenderCopy(
                    renderer,
                    map_tex_used,
                    &c.SDL_Rect{
                        .x = 0,
                        .y = 0,
                        .w = 32,
                        .h = 32,
                    },
                    &c.SDL_Rect{
                        .x = @intCast(x_to_cam),
                        .y = @intCast(y_to_cam),
                        .w = tile.w,
                        .h = tile.h,
                    },
                );
                if (debug_view) {
                    set_render_color(renderer, Color.green);
                    _ = c.SDL_RenderDrawRect(
                        renderer,
                        &c.SDL_Rect{
                            .x = @intCast(x_to_cam),
                            .y = @intCast(y_to_cam),
                            .w = tile.w,
                            .h = tile.h,
                        },
                    );
                }
            }
        }

        if (!vcollide_player_with_tiles(&player, &tmap)) {
            if (player.dy < 6) player.dy += 1;
            player.y += player.dy;
        }
        if (!hcollide_player_with_tiles(&player, &tmap)) {
            player.x += player.dx;
        }

        if (player_tex) |tex| {
            _ = c.SDL_RenderCopyEx(
                renderer,
                tex,
                &c.SDL_Rect{
                    .x = 0,
                    .y = 0,
                    .w = 32,
                    .h = 32,
                },
                &c.SDL_Rect{
                    .x = @intCast(player.x - camera.x),
                    .y = @intCast(player.y - camera.y),
                    .w = player.w,
                    .h = player.h,
                },
                0,
                null,
                c.SDL_FLIP_NONE,
            );
            set_render_color(renderer, Color.white);
            if (debug_view) {
                _ = c.SDL_RenderDrawRect(
                    renderer,
                    &c.SDL_Rect{
                        .x = @intCast(player.x - camera.x),
                        .y = @intCast(player.y - camera.y),
                        .w = player.w,
                        .h = player.h,
                    },
                );
            }
        } else {
            set_render_color(renderer, Color.white);
            _ = c.SDL_RenderDrawRect(
                renderer,
                &c.SDL_Rect{
                    .x = @intCast(player.x),
                    .y = @intCast(player.y),
                    .w = player.w,
                    .h = player.h,
                },
            );
        }

        frame_time = c.SDL_GetTicks() - frame_start;
        c.SDL_RenderPresent(renderer);
        if (FRAME_DELAY > frame_time) c.SDL_Delay(FRAME_DELAY - frame_time);
    }
}
