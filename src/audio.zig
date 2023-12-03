const std = @import("std");
const c = @import("c.zig");

pub fn open_audio(sound_frequency: usize, channels: u8, sample_size: usize) void {
    if (c.Mix_OpenAudio(@intCast(sound_frequency), c.MIX_DEFAULT_FORMAT, @intCast(channels), @intCast(sample_size)) < 0) {
        c.SDL_Log("SDL_mixer could not initialize! SDL_mixer Error: %s\n", c.Mix_GetError());
    }
}
pub fn close_audio() void {
    defer c.Mix_Quit();
}
pub const SoundEffect = struct {
    effect: ?*c.Mix_Chunk,
    timestamp: i64,
    is_footstep: bool = false,

    pub fn init(path: []const u8, is_footstep: bool) SoundEffect {
        std.debug.print("\ntrying path: {s}\n", .{path});
        return SoundEffect{
            .effect = load(@ptrCast(path)),
            .timestamp = std.time.milliTimestamp(),
            .is_footstep = is_footstep,
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
        switch (self.is_footstep) {
            true => {
                const new_time = std.time.milliTimestamp();
                if (new_time - 800 >= self.timestamp) {
                    self.timestamp = new_time;
                    _ = c.Mix_PlayChannel(-1, self.effect, 0);
                }
            },
            false => {
                _ = c.Mix_PlayChannel(-1, self.effect, 0);
            },
        }
    }
};
pub const Music = struct {
    music: ?*c.Mix_Music,
    playing: bool = false,
    paused: bool = false,

    pub fn init(path: [*c]const u8) Music {
        return Music{
            .music = load(path),
        };
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
