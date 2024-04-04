package json


import "core:fmt"
import "core:io"
import "core:log"
import "core:mem"
import "core:odin/ast"
import "core:odin/format"
import "core:odin/parser"
import "core:odin/printer"
import "core:os"
import "core:reflect"
import "core:strconv"
import "core:strings"
import "core:time"

// create map of package to folder path
// traverse each file per package and get @json types
//  // if a @json has non primitive types, simply call the to_json proc of it, from the right package

MARSHAL_GEN_FILENAME := "gen_json.odin"


@(thread_local)
sb: strings.Builder

import "core:c"

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

	marshal_settings: [dynamic]Marshal_Settings
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
					setting, ok := extract_marshal_settings(val)
					append(&marshal_settings, setting)
				}
			}
		}
	}

	// Fix up enum types


	pkg, success := parser.parse_package_from_path(source_path, &p)

	gen_file := strings.concatenate({pkg.fullpath, "/", MARSHAL_GEN_FILENAME})
	gen_handle, open_err := os.open(gen_file, os.O_RDWR | os.O_CREATE | os.O_TRUNC, 0o755)

	if open_err != os.ERROR_NONE {
		log.error(open_err)
		panic("could not open gen file")
	}

	to_write := generate_marshal_procs(MARSHAL_GEN_FILENAME, pkg.name, marshal_settings[:])
	os.write(gen_handle, transmute([]u8)to_write)

	package_location := make(map[string]string)
	defer delete(package_location)
}

write_indented :: proc(sb: ^strings.Builder, str: string, ident: int) {
	for _ in 0 ..< ident {
		strings.write_string(sb, "	")
	}
	strings.write_string(sb, str)
}

write_string_builder_start :: proc(sb: ^strings.Builder, ident: int) {
	write_indented(sb, "write_string(sb, ", ident)
}

write_given_builder_start :: proc(sb: ^strings.Builder, builder_t: string, field_name: string, ident: int) {
	using strings
	write_indented(sb, "write_", ident)
	write_string(sb, builder_t)
	write_string(sb, "(sb, ")
}

write_field_access :: proc(sb: ^strings.Builder, type_name: string, field: Field) {
	using strings
	if field.is_slice {
		write_string(sb, "ele")
	} else {
		write_field_access_by_name(sb, type_name, field)
	}
}

write_field_access_by_name :: proc(sb: ^strings.Builder, type_name: string, field: Field) {
	using strings
	write_string(sb, to_lower(type_name))
	write_string(sb, ".")
	write_string(sb, field.name)
}

write_field_value :: proc(sb: ^strings.Builder, field: Field, type_name: string) {
	log.debug(field)
	using strings
	switch field.type {
	case "string":
		if !field.from_enum {
			write_given_builder_start(sb, "quoted_string", type_name, 1)
			write_field_access(sb, type_name, field)
		}
	case "cstring":
		write_given_builder_start(sb, "quoted_string", type_name, 1)
		write_string(sb, "string(")
		write_field_access(sb, type_name, field)
		write_string(sb, ")")
	case "rune":
		if field.is_slice {
			write_string_builder_start(sb, 1)
			write_string(sb, "ele")
		} else {
			write_string_builder_start(sb, 1)
			write_string(sb, "\"\\\"\")\n")
			write_given_builder_start(sb, "rune", type_name, 1)
			write_field_access_by_name(sb, type_name, field)
			write_string(sb, ")\n")
			write_string_builder_start(sb, 1)
			write_string(sb, "\"\\\"\"")
		}
	case "bool":
		write_string_builder_start(sb, 1)
		write_field_access(sb, type_name, field)
		write_string(sb, " ? \"true\" : \"false\"")
	case "uint", "u64", "u32", "u16", "u8":
		write_given_builder_start(sb, "u64", type_name, 1)
		write_string(sb, "u64(")
		write_field_access(sb, type_name, field)
		write_string(sb, ")")
	case "int", "i64", "i32", "i16", "i8":
		write_given_builder_start(sb, "i64", type_name, 1)
		write_string(sb, "i64(")
		write_field_access(sb, type_name, field)
		write_string(sb, ")")
	case "f64", "f32", "f16":
		write_given_builder_start(sb, "f64", type_name, 1)
		write_string(sb, "f64(")
		write_field_access(sb, type_name, field)
		write_string(sb, "), 'f'")
	case:
		log.warn(field)
		log.warn("Unknown type:", field.type, "<- might be recursive, otherwise unsupported.")
		write_indented(sb, to_lower(field.type), 1)
		if field.from_enum {
			write_string(sb, "_to_json(")
		} else {
			write_string(sb, "_to_json(&")
		}
		write_string(sb, to_lower(type_name))
		write_string(sb, ".")
		write_string(sb, field.name)
		write_string(sb, ", sb")
	}
	write_string(sb, ")\n")
}

generate_marshal_procs :: proc(file_name: string, pkg: string, settings: []Marshal_Settings) -> string {
	using strings
	sb := builder_make()
	write_string(&sb, "package ")
	write_string(&sb, pkg)
	write_string(&sb, "\n\n")
	write_string(&sb, "// This file is auto generated through json-odin\n")
	write_string(&sb, "// For more information, visit: https://github.com/FreerGit/json-odin\n\n")
	write_string(&sb, "import \"core:strings\"\n\n")
	for setting in settings {
		write_string(&sb, to_lower(setting.name))
		write_string(&sb, "_to_json :: proc(")
		write_string(&sb, to_lower(setting.name))
		write_string(&sb, ": ")
		if setting.type == .Struct {
			write_string(&sb, "^")
		}
		write_string(&sb, setting.name)
		write_string(&sb, ", sb: ^strings.Builder) #no_bounds_check {\n")
		write_indented(&sb, "using strings\n", 1)
		if setting.type == .Enum {
			write_indented(&sb, "switch ", 1)
			write_string(&sb, to_lower(setting.name))
			write_string(&sb, " {\n")
		}
		for &field, i in setting.fields {
			switch setting.type {
			case .Enum:
				write_indented(&sb, "case .", 1)
				write_string(&sb, field.name)
				write_string(&sb, ":\n	")
				write_string_builder_start(&sb, 1)
				write_string(&sb, "\"\\\"")
				write_string(&sb, field.lowercase ? to_lower(field.name) : field.name)
				write_string(&sb, "\\\"\"")
			case .Struct:
				write_string_builder_start(&sb, 1)
				if i == 0 {
					write_string(&sb, "\"{\\\"")
				} else {
					write_string(&sb, "\",\\\"")
				}
				write_string(&sb, field.name)
				write_string(&sb, "\\\":\"")
				write_string(&sb, ")\n")
			}

			if field.is_slice {
				write_string_builder_start(&sb, 1)
				write_string(&sb, "\"[\")\n")
				write_indented(&sb, "for ele, i in &", 1)
				write_field_access_by_name(&sb, setting.name, field)
				write_string(&sb, " {\n")
				write_indented(&sb, "", 1)
				write_field_value(&sb, field, setting.name)

				write_indented(&sb, "if i != len(", 2)
				write_field_access_by_name(&sb, setting.name, field)
				write_string(&sb, ")-1 {\n		")
				write_string_builder_start(&sb, 1)
				write_string(&sb, "\",\")\n")
				write_indented(&sb, "}\n", 2)

				write_indented(&sb, "}\n", 1)
				write_string_builder_start(&sb, 1)
				write_string(&sb, "\"]\")\n")
			} else {
				log.warn(setting.type, "now")
				if setting.type == Odin_Type.Enum {
					field.from_enum = true
				}
				write_field_value(&sb, field, setting.name)
			}
		}
		switch setting.type {
		case .Enum:
			write_indented(&sb, "}", 1)
		case .Struct:
			write_string_builder_start(&sb, 1)
			write_string(&sb, "\"}\")")
		}

		write_string(&sb, "\n}\n\n")
	}

	return strings.to_string(sb)
}

extract_marshal_settings :: proc(val: ^ast.Value_Decl) -> (ms: Marshal_Settings, ok: bool) {
	struct_ident := val.names[0].derived.(^ast.Ident) or_return
	for attr in val.attributes {

		for elem in attr.elems {


			fv, has_fv := elem.derived.(^ast.Field_Value)
			ident: ^ast.Ident = nil
			if has_fv {
				// TODO err handling
				ident = fv.field.derived.(^ast.Ident) or_else panic("no field")

			} else {
				// TODO err handling
				ident = elem.derived.(^ast.Ident) or_else panic("no ident")
			}

			as_struct, is_struct := val.values[0].derived.(^ast.Struct_Type)
			as_enum, is_enum := val.values[0].derived.(^ast.Enum_Type)

			if ident.name == "json" {
				ms := Marshal_Settings {
					name   = struct_ident.name,
					strict = true,
				}

				if is_enum {
					ms.type = .Enum
					for field in as_enum.fields {
						field_ident, has_ident := field.derived.(^ast.Ident)
						assert(has_ident)
						append_elem(
							&ms.fields,
							Field {
								name = field_ident.name,
								type = "string",
								is_slice = false,
								tag = "",
								from_enum = true,
							},
						)
					}
				}

				if is_struct {
					ms.type = .Struct
					for field in as_struct.fields.list {
						field_name, has_fn := field.names[0].derived.(^ast.Ident)
						field_type, has_ft := field.type.derived.(^ast.Ident)
						field_enum, is_enum := field_type.derived.(^ast.Enum_Type)
						field_type_array, has_at := field.type.derived.(^ast.Array_Type)
						assert(has_fn)
						assert(has_ft || has_at)
						if has_at {
							w, ii := field_type_array.elem.derived.(^ast.Ident)
							assert(ii)
							append_elem(
								&ms.fields,
								Field {
									name = field_name.name,
									type = w.name,
									is_slice = true,
									tag = field.tag.text,
									from_enum = false,
								},
							)
						} else {
							log.debug("here", is_enum, has_fn, has_fn)
							append_elem(
								&ms.fields,
								Field {
									name = field_name.name,
									type = field_type.name,
									is_slice = false,
									tag = field.tag.text,
									from_enum = is_enum,
								},
							)
						}
					}

				}

				if has_fv {
					cmp_lit, has_cmp := fv.value.derived.(^ast.Comp_Lit)
					if has_cmp {
						for elem in cmp_lit.elems {
							fv, ok := elem.derived.(^ast.Field_Value)
							assert(ok, "no field value")
							ident_key := fv.field.derived.(^ast.Ident) or_return
							ident_value := fv.value.derived.(^ast.Ident) or_return
							if ident_key.name == "strict" && ident_value.name == "false" {
								ms.strict = false
							}
							if is_enum && ident_key.name == "lowercase" && ident_value.name == "true" {
								for f in &ms.fields {
									f.lowercase = true
								}
							}
						}
					}
				}


				return ms, true
			}
		}
	}

	return {}, false
}

Marshal_Settings :: struct {
	name:   string,
	strict: bool,
	type:   Odin_Type,
	fields: [dynamic]Field,
}

Odin_Type :: enum {
	Struct,
	Enum,
}

Field :: struct {
	name:      string,
	type:      string,
	tag:       string,
	is_slice:  bool,
	from_enum: bool,
	lowercase: bool,
}


Data_Type :: struct {
	kind:          string, // eg bool, int
	is_array:      bool,
	arr_len_fixed: int,
	ptr_depth:     int, // [][]bar == 2
}
