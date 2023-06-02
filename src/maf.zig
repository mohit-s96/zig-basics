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

pub fn parseU64(buf: *const []u8, radix: u8) !f64 {
    var x: u64 = 0;
    var decimalCounter: u64 = 1;
    var parsingFractional: bool = false;
    var sign: f64 = 1;
    for (buf.*) |c| {
        if (parsingFractional) {
            decimalCounter *= 10;
        }
        if (c == '.') {
            if (parsingFractional) {
                return error.InvalidChar;
            }
            parsingFractional = true;
            continue;
        }
        if (c == '-') {
            sign = -1;
            continue;
        }
        const digit = charToDigit(c);

        if (digit >= radix) {
            std.log.debug("Invalid character => {c}\n", .{c});
            return error.InvalidChar;
        }

        var ov = @mulWithOverflow(x, radix);
        if (ov[1] != 0) return error.OverFlow;

        ov = @addWithOverflow(ov[0], digit);
        if (ov[1] != 0) return error.OverFlow;
        x = ov[0];
    }

    var result: f64 = (@intToFloat(f64, x)) * sign;
    var decimalCounterFloat: f64 = @intToFloat(f64, decimalCounter);
    return result / decimalCounterFloat;
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
    var rightOperand: f64 = try parseU64(&operandStack.pop().?, 10);
    var leftOperand: f64 = try parseU64(&operandStack.pop().?, 10);
    var buffer = try allocator.alloc(u8, 64);
    switch (operator[0]) {
        '+' => {
            const sum: f64 = rightOperand + leftOperand;
            const len = std.fmt.bufPrint(buffer, "{d}", .{sum}) catch unreachable;
            operandStack.push(len);
        },
        '-' => {
            const difference: f64 = leftOperand - rightOperand;
            const len = std.fmt.bufPrint(buffer, "{d}", .{difference}) catch unreachable;
            operandStack.push(len);
        },
        '*' => {
            const product: f64 = leftOperand * rightOperand;
            const len = std.fmt.bufPrint(buffer, "{d}", .{product}) catch unreachable;
            operandStack.push(len);
        },
        '/' => {
            const quotient: f64 = leftOperand / rightOperand;
            const len = std.fmt.bufPrint(buffer, "{d}", .{quotient}) catch unreachable;
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
                    if (tokens[i][0] == ' ') {
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
        if (operatorStack.peek() == null) break;
    }

    var r = operandStack.pop().?;
    return r;
}

test "Addition" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    var arrayList = std.ArrayList([]u8).init(allocator);
    var expression = "3 + 4";
    for (expression) |ch| {
        var value = try allocator.alloc(u8, 1);
        value[0] = ch;
        var slice: []u8 = value[0..1];
        try arrayList.append(slice);
    }

    var actual = try eval(&arrayList, allocator);
    var expected: []const u8 = "7";
    try std.testing.expectEqualStrings(expected, actual);
}

test "Subtraction" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    var arrayList = std.ArrayList([]u8).init(allocator);
    var expression = "42111 - 42";
    for (expression) |ch| {
        var value = try allocator.alloc(u8, 1);
        value[0] = ch;
        var slice: []u8 = value[0..1];
        try arrayList.append(slice);
    }

    var actual = try eval(&arrayList, allocator);
    var expected: []const u8 = "42069";
    try std.testing.expectEqualStrings(expected, actual);
}

test "Multiplication" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    var arrayList = std.ArrayList([]u8).init(allocator);
    var expression = "14023 * 3";
    for (expression) |ch| {
        var value = try allocator.alloc(u8, 1);
        value[0] = ch;
        var slice: []u8 = value[0..1];
        try arrayList.append(slice);
    }

    var actual = try eval(&arrayList, allocator);
    var expected: []const u8 = "42069";
    try std.testing.expectEqualStrings(expected, actual);
}

test "Division" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    var arrayList = std.ArrayList([]u8).init(allocator);
    var expression = "126207/3";
    for (expression) |ch| {
        var value = try allocator.alloc(u8, 1);
        value[0] = ch;
        var slice: []u8 = value[0..1];
        try arrayList.append(slice);
    }

    var actual = try eval(&arrayList, allocator);
    var expected: []const u8 = "42069";
    try std.testing.expectEqualStrings(expected, actual);
}

test "Decimal" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    var arrayList = std.ArrayList([]u8).init(allocator);
    var expression = "6*5/4";
    for (expression) |ch| {
        var value = try allocator.alloc(u8, 1);
        value[0] = ch;
        var slice: []u8 = value[0..1];
        try arrayList.append(slice);
    }

    var actual = try eval(&arrayList, allocator);
    var expected: []const u8 = "7.5";
    try std.testing.expectEqualStrings(expected, actual);
}

test "Negative Number" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    var arrayList = std.ArrayList([]u8).init(allocator);
    var expression = "9*4-100.5/2";
    for (expression) |ch| {
        var value = try allocator.alloc(u8, 1);
        value[0] = ch;
        var slice: []u8 = value[0..1];
        try arrayList.append(slice);
    }

    var actual = try eval(&arrayList, allocator);
    var expected: []const u8 = "-14.25";
    try std.testing.expectEqualStrings(expected, actual);
}
