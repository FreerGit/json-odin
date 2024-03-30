package test_dir

import "core:encoding/json"
import "core:fmt"
import "core:strings"
import "core:time"
import "core:unicode/utf8"

j :: `{"can_drive":false,"state":"Alabama","days_until_expiry":55,"a":99,"b":15999999,"c":151515151515151,"d":-5,"e":-15,"f":-999999999999,"info":["car","motorcycle"],"int_arr":[1,2,3],"cstr":"hej"}`

@(json)
Scalar :: struct {
	val1:    int,
	val2:    i32,
	val3:    i16,
	val4:    f64,
	val5:    f32,
	val6:    f16,
	str_val: string,
}

STRING_INT64_LEN :: (size_of("-9223372036854775808") - 1)

write_f64__ :: proc(s: [dynamic]rune, f: f64, precision: int) {
	s := s
	buf: [STRING_INT64_LEN + 1]rune
	p := buf + STRING_INT64_LEN
	fmt.println(len(p))

	ui64: uint
	negative := false
	f2: f64

	// int part
	if (f < 0) {
		negative = true
		ui64 = uint(-f)
		f2 = -f - f64(ui64)
	} else {
		ui64 = uint(f)
		f2 = f - f64(ui64)
	}

	for i := len(p) - 1; i >= 0; ui64 /= 10 {
		p[i] = rune(ui64 % 10) + '0'
		i -= 1
	}
	if negative {
		append(&s, '-')
	}
	for p_ in p {
		append(&s, p_)
	}

	// float part
	// prec := buf + rune(precision)
	if f2 > 0 && f2 > 1e-6 {
		append(&s, '.')
		p = buf
		for i := 0; f2 > 1e-6 && f2 > 0.0 && len(p) < len(buf) + precision; {
			f2 *= 10
			p[i] = rune(f2) + '0'
			i += 1
			f2 -= i32(f2)
		}
	}

	fmt.println(utf8.runes_to_string(s[:]))
}


main :: proc() {
	ab: [dynamic]rune
	write_f64__(ab, 5.555, 6)
	fmt.println(ab)
	// license := License {
	// 	false,
	// 	"Alabama",
	// 	55,
	// 	99,
	// 	159999,
	// 	1515151,
	// 	-5,
	// 	-15,
	// 	-99999,
	// 	'a',
	// 	{"a", "b"},
	// 	{1, 2, 3},
	// 	"a_cstr",
	// 	.Car,
	// }

	scalar := Scalar{1, 2, 3, 3.14, 5.2, 6.3, "this is a string"}

	sb := strings.builder_make_len(256)
	str: string
	scalar_to_json(&scalar, &sb)
	str = strings.to_string(sb)
	sb = strings.builder_make_len(256)
	begin := time.tick_now()
	// for i in 0 ..< 100 {
	scalar_to_json(&scalar, &sb)
	// license_to_json(&license, &sb)
	str = strings.to_string(sb)
	sb = strings.builder_make_len(256)
	// }
	end := time.tick_now()

	begin_std := time.tick_now()
	s: []u8
	// for i in 0 ..< 100 {
	// s, _ = json.marshal(license, {spec = .JSON, use_enum_names = true})
	// }
	end_std := time.tick_now()

	fmt.println(str, time.duration_nanoseconds(time.tick_diff(begin, end)))
	fmt.println(string(s), time.duration_nanoseconds(time.tick_diff(begin_std, end_std)))
}
