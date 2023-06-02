const std = @import("std");
const maf = @import("maf.zig");

pub fn main() !void {
    std.debug.print("\n>>> Maf Interpreter [Ctrl + C to exit] <<<\n", .{});
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    while (true) {
        std.debug.print(">> ", .{});
        var maybe_input = try std.io
            .getStdIn()
            .reader()
            .readUntilDelimiterOrEofAlloc(allocator, '\n', std.math.maxInt(usize));
        var arrayList = std.ArrayList([]u8).init(allocator);
        defer arrayList.deinit();
        if (maybe_input) |input| {
            for (input) |ch| {
                var value = try allocator.alloc(u8, 1);
                value[0] = ch;
                var slice: []u8 = value[0..1];
                try arrayList.append(slice);
            }
        }
        var sum = try maf.eval(&arrayList, allocator);
        std.debug.print(">> {s}\n", .{sum});
    }
}
