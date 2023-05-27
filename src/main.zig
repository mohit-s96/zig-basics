const std = @import("std");

// could've just been arraylist lol
const Stack = struct {
    buffer: *std.ArrayList([]u8),

    pub fn push(self: *Stack, ch: []u8) void {
        self.buffer.append(ch) catch {};
    }

    pub fn pop(self: *Stack) ?[]u8 {
        if (self.buffer.items.len == 0) {
            return null;
        } else {
            return self.buffer.pop();
        }
    }

    pub fn peek(self: *Stack) ?[]u8 {
        if (self.buffer.items.len == 0) {
            return null;
        } else {
            return self.buffer.getLast();
        }
    }
};

pub fn parseU64(buf: *const []u8, radix: u8) !u64 {
    var x: u64 = 0;

    for (buf.*) |c| {
        const digit = charToDigit(c);

        if (digit >= radix) {
            return error.InvalidChar;
        }

        var ov = @mulWithOverflow(x, radix);
        if (ov[1] != 0) return error.OverFlow;

        ov = @addWithOverflow(ov[0], digit);
        if (ov[1] != 0) return error.OverFlow;
        x = ov[0];
    }

    return x;
}

fn charToDigit(c: u8) u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'A'...'Z' => c - 'A' + 10,
        'a'...'z' => c - 'a' + 10,
        else => std.math.maxInt(u8),
    };
}

pub fn greaterPrecedence(op1: *const []u8, op2: u8, map: std.AutoHashMap(u8, u8)) bool {
    var i = map.get(op1.*[0]) orelse 0;
    var j = map.get(op2) orelse 0;

    return i > j;
}

pub fn evaluate(operatorStack: *Stack, operandStack: *Stack, allocator: std.mem.Allocator) !void {
    var operator = operatorStack.pop().?;
    if (operandStack.peek() == null) return;
    var rightOperand: usize = try parseU64(&operandStack.pop().?, 10);
    var leftOperand: usize = try parseU64(&operandStack.pop().?, 10);
    var buffer = try allocator.alloc(u8, 64);
    switch (operator[0]) {
        '+' => {
            const sum: usize = rightOperand + leftOperand;
            const len = std.fmt.bufPrint(buffer, "{}", .{sum}) catch unreachable;
            operandStack.push(len);
        },
        '-' => {
            const difference: usize = leftOperand - rightOperand;
            const len = std.fmt.bufPrint(buffer, "{}", .{difference}) catch unreachable;
            operandStack.push(len);
        },
        '*' => {
            const product: usize = leftOperand * rightOperand;
            const len = std.fmt.bufPrint(buffer, "{}", .{product}) catch unreachable;
            operandStack.push(len);
        },
        '/' => {
            const quotient: usize = leftOperand / rightOperand;
            const len = std.fmt.bufPrint(buffer, "{}", .{quotient}) catch unreachable;
            operandStack.push(len);
        },
        else => {},
    }
}

pub fn eval(expression: *std.ArrayList([]u8), allocator: std.mem.Allocator) ![]u8 {
    var map = std.AutoHashMap(u8, u8).init(std.heap.page_allocator);
    defer map.deinit();
    try map.put('+', 1);
    try map.put('-', 1);
    try map.put('*', 2);
    try map.put('/', 2);

    var operandList = std.ArrayList([]u8).init(std.heap.c_allocator);
    defer operandList.deinit();
    var operatorList = std.ArrayList([]u8).init(std.heap.c_allocator);
    defer operatorList.deinit();

    var operandStack = Stack{ .buffer = &operandList };
    var operatorStack = Stack{ .buffer = &operatorList };
    var i: u32 = 0;
    const tokens = expression.items;
    while (i < tokens.len) {
        var token = tokens[i][0];

        switch (token) {
            ' ' => {
                i += 1;
            },
            '0'...'9' => {
                var j = i;
                while (i < tokens.len and !map.contains(tokens[i][0])) {
                    if ((tokens[i][0] == ' ')) {
                        break;
                    }
                    i += 1;
                }

                var list = std.ArrayList(u8).init(allocator);
                while (j < i) {
                    try list.append(tokens[j][0]);
                    j += 1;
                }
                var slice: []u8 = list.items[0..];
                operandStack.push(slice);
            },
            '+', '-', '*', '/' => {
                if (operatorStack.peek() != null) {
                    while (greaterPrecedence(&operatorStack.peek().?, token, map)) {
                        try evaluate(&operatorStack, &operandStack, allocator);
                        if (operatorStack.peek() == null) break;
                    }
                }

                operatorStack.push(tokens[i]);
                i += 1;
            },
            else => {
                std.debug.print("{c}", .{token});
                i += 1;
            },
        }
    }
    while (operatorStack.peek() != null) {
        try evaluate(&operatorStack, &operandStack, allocator);
    }

    var r = operandStack.pop().?;
    return r;
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
    var arrayList = std.ArrayList([]u8).init(allocator);
    if (maybe_input) |input| {
        for (input) |ch| {
            var value = try allocator.alloc(u8, 1);
            value[0] = ch;
            var slice: []u8 = value[0..1];
            try arrayList.append(slice);
        }
    }
    var sum = try eval(&arrayList, allocator);
    std.debug.print("{s}\n", .{sum});
}

test "test-stdin-read" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
