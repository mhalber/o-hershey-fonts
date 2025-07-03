package common

import rl "vendor:raylib"
import "core:fmt"

color_count: i32 : 12
colors: [color_count]rl.Color : {
	rl.BLACK,
	rl.BLUE,
	rl.RED,
	rl.GREEN,
	rl.MAROON,
	rl.PURPLE,
	rl.ORANGE,
	rl.MAGENTA,
	rl.BEIGE,
	rl.DARKGRAY,
	rl.DARKGREEN,
	rl.DARKBROWN,
}

draw_text :: proc(
	text: string,
	loc: rl.Vector2,
	glyphs: ^[dynamic]glyph_info,
	size: int = 18,
	width: f32 = 1.0,
	color: rl.Color,
) -> f32 {
	font_size_in_pixels := get_font_pixel_size(size)
	scale := cast(f32)font_size_in_pixels / 32.0
	origin := loc
	newline_count := 1
	for c in text {
		if is_line_break(cast(u8)c) {
			newline_count += 1
			origin.x = loc.x
			origin.y = cast(f32)newline_count * scale * 32
			continue
		}
		cur_glyph_idx := cast(u8)c - 32

		glyph := glyphs[cur_glyph_idx]
		px: i8 = INVALID_COORD
		py: i8 = INVALID_COORD
		for i: i16 = 0; i < glyph.coords_count; i += 1 {
			cx := glyph.coords[i * 2]
			cy := glyph.coords[i * 2 + 1]
			if (px != INVALID_COORD && cx != INVALID_COORD) {
				p0 := rl.Vector2{cast(f32)px, cast(f32)py}
				p1 := rl.Vector2{cast(f32)cx, cast(f32)cy}
				rl.DrawLineEx(origin + scale * p0, origin + scale * p1, width, color)
			}
			px = cx
			py = cy
		}
		origin.x += scale * cast(f32)glyph.advance
	}
	return cast(f32)newline_count * scale * 32
}

draw_glyph :: proc(glyph: glyph_info, origin: rl.Vector2, scale: f32, colorize_segments: bool) {
	px: i8 = INVALID_COORD
	py: i8 = INVALID_COORD
	color_idx: i32 = 0
	colors_cpy := colors
	for i: i16 = 0; i < glyph.coords_count; i += 1 {
		cx := glyph.coords[i * 2]
		cy := glyph.coords[i * 2 + 1]
		if (px != INVALID_COORD && cx != INVALID_COORD) {
			p0 := rl.Vector2{cast(f32)(px + glyph.left), cast(f32)(py + BASELINE)}
			p1 := rl.Vector2{cast(f32)(cx + glyph.left), cast(f32)(cy + BASELINE)}
			rl.DrawLineEx(origin + scale * p0, origin + scale * p1, 4.0, colors_cpy[color_idx])
		}
		if colorize_segments && cx == INVALID_COORD {
			color_idx = (color_idx + 1) % color_count
		}
		px = cx
		py = cy
	}
}

draw_glyph_box :: proc(
	glyph: glyph_info,
	size_x, size_y: i32,
	origin: rl.Vector2,
	scale: f32,
	line_color: rl.Color,
	dot_color: rl.Color,
	line_width: f32 = 2.0,
	dot_size: f32 = 2.0,
) {
	hsx := cast(f32)(size_x >> 1)
	hsy := cast(f32)(size_y >> 1)

	// Draw box itself
	bbox_a := rl.Vector2{-hsx, -hsy}
	bbox_b := rl.Vector2{-hsx, hsy}
	bbox_c := rl.Vector2{hsx, hsy}
	bbox_d := rl.Vector2{hsx, -hsy}
	rl.DrawLineEx(origin + scale * bbox_a, origin + scale * bbox_b, line_width, line_color)
	rl.DrawLineEx(origin + scale * bbox_b, origin + scale * bbox_c, line_width, line_color)
	rl.DrawLineEx(origin + scale * bbox_c, origin + scale * bbox_d, line_width, line_color)
	rl.DrawLineEx(origin + scale * bbox_d, origin + scale * bbox_a, line_width, line_color)

	// Draw baselines
	baseline_a := rl.Vector2{-16, -BASELINE}
	baseline_b := rl.Vector2{16, -BASELINE}
	rl.DrawLineEx(origin + scale * baseline_a, origin + scale * baseline_b, line_width, line_color)

	// Draw left and right verticals
	left_a := rl.Vector2{cast(f32)glyph.left, 16}
	left_b := rl.Vector2{cast(f32)glyph.left, -16}
	rl.DrawLineEx(origin + scale * left_a, origin + scale * left_b, line_width, line_color)

	right_a := rl.Vector2{cast(f32)glyph.right, 16}
	right_b := rl.Vector2{cast(f32)glyph.right, -16}
	rl.DrawLineEx(origin + scale * right_a, origin + scale * right_b, line_width, line_color)

	// Draw grid
	for r: f32 = -hsy; r <= hsy; r += 1 {
		for c: f32 = -hsx; c <= hsx; c += 1 {
			rl.DrawCircleV(origin + scale * rl.Vector2{c, r}, dot_size, dot_color)
		}
	}
}
