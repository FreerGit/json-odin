package json

import "core:strings"

// TODO(perf) simd all the things
find_next_delim_or_end :: `find_next_delim_or_end :: proc(s: string, delim: rune) -> int {
	offset := 0
	for b, i in s {
		if b == delim || b == '}' {
			offset = i
			break
		}
	}
	return offset
}

`

// TODO(perf) wtf do I do with this bro.
// TODO(fix) the standard library for string <-> floats are very imcomplete, write my own? wait? idk.
float_to_string :: `Decimal_Slice :: struct {
	digits:        []byte,
	count:         int,
	decimal_point: int,
	neg:           bool,
}

Float_Info :: struct {
	mantbits: uint,
	expbits:  uint,
	bias:     int,
}

generic_ftoa :: proc(buf: []byte, val: f64, fmt: byte, precision, bit_size: int) -> []byte {
	bits: u64
	flt := Float_Info{52, 11, -1023}
    bits = transmute(u64)val
	neg := bits >> (flt.expbits + flt.mantbits) != 0
	exp := int(bits >> flt.mantbits) & (1 << flt.expbits - 1)
	mant := bits & (u64(1) << flt.mantbits - 1)
	assert(exp != (1 << flt.expbits - 1))
	switch exp {
	case 0:
		// denormalized
		exp += 1
	case:
		mant |= u64(1) << flt.mantbits
	}

	exp += flt.bias

	d_: decimal.Decimal
	d := &d_
	decimal.assign(d, mant)
	decimal.shift(d, exp - int(flt.mantbits))
	digs: Decimal_Slice
	prec := precision

	decimal.round(d, d.decimal_point + prec)

	digs = Decimal_Slice {
		digits        = d.digits[:],
		count         = d.count,
		decimal_point = d.decimal_point,
	}

	return format_digits(buf, false, neg, digs, prec, fmt)
}


format_digits :: proc(
	buf: []byte,
	shortest: bool,
	neg: bool,
	digs: Decimal_Slice,
	precision: int,
	fmt: byte,
) -> []byte {
	Buffer :: struct {
		b: []byte,
		n: int,
	}

	to_bytes :: proc(b: Buffer) -> []byte {
		return b.b[:b.n]
	}
	add_bytes :: proc(buf: ^Buffer, bytes: ..byte) {
		buf.n += copy(buf.b[buf.n:], bytes)
	}

	b := Buffer {
		b = buf,
	}
	prec := precision

	if neg do add_bytes(&b, '-')

	// integer, padded with zeros when needed
	if digs.decimal_point > 0 {
		m := min(digs.count, digs.decimal_point)
		add_bytes(&b, ..digs.digits[0:m])
		for ; m < digs.decimal_point; m += 1 {
			add_bytes(&b, '0')
		}
	} else {
		add_bytes(&b, '0')
	}

	// fractional part

    add_bytes(&b, '.')
    for i in 0 ..< prec {
        c: byte = '0'
        if j := digs.decimal_point + i; 0 <= j && j < digs.count {
            c = digs.digits[j]
            add_bytes(&b, c)
        }  
	}
	return to_bytes(b)
}`


generate_helper_procs :: proc() -> string {
	procs := strings.builder_make()
	strings.write_string(&procs, find_next_delim_or_end)
	strings.write_string(&procs, float_to_string)
	return strings.to_string(procs)
}
