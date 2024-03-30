package test_dir

import "core:encoding/json"
import "core:fmt"
import "core:strings"
import "core:time"

j :: `{"can_drive":false,"state":"Alabama","days_until_expiry":55,"a":99,"b":15999999,"c":151515151515151,"d":-5,"e":-15,"f":-999999999999,"info":["car","motorcycle"],"int_arr":[1,2,3],"cstr":"hej"}`

main :: proc() {
	license := License {
		false,
		"Alabama",
		55,
		99,
		159999,
		1515151,
		-5,
		-15,
		-99999,
		'a',
		{"a", "b"},
		{1, 2, 3},
		"a_cstr",
		.Car,
	}

	sb := strings.builder_make_len(256)
	begin := time.tick_now()
	str: string
	// for i in 0 ..< 100 {
	license_to_json(&license, &sb)
	str = strings.to_string(sb)
	sb = strings.builder_make_len(256)
	// }
	end := time.tick_now()

	begin_std := time.tick_now()
	s: []u8
	// for i in 0 ..< 100 {
	s, _ = json.marshal(license, {spec = .JSON, use_enum_names = true})
	// }
	end_std := time.tick_now()

	fmt.println(str, time.duration_nanoseconds(time.tick_diff(begin, end)))
	fmt.println(string(s), time.duration_nanoseconds(time.tick_diff(begin_std, end_std)))
}
