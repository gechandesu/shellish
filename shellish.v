module shellish

import strings

// safe_chars contains ASCII characters that can be used in shell without any escaping.
pub const safe_chars = '%+,-./0123456789:=@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz'

// special_chars contains ASCII characters that must be escaped in shell.
pub const special_chars = ' \$"\'\\!'

const special_chars_runes = [` `, `$`, `"`, `'`, `\``, `\\`, `!`]!

// quote returns a quoted version of string `s`.
//
// Note: String will be quoted with single quotes (`'`). If you expect `"`, use `double_quote()` instead.
//
// Example:
// ```
// assert shellish.quote('Hello, world!') == "'Hello, world!'"
// assert shellish.quote("John's notebook") == '\'John\'"\'"\'s notebook\''
// ```
pub fn quote(s string) string {
	if s == '' {
		return "''"
	}
	if s.contains_only(safe_chars) {
		return s
	}
	return "'" + s.replace("'", '\'"\'"\'') + "'"
}

// double_quote returns a `"` quoted version of string. In-string double
// quote will be escaped with `\`.
//
// Note: Shell interprets special characters in string quoted by double quotes.
// To prevent this use `quote()` instead or use `double_quote()` in conjunction with `escape()`.
// Example:
// ```
// assert shellish.double_quote('NAME="Arch Linux"') == r'"NAME=\"Arch Linux\""'
// assert shellish.double_quote(r'Hello, ${NAME}!') == r'"Hello, ${NAME}!"'
// ```
pub fn double_quote(s string) string {
	if s == '' {
		return '""'
	}
	if s.contains_only(safe_chars) {
		return s
	}
	return '"' + s.replace('"', r'\"') + '"'
}

// unquote removes the leading and trailing quotes (any of `"`, `'`) from string.
pub fn unquote(s string) string {
	mut ret := strings.new_builder(s.len)
	for i := 0; i < s.len; i++ {
		if (i == 0 || i == s.len - 1) && s[i] in [`"`, `'`] {
			continue
		}
		ret.write_byte(s[i])
	}
	return ret.str()
}

// escape returns a shell-escaped version of string `s`.
// Shell special characters will be escaped with backslashes without inserting quotes.
// Example: assert shellish.escape('Hello, World!') == r'Hello,\ World\!'
pub fn escape(s string) string {
	mut ret := strings.new_builder(s.len)
	for i := 0; i < s.len; i++ {
		if s[i] in special_chars_runes {
			ret.write_byte(`\\`)
			ret.write_byte(s[i])
		} else {
			ret.write_byte(s[i])
		}
	}
	return ret.str()
}

// unescape unescapes the escaped string by removing backslash escapes.
// Example: assert shellish.unescape(r'line\ with\ spaces\\n') == r'line with spaces\n'
pub fn unescape(s string) string {
	mut ret := strings.new_builder(s.len)
	for i := 0; i < s.len; i++ {
		if s[i] == `\\` && i + 1 < s.len {
			ret.write_byte(s[i + 1])
			i++
		} else {
			ret.write_byte(s[i])
		}
	}
	return ret.str()
}

// strip_non_printable strips non-printable ASCII characters (from `0x00` to `0x1f` and `0x7f`) from string.
pub fn strip_non_printable(s string) string {
	mut ret := strings.new_builder(s.len)
	for c in s {
		if c > 0x1f || c != 0x7f {
			ret.write_byte(c)
		}
	}
	return ret.str()
}

// strip_ansi_escape_codes strips ANSI escape sequences starting with `ESC [` from string.
pub fn strip_ansi_escape_codes(s string) string {
	mut ret := strings.new_builder(s.len)
	mut esc := false
	mut lsbr := false
	for c in s {
		if c == 0x1b { // ESC
			esc = true
			continue
		}
		if esc && c == `[` { // ESC [
			lsbr = true
			continue
		}
		if esc && lsbr {
			if c >= 0x40 && c <= 0x7e { // end of sequence
				esc = false
				lsbr = false
			}
			continue
		}
		ret.write_byte(c)
	}

	return ret.str()
}

// split splits the `s` string into tokens using shell-like syntax in POSIX manner.
// Example: assert shellish.split('echo "Hello, World!"') == ['echo', 'Hello, World!']
pub fn split(s string) ![]string {
	if s.is_blank() {
		return error('non-blank string expected')
	}
	return parse(s)!
}

// join joins `a` array members into a shell command.
// Example: assert shellish.join(['sh', '-c', 'hostname -f']) == "sh -c 'hostname -f'"
pub fn join(a []string) string {
	mut quoted_args := []string{}
	for arg in a {
		quoted_args << quote(arg)
	}
	return quoted_args.join(' ')
}

enum Mode {
	no
	normal
	quoted
}

fn parse(line string) ![]string {
	mut tokens := []string{}
	mut buf := []u8{}

	mut escaped := false
	mut single_quoted := false
	mut double_quoted := false
	mut back_quoted := false
	mut dollar_depth := 0
	mut commented := false

	mut got := Mode.no

	for i, c in line {
		mut r := c
		dollar_quoted := dollar_depth > 0

		if escaped {
			if r == `t` {
				r = `\t`
			}
			if r == `n` {
				r = `\n`
			}
			escaped = false
			if commented {
				if r == `\n` {
					commented = false
				}
				continue
			}
			buf << r
			got = .normal
			continue
		}

		if r == `\\` {
			if single_quoted {
				buf << r
			} else {
				if double_quoted && i + 1 <= line.len {
					// POSIX-compliant shells removes backslash only if backslash is followed
					// by $, `, ", and \ characters. Otherwise backslash is accepted as literal.
					if line[i + 1] !in [`$`, `\``, `"`, `\\`] {
						buf << r
					}
				}
				escaped = true
			}
			continue
		}

		if commented {
			if r == `\n` {
				commented = false
			}
			continue
		}

		if r == `#` && !single_quoted && !double_quoted && !back_quoted && !dollar_quoted {
			// Everything up to the end of the line is a comment. The word being
			// accumulated, if any, is terminated by it.
			if got != .no {
				tokens << buf.bytestr()
				buf = []u8{}
				got = .no
			}
			commented = true
			continue
		}

		if r == `;` && !single_quoted && !double_quoted && !back_quoted && !dollar_quoted {
			// Command separator is a token on its own.
			if got != .no {
				tokens << buf.bytestr()
				buf = []u8{}
			}
			tokens << ';'
			got = .no
			continue
		}

		if r.is_space() {
			if single_quoted || double_quoted || back_quoted || dollar_quoted {
				buf << r
			} else if got != .no {
				tokens << buf.bytestr()
				buf = []u8{}
				got = .no
			}
			continue
		}

		match r {
			`\`` {
				if !single_quoted && !double_quoted && !dollar_quoted {
					back_quoted = !back_quoted
				}
			}
			`(` {
				if !single_quoted && !double_quoted {
					// Opens a `$(` expression or nests inside an already opened one.
					if dollar_quoted || (buf.len > 0 && buf.last() == `$`) {
						dollar_depth++
						buf << r
						continue
					}
				}
			}
			`)` {
				if !single_quoted && !double_quoted && dollar_quoted {
					dollar_depth--
				}
			}
			`"` {
				if !single_quoted && !dollar_quoted {
					if double_quoted {
						got = .quoted
					}
					double_quoted = !double_quoted
					continue
				}
			}
			`'` {
				if !double_quoted && !dollar_quoted {
					if single_quoted {
						got = .quoted
					}
					single_quoted = !single_quoted
					continue
				}
			}
			else {}
		}

		got = .normal
		buf << r
	}

	if got != .no {
		tokens << buf.bytestr()
	}

	match true {
		escaped { return error('invalid escape in string') }
		single_quoted { return error('non-terminated quote in string') }
		double_quoted { return error('non-terminated double quote in string') }
		back_quoted { return error('non-terminated backtick in string') }
		dollar_depth > 0 { return error('non-terminated dollar expression in string') }
		else {}
	}

	return tokens
}
