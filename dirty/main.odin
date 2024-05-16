package dirty

import "core:bytes"
import "core:fmt"
import "core:intrinsics"
import "core:simd"
import "core:strconv"
import "core:strings"
import "core:time"


@(json)
Integers :: struct {
	a_int:  f64,
	b_i64:  f64,
	c_i32:  f64,
	d_i16:  f64,
	e_i8:   f64,
	f_uint: f64,
	// g_u64:  u64,
	// h_u32:  u32,
	// i_u16:  u16,
	// j_u8:   u8,
}


main :: proc() {
	json := `{"a_int":1.5,"b_i64":2.5,"c_i32":3.5,"d_i16":4.5,"e_i8":5.5,"f_uint":6.5}`
	sb := strings.builder_make()
	// i := Integers{1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
	// integers_to_json(&i, &sb)
	// testing.expect_value(t, json, strings.to_string(sb))
	i_2 := Integers{}

	begin := time.tick_now()
	integers_from_json(&i_2, json[:])
	// yy := strconv.atof("5.55")
	end := time.tick_now()
	fmt.println(i_2, time.duration_nanoseconds(time.tick_diff(begin, end)))
	i_2 = {}


	begin = time.tick_now()
	integers_from_json(&i_2, json[:])
	end = time.tick_now()

	fmt.println(i_2, time.duration_nanoseconds(time.tick_diff(begin, end)))

	begin = time.tick_now()
	integers_to_json(&i_2, &sb)
	end = time.tick_now()
	fmt.println(strings.to_string(sb), time.duration_nanoseconds(time.tick_diff(begin, end)))

	// fmt.println(i_2)
}
