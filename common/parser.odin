package common

INVALID_COORD :: min(i8)
BASELINE :: -9

glyph_info :: struct {
	idx:          u16,
	advance:      i8,
	left:         i8,
	right:        i8,
	coords_count: i16,
	coords:       [2 * 512]i8,
}

jhf_parser :: struct {
	data: []u8,
	char_idx: int,
	col_idx: int,
}

advance :: #force_inline proc(parser: ^jhf_parser, amount: int = 1) {
	if is_line_break(parser.data[parser.char_idx]) {
		parser.col_idx = 0
	} else {
		parser.col_idx += amount
	}
	parser.char_idx += amount
}

skip_white_space :: proc (parser: ^jhf_parser) {
	for is_white_space(parser.data[parser.char_idx]) {
		advance(parser)
		if  parser.char_idx >= len(parser.data) do break
	}
}

parse_jhf :: proc(jhf_data: []u8, glyphs: ^[dynamic]glyph_info) {
	parser: jhf_parser = {data=jhf_data, char_idx=0, col_idx = 0}
	for parser.char_idx < len(parser.data) {
		glyph: glyph_info = {}

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
