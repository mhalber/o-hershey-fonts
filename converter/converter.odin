package hershey_converter

import parser "../common"
import "core:flags"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:mem"

OutputType :: enum {OdinCode, Binary}

log_if_verbose :: proc(verbose: bool, args: ..any) {
	if verbose do fmt.println(..args)
}

binary_file_write_i32 :: proc(file: os.Handle, value: i32) {
	value_bytes := [4]u8{
		u8(value & 0xFF),
		u8((value >> 8) & 0xFF),
		u8((value >> 16) & 0xFF),
		u8((value >> 24) & 0xFF),
	}
	os.write(file, value_bytes[:])
}

binary_file_write_u32 :: proc(file: os.Handle, value: u32) {
	value_bytes := [4]u8{
		u8(value & 0xFF),
		u8((value >> 8) & 0xFF),
		u8((value >> 16) & 0xFF),
		u8((value >> 24) & 0xFF),
	}
	os.write(file, value_bytes[:])
}

main :: proc() {
	// TODO: maciej - step through this. How does it even work??
	Options :: struct {
		input_font:  os.Handle `args:"pos=0,required,file=r" usage:"Input jhf file."`,
		output_file: os.Handle `args:"pos=1,required,file=cw" usage:"Output file."`,
		output_type: OutputType `usage:"Output type."`,
		verbose:     bool `usage:"Show verbose output."`,
	}

	// Parse command-line arguments
	opts: Options
	style: flags.Parsing_Style = .Unix
	flags.parse_or_exit(&opts, os.args, style)

	// Read the input jhf file
	file_size, size_err := os.file_size(opts.input_font)
	if size_err != nil {
		fmt.eprintln("Failed to get font file size", size_err)
		os.exit(1)
	}
	data := make([]u8, file_size)
	total_read, file_err := os.read(opts.input_font, data)
	if file_err != nil {
		fmt.eprintln("Failed to read data from file", file_err)
		os.exit(1)
	}

	// Parse the jhf data
	hershey_glyphs: [dynamic]parser.glyph_info = {}
	parser.parse_jhf(jhf_data = data, glyphs = &hershey_glyphs)

	if opts.output_type == OutputType.OdinCode {
	    fmt.println("Writing Odin code output")
    	max_coords_count: i16 = -1
    	for glyph in hershey_glyphs {
    		max_coords_count = max(max_coords_count, glyph.coords_count)
    	}
    	fmt.fprintfln(
    		opts.output_file,
    		"line_glyph :: struct {{\n\tadvance: i8,\n\tcoords_count: i8,\n\tcoords: [%d]i8\n}}",
    		2 * max_coords_count,
    	)
    	fmt.fprintf(opts.output_file, "\ncursive_jhf_font:: [%d]line_glyph{{\n", len(hershey_glyphs))
    	for glyph, i in hershey_glyphs {
    		fmt.fprintfln(opts.output_file, "// \"%c\"", i + 32)
    		fmt.fprintf(
    			opts.output_file,
    			"{{advance=%d, coords_count=%d, coords = {{",
    			glyph.advance,
    			glyph.coords_count,
    		)
    		for j in 0 ..< glyph.coords_count {
    			fmt.fprintf(
    				opts.output_file,
    				"%d=%d, %d=%d, ",
    				2 * j,
    				glyph.coords[2 * j],
    				2 * j + 1,
    				glyph.coords[2 * j + 1],
    			)
    		}
    		if glyph.coords_count != max_coords_count {
    			fmt.fprintfln(
    				opts.output_file,
    				"%d..<%d=-1}} }},",
    				2 * glyph.coords_count,
    				2 * max_coords_count,
    			)
    		} else {
    			fmt.fprintln(opts.output_file, "} },")
    		}
    	}
    	fmt.fprintln(opts.output_file, "\n}")
    	log_if_verbose(opts.verbose, "Done")
	} else if opts.output_type == OutputType.Binary {
	    log_if_verbose(opts.verbose, "Writing binary output")
		// Calculate the total size required for the binary file
		// Header: glyph count (4 bytes) + offsets (4 bytes per glyph)
		// Data: For each glyph: advance (1 byte) + coords_count (1 byte) + coords (coords_count * 2 bytes)
		glyph_count := len(hershey_glyphs)
		header_size := 4 + 4 * glyph_count // 4 bytes for count + 4 bytes per glyph offset

		// Calculate offsets and total size
		offsets := make([]u32, glyph_count)
		current_offset := u32(header_size)

		for glyph, i in hershey_glyphs {
			offsets[i] = current_offset
			// Size for this glyph: advance (1) + coords_count (1) + coords (coords_count * 2)
			current_offset += u32(2 + glyph.coords_count * 2)
		}

		total_size := current_offset


		log_if_verbose(opts.verbose, "Binary file structure:")
		log_if_verbose(opts.verbose, "Header size:", header_size, "bytes")
		log_if_verbose(opts.verbose, "Total file size:", total_size, "bytes")

		// Write the header
		// First 4 bytes: glyph count
		count_bytes := [4]u8{
			u8(glyph_count & 0xFF),
			u8((glyph_count >> 8) & 0xFF),
			u8((glyph_count >> 16) & 0xFF),
			u8((glyph_count >> 24) & 0xFF),
		}
		os.write(opts.output_file, count_bytes[:])
		// TODO(maciej): Test which one works correctly, or if both do
		os.write(opts.output_file, mem.any_to_bytes(glyph_count))

		// Write offsets (4 bytes each)
		for offset in offsets {
			offset_bytes := [4]u8{
				u8(offset & 0xFF),
				u8((offset >> 8) & 0xFF),
				u8((offset >> 16) & 0xFF),
				u8((offset >> 24) & 0xFF),
			}
			os.write(opts.output_file, offset_bytes[:])
		}

		// Write the glyph data
		for glyph in hershey_glyphs {
			// Write advance (1 byte)
			advance_byte := [1]u8{u8(glyph.advance)}
			os.write(opts.output_file, advance_byte[:])

			// Write coords_count (1 byte)
			coords_count_byte := [1]u8{u8(glyph.coords_count)}
			os.write(opts.output_file, coords_count_byte[:])

			// Write coordinates (coords_count * 2 bytes)
			for j in 0..<glyph.coords_count {
				x_byte := [1]u8{u8(glyph.coords[2 * j])}
				y_byte := [1]u8{u8(glyph.coords[2 * j + 1])}
				os.write(opts.output_file, x_byte[:])
				os.write(opts.output_file, y_byte[:])
			}
		}

		fmt.println("Binary output completed successfully")
	}
}
