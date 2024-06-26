package json

import "core:log"
import "core:mem"
import "core:odin/ast"
import "core:odin/parser"
import "core:odin/printer"
import "core:os"
import "core:strings"


JSON_GEN_FILENAME := "gen_json.odin"
main :: proc() {
	context.logger = log.create_console_logger()
	a: mem.Arena
	buf: [1024 * 16]byte
	mem.arena_init(&a, buf[:])
	arena := mem.arena_allocator(&a)

	pr := printer.make_printer(printer.default_style)
	p := parser.Parser{}

	arg := os.args[1]
	source_path := strings.concatenate({"./", arg})

	handle, err := os.open(source_path)
	assert(err == 0)
	defer os.close(handle)

	fi, dir_err := os.read_dir(handle, -1)
	assert(dir_err == 0)

	gen_settings: [dynamic]Gen_Settings
	for file_info in fi {
		if !file_info.is_dir && file_info.name != "gen_json.odin" {
			data := os.read_entire_file(file_info.fullpath) or_else panic("Could not read file")
			ast_file := ast.File {
				src      = string(data),
				fullpath = file_info.fullpath,
			}
			ok := parser.parse_file(&p, &ast_file)

			assert(ok)
			for decl in ast_file.decls {
				// print_tree(decl)

				val, is_v := decl.derived_stmt.(^ast.Value_Decl)
				if is_v && len(val.attributes) > 0 {
					setting, ok := extract_gen_settings(val)
					if ok {
						append(&gen_settings, setting)
					}
				}
			}
		}

	}

	// Fix up enum types
	fixup_enum_types(&gen_settings)
	log.debug(gen_settings)


	pkg, success := parser.parse_package_from_path(source_path, &p)

	gen_file := strings.concatenate({pkg.fullpath, "/", JSON_GEN_FILENAME})
	gen_handle, open_err := os.open(gen_file, os.O_RDWR | os.O_CREATE | os.O_TRUNC, 0o755)

	if open_err != os.ERROR_NONE {
		log.error(open_err)
		panic("could not open gen file")
	}

	header := generate_file_header(JSON_GEN_FILENAME, pkg.name, gen_settings[:])
	os.write(gen_handle, transmute([]u8)header)
	ser_procs := generate_serialization_procs(JSON_GEN_FILENAME, pkg.name, gen_settings[:])
	os.write(gen_handle, transmute([]u8)ser_procs)
	de_procs := generate_deserialization_procs(JSON_GEN_FILENAME, pkg.name, gen_settings[:])
	os.write(gen_handle, transmute([]u8)de_procs)
	helper_procs := generate_helper_procs()
	os.write(gen_handle, transmute([]u8)helper_procs)

	package_location := make(map[string]string)
	defer delete(package_location)
}
