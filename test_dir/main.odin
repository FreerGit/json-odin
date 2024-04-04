package test_dir

import "core:encoding/json"
import "core:fmt"
import "core:io"
import "core:strings"
import "core:time"
import "core:unicode/utf8"

import "core:c"
import "core:strconv"

j :: `{"can_drive":false,"state":"Alabama","days_until_expiry":55,"a":99,"b":15999999,"c":151515151515151,"d":-5,"e":-15,"f":-999999999999,"info":["car","motorcycle"],"int_arr":[1,2,3],"cstr":"hej"}`

// a_struct := A_Struct {
// 	.Car,
// 	{.Motorcycle},
// 	false,
// 	"Alabama",
// 	99,
// 	159999,
// 	1515151,
// 	-5,
// 	-15,
// 	-99.99,
// 	'a',
// 	{"a", "b"},
// 	{1, 2, 3},
// 	"a_cstr",
// }

to_parse :: `{"a_bool":true,"a_string":"hellope"}`

main :: proc() {
	a_struct := A_Struct{.Car, {.Motorcycle}, true, 12345.67, {{1, 2}, {1, 2}}}

	buf: [128]c.char

	sb := strings.builder_make_len(256)
	str: string
	begin := time.tick_now()
	// for i in 0 ..< 100 {
	// i := fmt.Info{}
	// a, b := strconv.parse_f64("43243.555")
	// strconv.append_float(buf[:], 43243.555, 'f', 6, 64)

	// strconv.generic_ftoa(buf[:], 43243.555, 'G', 6, 64)
	// strconv.generic_ftoa(buf[:], 43243., 'f', 6, 64)

	// ryu_string(c.double(43243.555), buf[:], len(buf))
	// strings.write_float(&sb, 43243.555, 'f', 6, 64)
	a_struct_to_json(&a_struct, &sb)
	str = strings.to_string(sb)
	sb = strings.builder_make_len(256)
	end := time.tick_now()

	// }

	// begin_std := time.tick_now()
	// s: []u8
	// // for i in 0 ..< 100 {d
	// // s, _ = json.marshal(license, {spec = .JSON, use_enum_names = true})
	// // }
	// end_std := time.tick_now()

	fmt.println(str, time.duration_nanoseconds(time.tick_diff(begin, end)))
	// fmt.println(string(s), time.duration_nanoseconds(time.tick_diff(begin_std, end_std)))
}
