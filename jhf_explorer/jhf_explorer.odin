package jhf_explorer

import "core:fmt"
import "core:math"
import "core:os"
import "core:path/filepath"
import "core:strings"

import rl "vendor:raylib"
import utils "../common"

// Load the font at compile time
binary_glyph_data :: #load("../jhf_files/rowmans.bhf")

ViewMode :: enum {GLYPH, TEXT}

main :: proc() {
	if len(os.args) != 2 {
		fmt.eprintfln("Usage: %s <jhf_filename>", filepath.stem(os.args[0]))
		os.exit(1)
	}
	hershey_filepath := os.args[1]

	data, data_ok := os.read_entire_file(hershey_filepath)
	if !data_ok {
		fmt.eprintfln("Failed to read file %s", hershey_filepath)
		os.exit(1)
	}

	// Read the binary font
	binary_glyphs :[dynamic]utils.glyph_info = {}
	utils.read_binary_font(binary_glyph_data, &binary_glyphs)

	// Read the font from jhf format
	jhf_glyphs: [dynamic]utils.glyph_info = {}
	utils.parse_jhf(jhf_data=data, glyphs = &jhf_glyphs)

	screen_width, screen_height: i32 = 1024, 1024
	rl.SetTraceLogLevel(rl.TraceLogLevel.NONE)
	rl.InitWindow(screen_width, screen_height, "Hershey Font (jhf) Explorer")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	glyph_idx := 0
	view_mode := ViewMode.GLYPH
	text_size := 14
	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)

		if rl.IsKeyPressed(rl.KeyboardKey.F1) {
		    view_mode = ViewMode.GLYPH if view_mode == ViewMode.TEXT else ViewMode.TEXT
		}

		if view_mode == ViewMode.GLYPH {
			origin := rl.Vector2{cast(f32)(screen_width / 2), cast(f32)(screen_height / 2 + 50)}
			scale: f32 = 1024 / 40

			// Iterate through parsed glyphs
			if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) || rl.IsKeyPressed(rl.KeyboardKey.K) {
				glyph_idx = utils.wrap_int(glyph_idx + 1, len(jhf_glyphs))
			}
			if rl.IsKeyPressed(rl.KeyboardKey.LEFT) || rl.IsKeyPressed(rl.KeyboardKey.J) {
				glyph_idx = utils.wrap_int(glyph_idx - 1, len(jhf_glyphs))
			}

			glyph := jhf_glyphs[glyph_idx]

			info_text := fmt.tprintf(
				"Glyph \'%c\' [%d out of %d]\nGlyph Idx.: %d\nCoordinate Count: %d\nWidth: %d",
				glyph_idx + 32,
				glyph_idx,
				len(jhf_glyphs),
				glyph.idx,
				glyph.coords_count,
				glyph.advance,
			)

			utils.draw_text(info_text, loc=rl.Vector2{20.0, 20.0}, glyphs = &jhf_glyphs, size=14, width=2, color=rl.BLACK)
			utils.draw_glyph_box(glyph=glyph, size_x=32, size_y=32, origin=origin, scale=scale, line_color=rl.RED, dot_color=rl.GRAY)
			utils.draw_glyph(glyph=glyph, origin=origin, scale=scale, color=rl.BLACK)


		} else {
    		if rl.IsKeyPressed(rl.KeyboardKey.EQUAL) {
       			text_size += 1
    		}
            if rl.IsKeyPressed(rl.KeyboardKey.MINUS) {
                text_size -= 1
            }
			text := "a quick brown fox jumps over a lazy dog"
    		color := rl.BLACK
			y_offset := utils.draw_text(text, loc=rl.Vector2{20.0, 20.0}, glyphs = &jhf_glyphs, size=text_size, width=2, color=color)
			text = "A QUICK BROWN FOX JUMPS OVER A LAZY DOG"
			y_offset += utils.draw_text(text, loc=rl.Vector2{20.0, 20.0 + y_offset}, glyphs = &jhf_glyphs, size=text_size, width=2, color=color)
			text = "Sphinx of black quartz, judge my vow"
			y_offset += utils.draw_text(text, loc=rl.Vector2{20.0, 20.0 + y_offset}, glyphs = &jhf_glyphs, size=text_size, width=2, color=color)
			text = "0, 1, 2, 3, 4, 5, 6, 7, 8, 9"
			y_offset += utils.draw_text(text, loc=rl.Vector2{20.0, 20.0 + y_offset}, glyphs = &jhf_glyphs, size=text_size, width=2, color=color)
			text = "(2+2)*3=12"
			y_offset += utils.draw_text(text, loc=rl.Vector2{20.0, 20.0 + y_offset}, glyphs = &jhf_glyphs, size=text_size, width=2, color=color)
			text = "{email: lastname.firstname@mailbox.com}"
			y_offset += utils.draw_text(text, loc=rl.Vector2{20.0, 20.0 + y_offset}, glyphs = &jhf_glyphs, size=text_size, width=2, color=color)
			text = "All your bases are now belong to us"
			y_offset += utils.draw_text(text, loc=rl.Vector2{20.0, 20.0 + y_offset}, glyphs = &jhf_glyphs, size=text_size, width=2, color=color)
			text = "All work and no play makes Jack a dull boy"
			y_offset += utils.draw_text(text, loc=rl.Vector2{20.0, 20.0 + y_offset}, glyphs = &jhf_glyphs, size=text_size, width=2, color=color)
		}

		rl.EndDrawing()
	}
}
