package common

import "core:fmt"
import rl "vendor:raylib"

// Basic
is_digit :: proc(c: u8) -> bool {
	return '0' <= c && c <= '9'
}

is_white_space :: proc(c: u8) -> bool {
	switch c {
	case '\t', '\n', '\v', '\f', '\r', ' ', 0x85, 0xa0:
		return true
	}
	return false
}

is_line_break :: proc(c: u8) -> bool {
	switch c {
	case '\n', '\v', '\f', '\r', 0x85:
		return true
	}
	return false
}

// Logging helpers
log_if_verbose :: proc(verbose: bool, args: ..any) {
	if verbose do fmt.println(..args)
}

get_font_pixel_size :: proc(font_size_in_points: int) -> f32 {
    dpi_scale := rl.GetWindowScaleDPI().x // Assuming DPI scale is uniform across x and y axis
    return (dpi_scale * (cast(f32)font_size_in_points * (96.0 / 72.0))) // 72 points per inch squared
}
