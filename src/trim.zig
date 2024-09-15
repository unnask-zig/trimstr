const std = @import("std");

const whitespace_bytes = [_]u8{
    // ASCII + UTF-8 supported whitespace
    0x09, // U+0009 horizontal tab
    0x0a, // U+000A line feed
    0x0b, // U+000B vertical tab
    0x0c, // U+000C form feed
    0x0d, // U+000D carriage return
    0x20, // U+0020 space
    0x85, // U+0085 next line
    0xA0, // U+00A0 no-break space

    // UNICODE/UTF-8 multibyte characters marked as whitespace
    0xe1, 0x9a, 0x80, // U+1680 ogham space mark
    0xe2, 0x80, 0x80, // U+2000 en quad
    0xe2, 0x80, 0x81, // U+2001 em quad
    0xe2, 0x80, 0x82, // U+2002 en space
    0xe2, 0x80, 0x83, // U+2003 em space
    0xe2, 0x80, 0x84, // U+2004 three-per-em space
    0xe2, 0x80, 0x85, // U+2005 four-per-em space
    0xe2, 0x80, 0x86, // U+2006 six-per-em space
    0xe2, 0x80, 0x87, // U+2007 figure space
    0xe2, 0x80, 0x88, // U+2008 punctuation space
    0xe2, 0x80, 0x89, // U+2009 thin space
    0xe2, 0x80, 0x8a, // U+200A hair space
    0xe2, 0x80, 0xa8, // U+2028 line separator
    0xe2, 0x80, 0xa9, // U+2029 paragraph separator
    0xe2, 0x80, 0xaf, // U+202F narrow no-break space
    0xe2, 0x81, 0x9f, // U+205F medium mathematical space
    0xe3, 0x80, 0x80, // U+3000 ideographic space

    // Not marked whitespace but may be used or it
    0xe1, 0xa0, 0x8e, // U+180E mongolian vowel separator
    0xe2, 0x80, 0x8b, // U+200B zero width space
    0xe2, 0x80, 0x8c, // U+200C zero width non-joiner
    0xe2, 0x80, 0x8d, // U+200D zero width joiner
    0xe2, 0x81, 0xa0, // U+2060 word joiner
    0xef, 0xbb, 0xbf, // U+FEFF zero width non-breaking space
};

const single_bytes = whitespace_bytes[0..8];
const multi_bytes = whitespace_bytes[8..77];

/// issbspace checks if the passed in byte is a space character.
/// This function supports UTF-8 and ASCII bytes
///
/// Characters that are considered whitespace
/// U+0009 horizontal tab
/// U+000A line feed
/// U+000B vertical tab
/// U+000C form feed
/// U+000D carriage return
/// U+0020 space
/// U+0085 next line
/// U+00A0 no-break space
fn issbspace(byte: u8) bool {
    comptime var i: usize = 0;

    inline while (i < single_bytes.len) : (i += 1) {
        if (byte == single_bytes[i]) {
            return true;
        }
    }

    return false;
}

/// ismbspace checks if the passed in bytes are a space character
/// This functions supports UTF-8.
///
/// UNICODE/UTF-8 multibyte characters marked as whitespace
/// U+1680 ogham space mark
/// U+2000 en quad
/// U+2001 em quad
/// U+2002 en space
/// U+2003 em space
/// U+2004 three-per-em space
/// U+2005 four-per-em space
/// U+2006 six-per-em space
/// U+2007 figure space
/// U+2008 punctuation space
/// U+2009 thin space
/// U+200A hair space
/// U+2028 line separator
/// U+2029 paragraph separator
/// U+202F narrow no-break space
/// U+205F medium mathematical space
/// U+3000 ideographic space
///
/// Not marked whitespace but may be used or it
/// U+180E mongolian vowel separator
/// U+200B zero width space
/// U+200C zero width non-joiner
/// U+200D zero width joiner
/// U+2060 word joiner
/// U+FEFF zero width non-breaking space
fn ismbspace(scalar: []const u8) bool {
    comptime var i: usize = 0;

    inline while (i < multi_bytes.len) : (i += 3) {
        const whitespace = multi_bytes[i..][0..3];
        if (std.mem.eql(u8, scalar, whitespace)) {
            return true;
        }
    }

    return false;
}

/// ltrim removes all single and multibyte whitespace characters at the start
/// of the given string, returning a slice of the given string.
pub fn ltrim(value: []const u8) []const u8 {
    if (value.len == 0) {
        return value;
    }

    var idx: usize = 0;
    while (idx < value.len) {
        // Fortunately, all the UTF-8 multibyte whitespace are all 3 bytes,
        // so we can just look for this one condition, and otherwise check
        // for the single byte
        if (value[idx] & 0xf0 == 0xe0) {
            //probably not an exploitable boundary even with a specially
            //crafted string but there's a small chance of causing a crash.
            //if (value.len - idx - 3 < 0) {
            //    break;
            //}
            if (ismbspace(value[idx..][0..3])) {
                idx += 3;
                continue;
            }
            break;
        } else {
            if (issbspace(value[idx])) {
                idx += 1;
                continue;
            }
            break;
        }
    }

    return value[idx..];
}

/// rtrim removes all single and multibyte whitespace characters at the end
/// of the given string, returning a slice of the given string.
pub fn rtrim(value: []const u8) []const u8 {
    if (value.len == 0) {
        return value;
    }

    var slice = value;

    while (slice.len > 0) {
        //continuation bytes are 0b10xxxxxx, so we should isolate these
        //bits with 0b11000000
        const idx = slice.len - 1;
        if (slice[idx] & 0xc0 == 0x80) {
            //multibyte value
            if (slice.len < 3 or !ismbspace(slice[idx - 2 ..][0..3])) {
                break;
            }
            slice = slice[0 .. idx - 2];
        } else {
            //single byte value
            if (!issbspace(slice[idx])) {
                break;
            }
            slice = slice[0..idx];
        }
    }

    return slice;
}

/// trim removes all single and multibyte whitespace characters from the
/// beginning and end of the given string, returning a slice of the given
/// string.
pub fn trim(value: []const u8) []const u8 {
    return ltrim(rtrim(value));
}

test "basic trim" {
    const str = "   hello world    ";
    const cmp = trim(str);

    try std.testing.expectEqualStrings("hello world", cmp);
}

test "ltrim ascii spaces" {
    const str = "     hello world   ";
    const cmp = ltrim(str);

    try std.testing.expectEqualStrings("hello world   ", cmp);
}

test "ltrim multibyte characters" {
    const str = "             　fr";
    const cmp = ltrim(str);

    try std.testing.expectEqualStrings("fr", cmp);
}

test "ltrim only multibyte characters" {
    const str = "             　";
    const cmp = ltrim(str);

    try std.testing.expectEqualStrings("", cmp);
}

test "ltrim only ascii spaces" {
    const str = "    ";
    const cmp = ltrim(str);

    try std.testing.expectEqualStrings("", cmp);
}

test "ltrim ascii and multibyte spaces" {
    const str = "               　   hello world   ";
    const cmp = ltrim(str);

    try std.testing.expectEqualStrings("hello world   ", cmp);
}

test "rtrim ascii spaces" {
    const str = "    hello world   ";
    const cmp = rtrim(str);

    try std.testing.expectEqualStrings("    hello world", cmp);
}

test "rtrim multibyte characters" {
    const str = "fr             　";
    const cmp = rtrim(str);

    try std.testing.expectEqualStrings("fr", cmp);
}

test "rtrim only multibyte characters" {
    const str = "             　";
    const cmp = rtrim(str);

    try std.testing.expectEqualStrings("", cmp);
}

test "rtrim only ascii spaces" {
    const str = "    ";
    const cmp = rtrim(str);

    try std.testing.expectEqualStrings("", cmp);
}

test "rtrim ascii and multibyte spaces" {
    const str = "    hello world               　 ";
    const cmp = rtrim(str);

    try std.testing.expectEqualStrings("    hello world", cmp);
}
