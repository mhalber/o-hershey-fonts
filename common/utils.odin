package common

import "core:fmt"
import "core:mem"
import "core:os"
import "core:slice"
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

// Misc
wrap_int :: proc(x, count: int) -> int {
	out := x % count
	return out + count if out < 0 else out
}

pack_u32 :: proc(bytes: []u8) -> u32 {
    assert(len(bytes) == 4)
    return u32(bytes[0]) | (u32(bytes[1]) << 8) | (u32(bytes[2]) << 16) | (u32(bytes[3]) << 24)
}

get_font_pixel_size :: proc(font_size_in_points: int) -> f32 {
    dpi_scale := rl.GetWindowScaleDPI().x // Assuming DPI scale is uniform across x and y axis
    return (dpi_scale * (cast(f32)font_size_in_points * (96.0 / 72.0))) // 72 points per inch squared
}

// Binary format
read_binary_font_from_memory :: proc(data: []u8, glyphs: ^[dynamic]glyph_info) -> bool {
    // First 4 bytes - glyph count
	glyph_count := mem.slice_data_cast([]i32, data[0:4])[0]
	// glyph_count := slice.to_type(data[0:4], i32)
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
	// TODO(maciej): Can I just transmute here??
		offset_idx := i * 4
		offsets[i] = pack_u32(offset_data[offset_idx:offset_idx+4])
	}

	// Parse each glyph
	for i in 0..<glyph_count {
		if int(offsets[i]) >= len(data) {
			fmt.eprintfln("Invalid offset for glyph %d", i)
			continue
		}

		// Build glyph
		offset := offsets[i]
		glyph: glyph_info
		glyph.advance = cast(i8)data[offset]
		coords_count_bytes := data[offset+1:offset+3]
		glyph.coords_count = i16(coords_count_bytes[0]) | (i16(coords_count_bytes[1]) << 8)
		glyph.idx = u16(i)
		glyph.left = -glyph.advance >> 1
		glyph.right = glyph.advance >> 1 + glyph.advance % 2

		fmt.println(i, glyph.coords_count)
		for j: i16 = 0; j < glyph.coords_count; j += 1 {
			coord_offset := offset + 3 + u32(j * 2)
			if int(coord_offset) + 1 >= len(data) {
				fmt.eprintfln("Invalid coordinate data for glyph %d", i)
				break
			}

			x := cast(i8)data[coord_offset]
			y := cast(i8)data[coord_offset + 1]

			glyph.coords[2 * j] = x
			glyph.coords[2 * j + 1] = y
		}

		append(glyphs, glyph)
	}

	return true
}

read_binary_font_from_file :: proc(filepath: string, glyphs: ^[dynamic]glyph_info) -> bool {
	data, data_ok := os.read_entire_file(filepath)
	if !data_ok {
		fmt.eprintfln("Failed to read file %s", filepath)
		return false
	}
	defer delete(data)

	if len(data) < 4 {
		fmt.eprintln("Invalid binary font file: too small")
		return false
	}
	return read_binary_font_from_memory(data, glyphs)
}

read_binary_font :: proc {
    read_binary_font_from_file,
    read_binary_font_from_memory,
}

write_binary_font :: proc (file: os.Handle, glyphs: [dynamic]glyph_info) {
	// Calculate the total size required for the binary file
	// Info - glyph count (4 bytes) + offsets (4 bytes per glyph)
	// Data - For each glyph: advance (1 byte) + coords_count (2 bytes) + coords (coords_count * 2 bytes)
	glyph_count :i32 = cast(i32)len(glyphs)
	info_size := 4 + 4 * glyph_count // 4 bytes for count + 4 bytes per glyph offset

	// Calculate offsets and total size
	offsets := make([]u32, glyph_count)
	current_offset := u32(info_size)
	defer delete(offsets)

	// Size for each glyph: advance (1) + coords_count (2) + coords (coords_count * 2)
	for glyph, i in glyphs {
		offsets[i] = current_offset
		current_offset += u32(3 + glyph.coords_count * 2)
	}

	total_size := current_offset

	// Write the header
	// First 4 bytes: glyph count
	os.write(file, mem.any_to_bytes(glyph_count))

	// Write offsets (4 bytes each)
	for offset, i in offsets {
	    offset_bytes := mem.any_to_bytes(offset)
		os.write(file, offset_bytes)
	}

	// Write the glyph data
	for glyph in glyphs {
		os.write(file, mem.any_to_bytes(glyph.advance))
		os.write(file, mem.any_to_bytes(glyph.coords_count))

		glyph_coords := glyph.coords
		fmt.println(glyph.coords_count)
		// Write coordinates (coords_count * 2 bytes)
		for j in 0..<glyph.coords_count {
			os.write(file, mem.slice_data_cast([]u8, glyph_coords[(2*j):(2*j+1)]))
		}
	}
}
