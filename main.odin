package hershey_explorer

import "core:fmt"
import "core:math"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:unicode"

import rl "vendor:raylib"


// TODO: extract functions for string drawing. Figure out how

INVALID_COORD :: -127
BASELINE :: -9

wrap_int :: proc(x, count: int) -> int {
	out := x % count
	return out + count if out < 0 else out
}

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


hershey_glyph_info :: struct {
	idx:          u16,
	advance:      i8,
	left:         i8,
	right:        i8,
	coords_count: i16,
	coords:       [2 * 512]i8,
}

hershey_jhf_parser :: struct {
	data: []u8,
	char_idx: int,
	col_idx: int,
}

advance :: #force_inline proc(parser: ^hershey_jhf_parser, amount: int = 1) {
	if is_line_break(parser.data[parser.char_idx]) {
		parser.col_idx = 0
	} else {
		parser.col_idx += amount
	}
	parser.char_idx += amount
}

skip_white_space :: proc (parser: ^hershey_jhf_parser) {
	for is_white_space(parser.data[parser.char_idx]) {
		advance(parser)
		if  parser.char_idx >= len(parser.data) do break
	}
}

parse_jhf :: proc(jhf_data: []u8, glyphs: ^[dynamic]hershey_glyph_info) {
	parser: hershey_jhf_parser = {data=jhf_data, char_idx=0, col_idx = 0}
	for parser.char_idx < len(parser.data) {
		glyph: hershey_glyph_info = {}

		// Possibly a new glyph, see if we need to break and skip_whitespace
		if parser.char_idx >= len(parser.data) do break
		skip_white_space(&parser)
		if parser.char_idx >= len(parser.data) do break

		// grab glyph number
		glyph.idx = 0
		for parser.col_idx < 5 && is_digit(parser.data[parser.char_idx]) {
			glyph.idx *= 10
			glyph.idx += cast(u16)(parser.data[parser.char_idx] - cast(u8)('0'))
			advance(&parser)
		}

		// grab coordinate count
		glyph.coords_count = 0
		skip_white_space(&parser)
		for parser.col_idx < 8 && is_digit(parser.data[parser.char_idx]) {
			glyph.coords_count *= 10
			glyph.coords_count += cast(i16)(parser.data[parser.char_idx] - '0')
			advance(&parser)
		}

		// Coordinates include the advance, so we will decrease this by 1
		glyph.coords_count -= 1

		skip_white_space(&parser) // Likely unnecessary

		// Parse width / advance(?)
		glyph.left = cast(i8)parser.data[parser.char_idx] - cast(i8)'R'
		advance(&parser)
		glyph.right = cast(i8)parser.data[parser.char_idx] - cast(i8)'R'
		advance(&parser)
		glyph.advance = glyph.right - glyph.left

		for p: i16 = 0; p < glyph.coords_count; p += 1 {
			if parser.data[parser.char_idx] == ' ' {
				// Skip space and R - the pen up coordinate
				glyph.coords[2 * p + 0] = INVALID_COORD
				glyph.coords[2 * p + 1] = INVALID_COORD
				advance(&parser, 2)
				if p != glyph.coords_count - 1 && is_line_break(parser.data[parser.char_idx]) {
					advance(&parser)
				}
				continue
			}

			x := cast(i8)(parser.data[parser.char_idx] - 'R')
			advance(&parser)
			y := cast(i8)(parser.data[parser.char_idx] - 'R')
			advance(&parser)
			glyph.coords[2 * p + 0] = x - glyph.left
			glyph.coords[2 * p + 1] = y - BASELINE

			if p != glyph.coords_count - 1 && is_line_break(parser.data[parser.char_idx]){
				advance(&parser)
			}
		}
		append(glyphs, glyph)
	}
}

main :: proc() {
	fmt.println("Hello, World!")

	if len(os.args) != 2 {
		fmt.eprintfln("Usage: %s <ply_filename>", filepath.stem(os.args[0]))
		os.exit(1)
	}
	hershey_filepath := os.args[1]

	data, data_ok := os.read_entire_file(hershey_filepath)
	if !data_ok {
		fmt.eprintfln("Failed to read file %s", hershey_filepath)
		os.exit(1)
	}

	// Ok so it seems like we need some state that keeps track of cursor and column position
	// function like advance will move col and cursor. We also probably dont want to use the unicode package, just write out own functions
	col := 0
	hershey_glyphs: [dynamic]hershey_glyph_info = {}
	parsed_glyphs_count := 0
	for c := 0; c < len(data); {
		glyph: hershey_glyph_info = {}

		//skip_whitespace
		if c >= len(data) do break
		for unicode.is_white_space(cast(rune)(data[c])) {
			if data[c] == '\r' || data[c] == '\n' {
				col = 0
			} else {
				col += 1
			}
			c += 1
			if c >= len(data) do break
		}
		if c >= len(data) do break

		// grab glyph number
		glyph.idx = 0
		for (col < 5 && unicode.is_digit(cast(rune)(data[c]))) {
			glyph.idx *= 10
			glyph.idx += cast(u16)(data[c] - cast(u8)('0'))
			col += 1
			c += 1
		}

		//skip_whitespace
		for unicode.is_white_space(cast(rune)(data[c])) {
			c += 1
			col += 1
		}

		// graph coordinate count
		glyph.coords_count = 0
		for (col < 8 && unicode.is_digit(cast(rune)(data[c]))) {
			glyph.coords_count *= 10
			glyph.coords_count += cast(i16)(data[c] - '0')
			col += 1
			c += 1
		}
		// Coordinates include the advance, so we will decrease this by 1
		glyph.coords_count -= 1

		//skip_whitespace
		for unicode.is_white_space(cast(rune)(data[c])) {
			c += 1
			col += 1
		}

		// Parse width / advance(?)
		glyph.left = cast(i8)data[c] - cast(i8)'R'
		if glyph.idx == 3010 do fmt.printfln("%d %c", data[c], data[c])
		c += 1
		col += 1
		glyph.right = cast(i8)data[c] - cast(i8)'R'
		if glyph.idx == 3010 do fmt.printfln("%d %c", data[c], data[c])
		c += 1
		col += 1
		glyph.advance = glyph.right - glyph.left


		for p: i16 = 0; p < glyph.coords_count; p += 1 {
			if data[c] == ' ' {
				// Skip space and R
				glyph.coords[2 * p + 0] = INVALID_COORD
				glyph.coords[2 * p + 1] = INVALID_COORD
				c += 2
				col += 2
				if p != glyph.coords_count - 1 && (data[c] == '\r' || data[c] == '\n') {
					c += 1
				}
				continue
			}

			x := cast(i8)data[c] - cast(i8)'R'
			c += 1
			col += 1
			y := cast(i8)data[c] - cast(i8)'R'
			c += 1
			col += 1
			glyph.coords[2 * p + 0] = x - glyph.left
			glyph.coords[2 * p + 1] = y - BASELINE

			if p != glyph.coords_count - 1 && (data[c] == '\r' || data[c] == '\n') {
				c += 1
			}
		}
		append(&hershey_glyphs, glyph)
		parsed_glyphs_count += 1
	}
	fmt.println("Parsed glyphs", parsed_glyphs_count, len(hershey_glyphs))

	hershey_glyphs2: [dynamic]hershey_glyph_info = {}
	parse_jhf(jhf_data=data, glyphs = &hershey_glyphs2)
	fmt.println("Parsed glyphs2:", len(hershey_glyphs2))
	


	screen_width, screen_height: i32 = 1024, 1024
	rl.SetTraceLogLevel(rl.TraceLogLevel.NONE)
	rl.InitWindow(screen_width, screen_height, "Hershey Font Explorer")
	defer rl.CloseWindow()
	rl.SetTargetFPS(30)

	glyph_idx := 0
	mode := false
	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)

		if rl.IsKeyPressed(rl.KeyboardKey.F1) {
			mode = !mode
		}

		if !mode {
			origin := rl.Vector2{cast(f32)(screen_width / 2), cast(f32)(screen_height / 2 + 50)}
			scale: f32 = 1024 / 40

			// Iterate through parsed glyphs
			if rl.IsKeyPressed(rl.KeyboardKey.J) {
				glyph_idx = wrap_int(glyph_idx + 1, len(hershey_glyphs2))
			}
			if rl.IsKeyPressed(rl.KeyboardKey.K) {
				glyph_idx = wrap_int(glyph_idx - 1, len(hershey_glyphs2))
			}

			// Draw glyph
			glyph := hershey_glyphs2[glyph_idx]
			px: i8 = INVALID_COORD
			py: i8 = INVALID_COORD
			for i: i16 = 0; i < glyph.coords_count; i += 1 {
				cx := glyph.coords[i * 2]
				cy := glyph.coords[i * 2 + 1]
				if (px != INVALID_COORD && cx != INVALID_COORD) {
					p0 := rl.Vector2{cast(f32)(px + glyph.left), cast(f32)(py + BASELINE)}
					p1 := rl.Vector2{cast(f32)(cx + glyph.left), cast(f32)(cy + BASELINE)}
					rl.DrawLineEx(origin + scale * p0, origin + scale * p1, 4.0, rl.BLACK)
				}
				px = cx
				py = cy
			}

			// Draw info about current glyph
			info_text := fmt.tprintf(
				"Glyph %c [%d out of %d]\nGlyph Idx.: %d\nCoordinate Count: %d\nWidth: %d",
				glyph_idx + 32,
				glyph_idx,
				len(hershey_glyphs),
				glyph.idx,
				glyph.coords_count,
				glyph.advance,
			)
			rl.DrawText(strings.unsafe_string_to_cstring(info_text), 10, 10, 25, rl.GRAY)

			// Draw point grid
			for r: f32 = -15; r <= 15; r += 1 {
				for c: f32 = -15; c <= 15; c += 1 {
					rl.DrawCircleV(origin + scale * rl.Vector2{c, r}, 2.0, rl.GRAY)
				}
			}
			// Draw bbox
			bbox_a := rl.Vector2{-16, -16}
			bbox_b := rl.Vector2{-16, 16}
			bbox_c := rl.Vector2{16, 16}
			bbox_d := rl.Vector2{16, -16}
			rl.DrawLineEx(origin + scale * bbox_a, origin + scale * bbox_b, 1.0, rl.RED)
			rl.DrawLineEx(origin + scale * bbox_b, origin + scale * bbox_c, 1.0, rl.RED)
			rl.DrawLineEx(origin + scale * bbox_c, origin + scale * bbox_d, 1.0, rl.RED)
			rl.DrawLineEx(origin + scale * bbox_d, origin + scale * bbox_a, 1.0, rl.RED)
			baseline_a := rl.Vector2{-16, 9}
			baseline_b := rl.Vector2{16, 9}
			rl.DrawLineEx(origin + scale * baseline_a, origin + scale * baseline_b, 1.0, rl.MAROON)
			left_a := rl.Vector2{cast(f32)glyph.left, 16}
			left_b := rl.Vector2{cast(f32)glyph.left, -16}
			rl.DrawLineEx(origin + scale * left_a, origin + scale * left_b, 1.0, rl.MAROON)
			right_a := rl.Vector2{cast(f32)glyph.right, 16}
			right_b := rl.Vector2{cast(f32)glyph.right, -16}
			rl.DrawLineEx(origin + scale * right_a, origin + scale * right_b, 1.0, rl.MAROON)
		} else {
			string := "a quick brown fox jumps over a lazy dog"
			origin := rl.Vector2{20, 20}
			for c in string {
				cur_glyph_idx := cast(i8)c - 32
				cur_glyph := hershey_glyphs[cur_glyph_idx]

				glyph := hershey_glyphs[cur_glyph_idx]
				px: i8 = INVALID_COORD
				py: i8 = INVALID_COORD
				for i: i16 = 0; i < glyph.coords_count; i += 1 {
					cx := glyph.coords[i * 2]
					cy := glyph.coords[i * 2 + 1]
					if (px != INVALID_COORD && cx != INVALID_COORD) {
						p0 := rl.Vector2{cast(f32)px, cast(f32)py}
						p1 := rl.Vector2{cast(f32)cx, cast(f32)cy}
						rl.DrawLineEx(origin + p0, origin + p1, 1.0, rl.BLACK)
					}
					px = cx
					py = cy
				}
				origin.x += cast(f32)cur_glyph.advance
			}
			string = "A QUICK BROWN FOX JUMPS OVER A LAZY DOG"
			origin = rl.Vector2{20, 52}
			for c in string {
				cur_glyph_idx := cast(i8)c - 32
				cur_glyph := hershey_glyphs[cur_glyph_idx]

				glyph := hershey_glyphs[cur_glyph_idx]
				px: i8 = INVALID_COORD
				py: i8 = INVALID_COORD
				for i: i16 = 0; i < glyph.coords_count; i += 1 {
					cx := glyph.coords[i * 2]
					cy := glyph.coords[i * 2 + 1]
					if (px != INVALID_COORD && cx != INVALID_COORD) {
						p0 := rl.Vector2{cast(f32)px, cast(f32)py}
						p1 := rl.Vector2{cast(f32)cx, cast(f32)cy}
						rl.DrawLineEx(origin + p0, origin + p1, 2.0, rl.BLACK)
					}
					px = cx
					py = cy
				}
				origin.x += cast(f32)cur_glyph.advance
			}
		}

		rl.EndDrawing()
	}
}
