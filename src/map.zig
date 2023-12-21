const c = @import("c.zig");
const main = @import("main.zig");
const std = @import("std");

const Allocator = std.mem.Allocator;

pub const TileID = enum(u8) {
    Wall,
    Floor,
    SpawnPoint,
    BluePortal,
    FloorSurface,
    FinishLine,
};

pub const Portal = struct {
    id: TileID,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    link: ?*Portal, // idea is same id == linked, no link = no tp
};

pub const Tilemap = struct {
    pub const Tile = struct {
        id: TileID,
        x: i32,
        y: i32,
        w: i32,
        h: i32,
        collides: bool,

        pub fn init(id: u8, x: i32, y: i32, w: i32, h: i32) Tile {
            std.debug.print("id: {d}, x: {d}, y: {d}\n", .{ id, x, y });
            return Tile{
                .id = @enumFromInt(id),
                .x = x,
                .y = y,
                .w = w,
                .h = h,
                .collides = switch (@as(TileID, @enumFromInt(id))) {
                    .Floor => true,
                    .Wall => false,
                    .SpawnPoint => false,
                    .BluePortal => true,
                    .FloorSurface => true,
                    .FinishLine => true,
                },
            };
        }
        pub fn update_id(self: *Tile, id: TileID) void {
            self.id = id;
            self.collides = switch (id) {
                .Floor => true,
                .Wall => false,
                .SpawnPoint => false,
                .BluePortal => true,
                .FloorSurface => true,
                .FinishLine => true,
            };
        }
    };
    map: [][]Tile,
    portals: []Portal,
    cur: []const u8,

    pub fn init(allocator: Allocator, w: u32, h: u32, tile_w: i32, tile_h: i32, path: []const u8) !Tilemap {
        const tiles_across = w / @as(u32, @intCast(tile_w));
        const tiles_down = h / @as(u32, @intCast(tile_h));
        var map: [][]Tile = undefined;
        if (path.len < 1) {
            map = try build_map(allocator, @intCast(tiles_across), @intCast(tiles_down), tile_w, tile_h);
        } else {
            map = read_from_file(allocator, path, tile_w, tile_h) catch try build_map(allocator, @intCast(tiles_across), @intCast(tiles_down), tile_w, tile_h);
        }

        var portals = std.ArrayList(Portal).init(allocator);
        for (map) |row| {
            for (row) |tile| {
                if (tile.id == .BluePortal) {
                    if (portals.items.len == 0) {
                        try portals.append(Portal{
                            .id = tile.id,
                            .x = tile.x,
                            .y = tile.y,
                            .w = tile.w,
                            .h = tile.h,
                            .link = null,
                        });
                    } else {
                        try portals.append(Portal{
                            .id = tile.id,
                            .x = tile.x,
                            .y = tile.y,
                            .w = tile.w,
                            .h = tile.h,
                            .link = &portals.items[0],
                        });
                        portals.items[0].link = &portals.items[1];
                    }
                }
            }
        }

        return Tilemap{
            .map = map,
            .cur = path,
            .portals = try portals.toOwnedSlice(),
        };
    }

    fn build_map(allocator: Allocator, tiles_down: i32, tiles_across: usize, tile_w: i32, tile_h: i32) ![][]Tile {
        var tmp = std.ArrayList([]Tile).init(allocator);

        for (0..@intCast(tiles_across)) |y| {
            var row = std.ArrayList(Tile).init(allocator);
            for (0..@intCast(tiles_down)) |x| {
                const xpos = @as(i32, @intCast(x)) * tile_w;
                const ypos = @as(i32, @intCast(y)) * tile_h;
                try row.append(Tile.init(0, xpos, ypos, tile_w, tile_h));
            }
            try tmp.append(try row.toOwnedSlice());
        }
        return try tmp.toOwnedSlice();
    }

    //*****************************************//
    //                                         //
    //              *** TODO ***               //
    //                                         //
    //  look into using bufstream and reading  //
    //  in int values from the file, instead   //
    //  of current, naïve u8 mem split method  //
    //                                         //
    //*****************************************//

    fn read_from_file(allocator: Allocator, path: []const u8, tile_w: i32, tile_h: i32) ![][]Tile {
        var map = std.ArrayList([]Tile).init(allocator);
        const file = try std.fs.cwd().openFile(path, .{});
        const buf = try allocator.alloc(u8, 80000);
        _ = try file.reader().readAll(buf);
        defer allocator.free(buf);

        var y: i32 = 0;
        var iter_lines = std.mem.split(u8, buf, "\n");
        while (iter_lines.next()) |line| {
            var x: i32 = 0;
            var row = std.ArrayList(Tile).init(allocator);

            var iter_elems = std.mem.split(u8, line, " ");
            while (iter_elems.next()) |elem| {
                if (elem.len > 0) {
                    if (elem[0] > 47 and elem[0] < 58) {
                        try row.append(Tile.init(elem[0] - 48, x * tile_w, y * tile_h, tile_w, tile_h));
                        x += 1;
                    }
                }
            }
            if (row.items.len > 10) {
                try map.append(try row.toOwnedSlice());
                y += 1;
            } else {
                row.clearAndFree();
            }
        }

        return map.toOwnedSlice();
    }

    fn export_to_file(self: *Tilemap, allocator: Allocator, file_out: []const u8) !void {
        var file = std.fs.cwd().openFile(
            file_out,
            .{ .mode = std.fs.File.OpenMode.write_only },
        ) catch try std.fs.cwd().createFile(file_out, .{});
        defer file.close();
        for (self.map) |row| {
            for (row) |tile| {
                _ = try file.write(try std.fmt.allocPrint(allocator, "{d} ", .{@intFromEnum(tile.id)}));
            }
            _ = try file.write("\n");
        }
        const stdout = std.io.getStdOut().writer();
        try stdout.print("File export completed\n", .{});
    }

    pub fn save(self: *Tilemap, allocator: Allocator) !void {
        try export_to_file(self, allocator, self.cur);
    }

    pub fn edit_tile(self: *Tilemap, id: TileID, x: u32, y: u32) void {
        if (y >= self.map.len or x >= self.map[0].len) return;
        self.map[y][x].update_id(id);
    }
};
