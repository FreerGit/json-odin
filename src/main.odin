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

	log.debug(marshal_settings)
	log.debug("done")

	pkg, success := parser.parse_package_from_path(source_path, &p)
	log.debug(pkg, success)


	gen_file := strings.concatenate({pkg.fullpath, "/", MARSHAL_GEN_FILENAME})
	log.debug("")
	gen_handle, open_err := os.open(gen_file, os.O_RDWR | os.O_CREATE | os.O_TRUNC, 0o755)
	log.debug("")
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

write_string_builder_start :: proc(sb: ^strings.Builder, field_name: string, ident: int) {
	using strings
	write_indented(sb, "write_string(&", 1)
	write_string(sb, to_lower(field_name))
	write_string(sb, "_sb, ")
}

write_given_builder_start :: proc(sb: ^strings.Builder, builder_t: string, field_name: string, ident: int) {
	using strings
	write_indented(sb, "write_", 1)
	write_string(sb, builder_t)
	write_string(sb, "(&")
	write_string(sb, to_lower(field_name))
	write_string(sb, "_sb, ")
}

write_field_access :: proc(sb: ^strings.Builder, type_name: string, field_name: string) {
	using strings
	write_string(sb, to_lower(type_name))
	write_string(sb, ".")
	write_string(sb, field_name)
}

write_field_value :: proc(sb: ^strings.Builder, field: Field, type_name: string) {
	using strings
	switch field.type {
	case "string":
		write_given_builder_start(sb, "quoted_string", type_name, 1)
		write_field_access(sb, type_name, field.name)
	case "bool":
		write_string_builder_start(sb, type_name, 1)
		write_field_access(sb, type_name, field.name)
		write_string(sb, " ? \"true\" : \"false\"")
	case "uint", "u64", "u32", "u16", "u8":
		write_given_builder_start(sb, "u64", type_name, 1)
		write_string(sb, "u64(")
		write_field_access(sb, type_name, field.name)
		write_string(sb, ")")
	case "int", "i64", "i32", "i16", "i8":
		write_given_builder_start(sb, "i64", type_name, 1)
		write_string(sb, "i64(")
		write_field_access(sb, type_name, field.name)
		write_string(sb, ")")
	case:
		str, _ := strings.concatenate({"Type (", field.type, ") is not supported for unmarshalling."})
		unimplemented(str)
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
		write_string(&sb, ": ^")
		write_string(&sb, setting.name)
		write_string(&sb, ", initial_len: int = 256) -> string #no_bounds_check {\n")
		write_indented(&sb, "using strings\n", 1)
		write_indented(&sb, to_lower(setting.name), 1)
		write_string(&sb, "_sb := builder_make_len(initial_len)\n")
		for field, i in setting.fields {
			write_string_builder_start(&sb, setting.name, 1)
			if i == 0 {
				write_string(&sb, "\"{\\\"")
			} else {
				write_string(&sb, "\", \\\"")

			}
			write_string(&sb, field.name)
			write_string(&sb, "\\\": \"")
			write_string(&sb, ")\n")
			write_field_value(&sb, field, setting.name)
		}
		write_string_builder_start(&sb, setting.name, 1)
		write_string(&sb, "\"}\")\n\n")
		write_indented(&sb, "return to_string(", 1)
		write_string(&sb, to_lower(setting.name))
		write_string(&sb, "_sb)\n")
		write_string(&sb, "}\n")
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

			fl, has_fl := val.values[0].derived.(^ast.Struct_Type)

			if ident.name == "json" {
				ms := Marshal_Settings {
					name   = struct_ident.name,
					strict = true,
				}

				for field in fl.fields.list {
					field_name, has_fn := field.names[0].derived.(^ast.Ident)
					field_type, has_ft := field.type.derived.(^ast.Ident)
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
							},
						)
					} else {
						append_elem(
							&ms.fields,
							Field {
								name = field_name.name,
								type = field_type.name,
								is_slice = false,
								tag = field.tag.text,
							},
						)
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
	fields: [dynamic]Field,
}

Field :: struct {
	name:     string,
	type:     string,
	tag:      string,
	is_slice: bool,
}

// Marshal_Struct :: struct {
// 	name:   string,
// 	strict: bool,
// }

print_tree :: proc(root_node: ^ast.Node) {
	visitor := ast.Visitor {
		visit = proc(visitor: ^ast.Visitor, node: ^ast.Node) -> ^ast.Visitor {
			if node == nil do return visitor
			line_info := "\n"

			switch typed_node in node.derived {
			case ^ast.Package:
			// fmt.println(typed_node)
			case ^ast.File:
			// fmt.println(typed_node)
			case ^ast.Comment_Group:
				fmt.printf("Comment_Group ( ")
				for c in typed_node.list {fmt.printf("%s ", c.text)}
				fmt.printf(")%s", line_info)
			case ^ast.Bad_Expr:
			// fmt.println(typed_node)
			case ^ast.Ident:
				fmt.printf("Ident (%s)%s", typed_node.name, line_info)
			case ^ast.Implicit:
			// fmt.println(typed_node)
			case ^ast.Undef:
			// fmt.println(typed_node)
			case ^ast.Basic_Lit:
				fmt.printf("Basic_Lit (%s(%s))%s", typed_node.tok.text, typed_node.tok.kind, line_info)
			case ^ast.Basic_Directive:
			// fmt.println(typed_node)
			case ^ast.Ellipsis:
			// fmt.println(typed_node)
			case ^ast.Proc_Lit:
				fmt.printf("Proc_Lit (inlining: %s)%s", typed_node.inlining, line_info)
			case ^ast.Comp_Lit:
				fmt.printf("Comp_Lit (n_elms:%d)%s", len(typed_node.elems), line_info)
			case ^ast.Tag_Expr:
			// fmt.println(typed_node)
			case ^ast.Unary_Expr:
			// fmt.println(typed_node)
			case ^ast.Binary_Expr:
			// fmt.println(typed_node)
			case ^ast.Paren_Expr:
			// fmt.println(typed_node)
			case ^ast.Selector_Expr:
			// fmt.println(typed_node)
			case ^ast.Implicit_Selector_Expr:
			// fmt.println(typed_node)
			case ^ast.Selector_Call_Expr:
			// fmt.println(typed_node)
			case ^ast.Index_Expr:
			// fmt.println(typed_node)
			case ^ast.Deref_Expr:
			// fmt.println(typed_node)
			case ^ast.Slice_Expr:
			// fmt.println(typed_node)
			case ^ast.Matrix_Index_Expr:
			// fmt.println(typed_node)
			case ^ast.Call_Expr:
			// fmt.println(typed_node)
			case ^ast.Field_Value:
				fmt.printf("Field_Value %s", line_info) // field: value
			case ^ast.Ternary_If_Expr:
			// fmt.println(typed_node)
			case ^ast.Ternary_When_Expr:
			// fmt.println(typed_node)
			case ^ast.Or_Else_Expr:
			// fmt.println(typed_node)
			case ^ast.Or_Return_Expr:
			// fmt.println(typed_node)
			case ^ast.Type_Assertion:
			// fmt.println(typed_node)
			case ^ast.Type_Cast:
			// fmt.println(typed_node)
			case ^ast.Auto_Cast:
			// fmt.println(typed_node)
			case ^ast.Inline_Asm_Expr:
			// fmt.println(typed_node)
			case ^ast.Proc_Group:
			// fmt.println(typed_node)
			case ^ast.Typeid_Type:
			// fmt.println(typed_node)
			case ^ast.Helper_Type:
			// fmt.println(typed_node)
			case ^ast.Distinct_Type:
			// fmt.println(typed_node)
			case ^ast.Poly_Type:
			// fmt.println(typed_node)
			case ^ast.Proc_Type:
				fmt.printf("Proc_Type (%s)%s", typed_node.calling_convention, line_info)
			case ^ast.Pointer_Type:
				ptr_depth, interior_node := extract_ptr_depth(&typed_node.elem.derived)
				desc := "" // NOTE(Jon): ideally we dont visit child pointers, so the visitor is a bit redundant
				if type_of(interior_node) == ^ast.Ident {
					desc = interior_node.(^ast.Ident).name
				}
				ptrs := strings.repeat("^", ptr_depth, context.temp_allocator)
				fmt.printf("Pointer_Type (%s%s)%s", ptrs, desc, line_info)
			case ^ast.Multi_Pointer_Type:
				ident, ok := typed_node.elem.derived.(^ast.Ident)
				name: string = ""
				if ok {name = ident.name}
				fmt.printf("Multi_Pointer_Type ([^]%s) %s", name, line_info)
			case ^ast.Array_Type:
				arr_len := ""
				if typed_node.len != nil {arr_len = typed_node.len.derived.(^ast.Basic_Lit).tok.text}
				desc := ""
				#partial switch interior in typed_node.elem.derived {
				case ^ast.Ident:
					desc = interior.name
				case ^ast.Pointer_Type:
					ptr_depth, _ := extract_ptr_depth(&interior.derived)
					desc = strings.repeat("^", ptr_depth, context.temp_allocator)
				}
				fmt.printf("Array_Type ([%s]%s) %s", arr_len, desc, line_info)
			case ^ast.Dynamic_Array_Type:
				ident := typed_node.elem.derived.(^ast.Ident).name
				fmt.printf("Dynamic_Array_Type ([dynamic]%s) %s", ident, line_info)
			case ^ast.Struct_Type:
				fmt.printf(
					"Struct_Type%s%s(fields:%d) %s",
					typed_node.is_packed ? " #packed" : "",
					typed_node.is_raw_union ? " #raw_union" : "",
					typed_node.name_count,
					line_info,
				)
			case ^ast.Union_Type:
			// fmt.println(typed_node)
			case ^ast.Enum_Type:
			// fmt.println(typed_node)
			case ^ast.Bit_Set_Type:
			// fmt.println(typed_node)
			case ^ast.Map_Type:
			// fmt.println(typed_node)
			case ^ast.Relative_Type:
			// fmt.println(typed_node)
			case ^ast.Matrix_Type:
			// fmt.println(typed_node)
			case ^ast.Bad_Stmt:
			// fmt.println(typed_node)
			case ^ast.Empty_Stmt:
			// fmt.println(typed_node)
			case ^ast.Expr_Stmt:
			// fmt.println(typed_node)
			case ^ast.Tag_Stmt:
			// fmt.println(typed_node)
			case ^ast.Assign_Stmt:
			// fmt.println(typed_node)
			case ^ast.Block_Stmt:
				fmt.printf("Block_Stmt (n_val:%d)%s", len(typed_node.stmts), line_info)
			case ^ast.If_Stmt:
			// fmt.println(typed_node)
			case ^ast.When_Stmt:
			// fmt.println(typed_node)
			case ^ast.Return_Stmt:
				fmt.printf("Return_Stmt (n_val:%d)%s", len(typed_node.results), line_info)
			case ^ast.Defer_Stmt:
			// fmt.println(typed_node)
			case ^ast.For_Stmt:
			// fmt.println(typed_node)
			case ^ast.Range_Stmt:
			// fmt.println(typed_node)
			case ^ast.Inline_Range_Stmt:
			// fmt.println(typed_node)
			case ^ast.Case_Clause:
			// fmt.println(typed_node)
			case ^ast.Switch_Stmt:
			// fmt.println(typed_node)
			case ^ast.Type_Switch_Stmt:
			// fmt.println(typed_node)
			case ^ast.Branch_Stmt:
			// fmt.println(typed_node)
			case ^ast.Or_Branch_Expr:
			// fmt.println(typed_node)
			case ^ast.Using_Stmt:
				fmt.println("USING USING USING USING USING USING USING ")
			// fmt.println(typed_node)
			case ^ast.Bad_Decl:
			// fmt.println(typed_node)
			case ^ast.Value_Decl:
				fmt.printf("Value_Decl (n_attrs:%d) %s", len(typed_node.attributes), line_info)
			case ^ast.Package_Decl:
			// fmt.println(typed_node)
			case ^ast.Import_Decl:
			// fmt.println(typed_node)
			case ^ast.Foreign_Block_Decl:
			// fmt.println(typed_node)
			case ^ast.Foreign_Import_Decl:
			// fmt.println(typed_node)
			case ^ast.Attribute:
				fmt.printf("Attribute (n_elm:%d) %s", len(typed_node.elems), line_info)
			case ^ast.Field:
				tag := typed_node.tag
				tag_str: string = ""
				if len(tag.text) > 0 {
					tag_str = fmt.tprintf("(Tag:%s(%s))", tag.text, tag.kind)
				}
				fmt.printf("Field %s%s", tag_str, line_info)
			// fmt.println(typed_node.type)
			case ^ast.Field_List:
				fmt.printf("Field_List (n_elm:%d) %s", len(typed_node.list), line_info)
			}
			return visitor
		},
	}
	ast.walk(&visitor, root_node)
}
extract_ptr_depth :: proc(node: ^ast.Any_Node) -> (ptr_depth: int, interior_node: ^ast.Any_Node) {
	next: ^ast.Any_Node = node
	ptr_depth = 0 // TODO: this should really be 1, but breaks the field_type proc
	for {
		current, is_ptr := next.(^ast.Pointer_Type)
		if !is_ptr {break}
		ptr_depth += 1
		next = &current.elem.derived
	}
	interior_node = next
	return ptr_depth, interior_node
}
extract_arr_data :: proc(
	node: ^ast.Any_Node,
) -> (
	arr_type: Array_Type,
	arr_len_fixed: int,
	interior_node: ^ast.Any_Node,
) {
	arr_len_fixed = -1
	#partial switch typed_node in node {
	case ^ast.Array_Type:
		arr_type = .Slice
		if typed_node.len != nil {
			len_str := typed_node.len.derived.(^ast.Basic_Lit).tok.text
			len_int, ok := strconv.parse_int(len_str)
			arr_type = .Fixed
			arr_len_fixed = len_int
		}
		interior_node = &typed_node.elem.derived
	case ^ast.Multi_Pointer_Type:
		arr_type = .Multi_Pointer
		interior_node = &typed_node.elem.derived
	case ^ast.Dynamic_Array_Type:
		arr_type = .Dynamic
		interior_node = &typed_node.elem.derived
	case:
		panic("unhandled array extract")
	}
	return arr_type, arr_len_fixed, interior_node
}

extract_field_type :: proc(node: ^ast.Any_Node, data_type: ^Data_Type) {
	interior_node: ^ast.Any_Node
	ptr_depth := 0
	#partial switch typed_node in node {
	case ^ast.Struct_Type:
		fmt.println(typed_node.fields.list[0])
		unimplemented("STRUCT WAS FIELD")
	case ^ast.Ident:
		data_type.kind = typed_node.name
	case ^ast.Array_Type, ^ast.Multi_Pointer_Type, ^ast.Dynamic_Array_Type:
		data_type.arr_type, data_type.arr_len_fixed, interior_node = extract_arr_data(typed_node)
	case ^ast.Pointer_Type:
		ptr_depth, interior_node = extract_ptr_depth(&typed_node.derived)
	}
	if interior_node != nil {
		#partial switch typed_node in interior_node {
		case ^ast.Ident:
			data_type.ptr_depth = ptr_depth
		case ^ast.Array_Type, ^ast.Multi_Pointer_Type, ^ast.Dynamic_Array_Type:
			data_type.arr_ptr_depth = ptr_depth
		}
		extract_field_type(interior_node, data_type)
	}
}
Data_Type :: struct {
	kind:          string, // eg bool, int
	arr_type:      Array_Type,
	arr_len_fixed: int,
	ptr_depth:     int, // eg foo: ^^bar == 2
	arr_ptr_depth: int, // eg foo: ^^^[]^bar == 3
}
Array_Type :: enum {
	Not,
	Slice,
	Fixed,
	Multi_Pointer,
	Dynamic,
}
