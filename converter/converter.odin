package hershey_converter

import utils "../common"
import "core:flags"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:mem"

OutputType :: enum {Binary, OdinCode}

main :: proc() {
	Options :: struct {
		input_font:  os.Handle `args:"pos=0,required,file=r" usage:"Input jhf file."`,
		output_filename: string `args:"pos=1,required" usage:"Output fil ename."`,
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
	hershey_glyphs: [dynamic]utils.glyph_info = {}
	utils.parse_jhf(jhf_data = data, glyphs = &hershey_glyphs)
	// Open file for writing
	output_file, file_open_err := os.open(opts.output_filename, os.O_CREATE | os.O_WRONLY | os.O_TRUNC)
	font_name := filepath.short_stem(opts.output_filename)
	if file_open_err != nil {
					fmt.eprintln("Failed to open output file for writing", file_open_err)
					os.exit(1)
	}
	if opts.output_type == OutputType.OdinCode {
    	max_coords_count: i16 = -1
    	for glyph in hershey_glyphs {
    		max_coords_count = max(max_coords_count, glyph.coords_count)
    	}

    	fmt.fprintfln(
    		output_file,
    		"jhf_glyph :: struct {{\n\tadvance: i8,\n\tcoords_count: i16,\n\tcoords: [%d]i8\n}}",
    		2 * max_coords_count,
    	)
    	fmt.fprintf(output_file, "\n%s_font:: [%d]jhf_glyph{{\n", font_name, len(hershey_glyphs))
    	for glyph, i in hershey_glyphs {
    		fmt.fprintfln(output_file, "// \"%c\"", i + 32)
    		fmt.fprintf(
    			output_file,
    			"{{advance=%d, coords_count=%d, coords = {{",
    			glyph.advance,
    			glyph.coords_count,
    		)
    		for j in 0 ..< glyph.coords_count {
    			fmt.fprintf(
    				output_file,
    				"%d=%d, %d=%d, ",
    				2 * j,
    				glyph.coords[2 * j],
    				2 * j + 1,
    				glyph.coords[2 * j + 1],
    			)
    		}
    		if glyph.coords_count != max_coords_count {
    			fmt.fprintfln(
    				output_file,
    				"%d..<%d=%d}} }},",
    				2 * glyph.coords_count,
    				2 * max_coords_count,
                    utils.INVALID_COORD
    			)
    		} else {
    			fmt.fprintln(output_file, "} },")
    		}
    	}
    	fmt.fprintln(output_file, "\n}")
    	utils.log_if_verbose(opts.verbose, "Done")
	} else if opts.output_type == OutputType.Binary {
	    utils.log_if_verbose(opts.verbose, "Writing binary output")
		utils.write_binary_font(file = output_file, glyphs = hershey_glyphs)
		utils.log_if_verbose(opts.verbose, "Done")
	}
}
