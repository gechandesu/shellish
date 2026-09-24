import shellish

fn test_quote() {
	assert shellish.quote('Hello, world!') == "'Hello, world!'"
	assert shellish.quote("John's notebook") == '\'John\'"\'"\'s notebook\''
	assert shellish.quote("Jack O'Neill") == '\'Jack O\'"\'"\'Neill\''
}

fn test_double_quote() {
	assert shellish.double_quote('NAME="Arch Linux"') == r'"NAME=\"Arch Linux\""'
	assert shellish.double_quote(r'Hello, ${NAME}!') == r'"Hello, ${NAME}!"'
}

fn test_unquote() {
	assert shellish.unquote('"hello"') == 'hello'
	assert shellish.unquote("'world'") == 'world'
}

fn test_escape() {
	assert shellish.escape('Hello, World!') == r'Hello,\ World\!'
}

fn test_unescape() {
	assert shellish.unescape(r'\\\\\\') == r'\\\'
	assert shellish.unescape(r'Line\ with\ spaces\\n') == r'Line with spaces\n'
}

fn test_strip_ansi_escape_codes() {
	assert shellish.strip_ansi_escape_codes('\033[32mhello\033[0m') == 'hello'
}

// Original test data taken from https://github.com/python/cpython/blob/3.14/Lib/test/test_shlex.py
// vfmt off
const test_data = {
	'foo':                      ['foo']
	'foo bar':                  ['foo', 'bar']
	' foo bar':                 ['foo', 'bar']
	' foo bar ':                ['foo', 'bar']
	'foo     bar  baz':         ['foo', 'bar', 'baz']
	r'\foo bar':                ['foo', 'bar']
	r'\ foo bar':               [' foo', 'bar']
	r'\ foo':                   [' foo']
	r'foo\ bar':                ['foo bar']
	r'foo \bar baz':            ['foo', 'bar', 'baz']
	r'foo \ bar baz':           ['foo', ' bar', 'baz']
	r'foo \ bar':               ['foo', ' bar']
	'"foo" bar baz':            ['foo', 'bar', 'baz']
	'foo "bar" baz':            ['foo', 'bar', 'baz']
	'foo bar "baz"':            ['foo', 'bar', 'baz']
	"'foo' bar baz":            ['foo', 'bar', 'baz']
	"foo 'bar' baz":            ['foo', 'bar', 'baz']
	"foo bar 'baz'":            ['foo', 'bar', 'baz']
	'"foo" "bar" "baz"':        ['foo', 'bar', 'baz']
	"'foo' 'bar' 'baz'":        ['foo', 'bar', 'baz']
	'foo bar"bla"bla"bar" baz': ['foo', 'barblablabar', 'baz']
	"foo bar'bla'bla'bar' baz": ['foo', 'barblablabar', 'baz']
	'""':                       ['']
	"''":                       ['']
	'"" "" ""':                 ['', '', '']
	'foo "" bar':               ['foo', '', 'bar']
	"foo '' bar":               ['foo', '', 'bar']
	'foo "" "" "" bar':         ['foo', '', '', '', 'bar']
	"foo '' '' '' bar":         ['foo', '', '', '', 'bar']
	'foo "bar baz"':            ['foo', 'bar baz']
	r"\'":                      ["'"]
	r'\"':                      ['"']
	r'"\""':                    ['"']
	r'"foo\ bar"':              [r'foo\ bar']
	r'"foo\\ bar"':             [r'foo\ bar']
	r'"foo\\ bar\""':           [r'foo\ bar"']
	r'"foo\\" bar\"':           [r'foo\', 'bar"']
	r'"foo\\ bar\" abcde"':     [r'foo\ bar" abcde']
	r'"foo\\\ bar\" abcde"':    [r'foo\\ bar" abcde']
	r'"foo\\\x bar\" abcde"':   [r'foo\\x bar" abcde']
	r'"foo\x bar\" abcde"':     [r'foo\x bar" abcde']
	r"'foo\ bar'":              [r'foo\ bar']
	r"'foo\\ bar'":             [r'foo\\ bar']
	r'\"foo':                   ['"foo']
	r'\"foo\x':                 ['"foox']
	r'"foo\x"':                 [r'foo\x']
	r'"foo\ "':                 [r'foo\ ']
	r'foo\ xx':                 ['foo xx']
	r'foo\ x\x':                ['foo xx']
	r'foo\ x\x\"':              ['foo xx"']
	r'"foo\ x\x"':              [r'foo\ x\x']
	r'"foo\ x\x\\"':            [r'foo\ x\x\']
	r'"foo\ x\x\\""foobar"':    [r'foo\ x\x\foobar']

	'":-) ;-)"':                [':-) ;-)']
	'foo `bar baz`':            ['foo', '`bar baz`']
	r'foo "$(bar baz)"':        ['foo', r'$(bar baz)']
	r'foo $(bar)':              ['foo', r'$(bar)']
	r'foo $(bar baz)':          ['foo', r'$(bar baz)']
	r'foo#bar\nbaz':            ['foo', 'baz']
	'foo;bar':                  ['foo', ';', 'bar']

	'"foo\\\\\\x bar\\" df\'a\\ \'df"': ['foo\\\\x bar" df\'a\\ \'df']
	'"foo\\ x\\x\\\\"\\\'"foobar"': [r"foo\ x\x\'foobar"]
	'"foo\\ x\\x\\\\"\\\'"fo\'obar"': [r"foo\ x\x\'fo'obar"]
	'"foo\\ x\\x\\\\"\\\'"fo\'obar" \'don\'\\\'\'t\'': [r"foo\ x\x\'fo'obar", "don't"]
	'"foo\\ x\\x\\\\"\\\'"fo\'obar" \'don\'\\\'\'t\' \\\\': [r"foo\ x\x\'fo'obar", r"don't", r'\']
}
// vfmt on

fn test_split() {
	for input, output in test_data {
		assert shellish.split(input)! == output, 'failed on input: ${input}'
	}
}
