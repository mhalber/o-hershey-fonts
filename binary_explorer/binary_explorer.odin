package binary_explorer

import "core:fmt"
import "core:math"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:mem"

import rl "vendor:raylib"
import utils "../common"

ViewMode :: enum {GLYPH, TEXT}

wrap_int :: proc(x, count: int) -> int {
	out := x % count
	return out + count if out < 0 else out
}

draw_text :: proc (text: string,
                   loc: rl.Vector2,
                   glyphs: ^[dynamic]utils.glyph_info,
                   size: int=18,
                   width: f32 = 1.0) -> f32 {
    font_size_in_pixels := utils.get_font_pixel_size(size)
	scale := cast(f32)font_size_in_pixels / 32.0
	origin := loc
	newline_count := 1
	for c in text {
		newline_count += cast(int)utils.is_line_break(cast(u8)c)
		cur_glyph_idx := cast(u8)c - 32
		if cur_glyph_idx >= 0 && int(cur_glyph_idx) < len(glyphs) {
			glyph := glyphs[cur_glyph_idx]
			px: i8 = utils.INVALID_COORD
			py: i8 = utils.INVALID_COORD
			for i: i16 = 0; i < glyph.coords_count; i += 1 {
				cx := glyph.coords[i * 2]
				cy := glyph.coords[i * 2 + 1]
				if (px != utils.INVALID_COORD && cx != utils.INVALID_COORD) {
					p0 := rl.Vector2{cast(f32)px, cast(f32)py}
					p1 := rl.Vector2{cast(f32)cx, cast(f32)cy}
					rl.DrawLineEx(origin + scale * p0, origin + scale * p1, width, rl.BLACK)
				}
				px = cx
				py = cy
			}
			origin.x += scale * cast(f32)glyph.advance
		}
	}
	return cast(f32)newline_count * scale * 32
}

read_binary_font :: proc(filepath: string, glyphs: ^[dynamic]utils.glyph_info) -> bool {
	data, data_ok := os.read_entire_file(filepath)
	if !data_ok {
		fmt.eprintfln("Failed to read file %s", filepath)
		return false
	}
	// defer delete(data)

	if len(data) < 4 {
		fmt.eprintln("Invalid binary font file: too small")
		return false
	}

	// Read glyph count (first 4 bytes)
	glyph_count := mem.slice_data_cast([]i32, data[0:4])[0]
	fmt.println(glyph_count)

	if glyph_count <= 0 || len(data) < int(4 + 4 * glyph_count) {
		fmt.eprintln("Invalid binary font file: invalid glyph count or file too small")
		return false
	}

	// Read offsets
	offsets := make([]u32, glyph_count)
	defer delete(offsets)

	offset_data := data[4:(4 + 4*glyph_count)]
	for i in 0..<glyph_count {
		offset_idx := i * 4
		offsets[i] = u32(offset_data[offset_idx]) |
		            (u32(offset_data[offset_idx+1]) << 8) |
		            (u32(offset_data[offset_idx+2]) << 16) |
		            (u32(offset_data[offset_idx+3]) << 24)
		fmt.println(i, offset_data[offset_idx:offset_idx+4], offsets[i])
	}
	return true

	// // Parse each glyph
	// for i in 0..<glyph_count {
	// 	if int(offsets[i]) >= len(data) {
	// 		fmt.eprintfln("Invalid offset for glyph %d", i)
	// 		continue
	// 	}

	// 	// Read glyph data starting at offset
	// 	offset := offsets[i]

	// 	// Create a new glyph
	// 	glyph: utils.glyph_info

	// 	// Read advance (1 byte)
	// 	glyph.advance = cast(i8)data[offset]

	// 	// Read coords_count (2 bytes)
	// 	coords_count_bytes := data[offset+1:offset+3]
	// 	glyph.coords_count = i16(coords_count_bytes[0]) | (i16(coords_count_bytes[1]) << 8)

	// 	// Set the glyph index (same as ASCII value - 32)
	// 	glyph.idx = u16(i)

	// 	// Calculate left and right values based on advance
	// 	glyph.left = 0
	// 	glyph.right = glyph.advance

	// 	// Read coordinates
	// 	for j: i16 = 0; j < glyph.coords_count; j += 1 {
	// 		coord_offset := offset + 3 + u32(j * 2)
	// 		if int(coord_offset) + 1 >= len(data) {
	// 			fmt.eprintfln("Invalid coordinate data for glyph %d", i)
	// 			break
	// 		}

	// 		x := cast(i8)data[coord_offset]
	// 		y := cast(i8)data[coord_offset + 1]

	// 		glyph.coords[2 * j] = x
	// 		glyph.coords[2 * j + 1] = y
	// 	}

	// 	append(glyphs, glyph)
	// }

	// return true
}

main :: proc() {
	if len(os.args) != 2 {
		fmt.eprintfln("Usage: %s <binary_font_filename>", filepath.stem(os.args[0]))
		os.exit(1)
	}
	binary_filepath := os.args[1]

	hershey_glyphs: [dynamic]utils.glyph_info = {}

	if !read_binary_font(binary_filepath, &hershey_glyphs) {
		fmt.eprintfln("Failed to parse binary font file: %s", binary_filepath)
		os.exit(1)
	}

	// screen_width, screen_height: i32 = 1024, 1024
	// rl.SetTraceLogLevel(rl.TraceLogLevel.NONE)
	// rl.InitWindow(screen_width, screen_height, "Hershey Font (Binary) Explorer")
	// defer rl.CloseWindow()
	// rl.SetTargetFPS(30)

	// glyph_idx := 0
	// view_mode := ViewMode.GLYPH
	// for !rl.WindowShouldClose() {
	// 	rl.BeginDrawing()
	// 	rl.ClearBackground(rl.RAYWHITE)

	// 	if rl.IsKeyPressed(rl.KeyboardKey.F1) {
	// 	    view_mode = ViewMode.GLYPH if view_mode == ViewMode.TEXT else ViewMode.TEXT
	// 	}

	// 	if view_mode == ViewMode.GLYPH {
	// 		origin := rl.Vector2{cast(f32)(screen_width / 2), cast(f32)(screen_height / 2 + 50)}
	// 		scale: f32 = 1024 / 40

	// 		// Iterate through parsed glyphs
	// 		if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) || rl.IsKeyPressed(rl.KeyboardKey.K) {
	// 			glyph_idx = wrap_int(glyph_idx + 1, len(hershey_glyphs))
	// 		}
	// 		if rl.IsKeyPressed(rl.KeyboardKey.LEFT) || rl.IsKeyPressed(rl.KeyboardKey.J) {
	// 			glyph_idx = wrap_int(glyph_idx - 1, len(hershey_glyphs))
	// 		}

	// 		// Draw glyph
	// 		glyph := hershey_glyphs[glyph_idx]
	// 		px: i8 = utils.INVALID_COORD
	// 		py: i8 = utils.INVALID_COORD
	// 		for i: i16 = 0; i < glyph.coords_count; i += 1 {
	// 			cx := glyph.coords[i * 2]
	// 			cy := glyph.coords[i * 2 + 1]
	// 			if (px != utils.INVALID_COORD && cx != utils.INVALID_COORD) {
	// 				p0 := rl.Vector2{cast(f32)px, cast(f32)py}
	// 				p1 := rl.Vector2{cast(f32)cx, cast(f32)cy}
	// 				rl.DrawLineEx(origin + scale * p0, origin + scale * p1, 4.0, rl.BLACK)
	// 			}
	// 			px = cx
	// 			py = cy
	// 		}

	// 		// Draw info about current glyph
	// 		info_text := fmt.tprintf(
	// 			"Glyph %c [%d out of %d]\nGlyph Idx.: %d\nCoordinate Count: %d\nWidth: %d",
	// 			glyph_idx + 32,
	// 			glyph_idx,
	// 			len(hershey_glyphs),
	// 			glyph.idx,
	// 			glyph.coords_count,
	// 			glyph.advance,
	// 		)
	// 		rl.DrawText(strings.unsafe_string_to_cstring(info_text), 10, 10, 25, rl.GRAY)

	// 		// Draw point grid
	// 		for r: f32 = -15; r <= 15; r += 1 {
	// 			for c: f32 = -15; c <= 15; c += 1 {
	// 				rl.DrawCircleV(origin + scale * rl.Vector2{c, r}, 2.0, rl.GRAY)
	// 			}
	// 		}
	// 		// Draw bbox
	// 		bbox_a := rl.Vector2{-16, -16}
	// 		bbox_b := rl.Vector2{-16, 16}
	// 		bbox_c := rl.Vector2{16, 16}
	// 		bbox_d := rl.Vector2{16, -16}
	// 		rl.DrawLineEx(origin + scale * bbox_a, origin + scale * bbox_b, 1.0, rl.RED)
	// 		rl.DrawLineEx(origin + scale * bbox_b, origin + scale * bbox_c, 1.0, rl.RED)
	// 		rl.DrawLineEx(origin + scale * bbox_c, origin + scale * bbox_d, 1.0, rl.RED)
	// 		rl.DrawLineEx(origin + scale * bbox_d, origin + scale * bbox_a, 1.0, rl.RED)

	// 		// Draw baselines
	// 		baseline_a := rl.Vector2{-16, -utils.BASELINE}
	// 		baseline_b := rl.Vector2{16, -utils.BASELINE}
	// 		rl.DrawLineEx(origin + scale * baseline_a, origin + scale * baseline_b, 1.0, rl.MAROON)

	// 		// Draw left and right verticals
	// 		left_a := rl.Vector2{cast(f32)glyph.left, 16}
	// 		left_b := rl.Vector2{cast(f32)glyph.left, -16}
	// 		rl.DrawLineEx(origin + scale * left_a, origin + scale * left_b, 1.0, rl.MAROON)
	// 		right_a := rl.Vector2{cast(f32)glyph.right, 16}
	// 		right_b := rl.Vector2{cast(f32)glyph.right, -16}
	// 		rl.DrawLineEx(origin + scale * right_a, origin + scale * right_b, 1.0, rl.MAROON)
	// 	} else {
	// 	    // Draw some text
	// 		text := "a quick brown fox jumps over a lazy dog"
	// 		y_offset := draw_text(text, loc=rl.Vector2{20.0, 20.0}, glyphs = &hershey_glyphs, size=14, width=2)
	// 		text = "A QUICK BROWN FOX JUMPS OVER A LAZY DOG"
	// 		y_offset += draw_text(text, loc=rl.Vector2{20.0, 20.0 + y_offset}, glyphs = &hershey_glyphs, size=14, width=2)
	// 		text = "Sphinx of black quartz, judge my vow"
	// 		y_offset += draw_text(text, loc=rl.Vector2{20.0, 20.0 + y_offset}, glyphs = &hershey_glyphs, size=14, width=2)
	// 		text = "0, 1, 2, 3, 4, 5, 6, 7, 8, 9"
	// 		y_offset += draw_text(text, loc=rl.Vector2{20.0, 20.0 + y_offset}, glyphs = &hershey_glyphs, size=14, width=2)
	// 		text = "(2+2)*3=12"
	// 		y_offset += draw_text(text, loc=rl.Vector2{20.0, 20.0 + y_offset}, glyphs = &hershey_glyphs, size=14, width=2)
	// 		text = "{email: lastname.firstname@mailbox.com}"
	// 		y_offset += draw_text(text, loc=rl.Vector2{20.0, 20.0 + y_offset}, glyphs = &hershey_glyphs, size=14, width=2)
	// 		text = "All your bases are now belong to us"
	// 		y_offset += draw_text(text, loc=rl.Vector2{20.0, 20.0 + y_offset}, glyphs = &hershey_glyphs, size=14, width=2)
	// 		text = "All work and no play makes Jack a dull boy"
	// 		y_offset += draw_text(text, loc=rl.Vector2{20.0, 20.0 + y_offset}, glyphs = &hershey_glyphs, size=14, width=2)
	// 	}

	// 	rl.EndDrawing()
	// }
}
