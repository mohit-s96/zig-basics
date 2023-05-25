const std = @import("std");

// could've just been arraylist lol
const Stack = struct {
    buffer: *std.ArrayList(u8),

    pub fn push(self: *Stack, ch: u8) void {
        self.buffer.append(ch) catch {};
    }

    pub fn pop(self: *Stack) u8 {
        return self.buffer.pop() catch {};
    }

    pub fn peek(self: *Stack) u8 {
        return self.buffer.getLast() catch {};
    }
};

pub fn eval(stack: Stack) usize {
    _ = stack;
    return 42;
}

pub fn main() !void {
    std.debug.print("Hello World {s} {c}", .{ "fmt", '\n' });
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    var maybe_input = try std.io
        .getStdIn()
        .reader()
        .readUntilDelimiterOrEofAlloc(allocator, '\n', std.math.maxInt(usize));
    var arrayList = std.ArrayList(u8).init(allocator);
    var stack = Stack{ .buffer = &arrayList };
    if (maybe_input) |input| {
        for (input) |ch| {
            stack.push(ch);
        }
    }
    var sum = eval(stack);
    std.debug.print("{d}\n", .{sum});
}

test "test-stdin-read" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
