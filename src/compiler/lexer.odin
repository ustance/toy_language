package compiler;

import "core:fmt"
import "core:unicode/utf8"
import "core:unicode"
import "core:strconv"

import "core:strings"
import "core:os"

Token :: enum {
	IDENT, //name_test
	OP, //+ - * / > >= < <=
	NUMBER,
	STR,
	UNOP, 

	FN,
	RET,
	VAR,

	CB_OPEN, //{
	CB_CLOSE, //}

	PAR_OPEN, //(
	PAR_CLOSE, //)

	COLON, // :
	SEMICOLON, // ;
	COMMA, //,

	EOF,
}

Op :: enum {
	SET = -1, // =
	MUL = 0x01, // *
	FDIV = 0x02, // /
	ADD = 0x10, // +
	SUB = 0x11, // -

	EQ = 0x40, // == 
	NE = 0x41, // !=
	LT = 0x42, // <
	LE = 0x43, // <=
	GT = 0x44, // >
	GE = 0x45, // >=

	MAXP = 0x50,
}

Token_Value :: union {
	string,
	f32,
	Op,
}

IToken :: struct {
	token: Token,
	value: Token_Value, 

	pos: int,
}

DEBUG :: true;

lex_things :: proc(source_string: string) -> (tokens: [dynamic] IToken) {

	tokens = make([dynamic] IToken);

	pack_token :: proc(t: IToken, tokens: ^[dynamic] IToken) {
		if DEBUG {
			if t.value != nil { 
				fmt.println(t.token, " with ", t.value, " at ", t.pos);
			} else {
				fmt.println(t.token, " at ", t.pos);
			}
		}

		append(tokens, t);
	}

	index := 0;
	for index < len(source_string) {
		start := index;
		r := utf8.rune_at_pos(source_string, index);

		index += 1;

		switch r {
			case ' ', '\r', '\n': {

			}
			case '+':
				pack_token(IToken {
					.OP,
					.ADD,
					start
				}, &tokens);
			case '-':
				pack_token(IToken {
					.OP,
					.SUB,
					start
				}, &tokens);
			case '*':
				pack_token(IToken {
					.OP,
					.MUL,
					start
				}, &tokens);
			case '!': 
				new_r := utf8.rune_at_pos(source_string, index);
				if new_r == '=' {
					index += 1;
					pack_token(IToken {
						.OP,
						.NE,
						start
					}, &tokens);
				}
			case '>': 
				new_r := utf8.rune_at_pos(source_string, index);
				if new_r == '=' {
					index += 1;
					pack_token(IToken {
						.OP,
						.GE,
						start
					}, &tokens);
				} else {
					pack_token(IToken {
						.OP,
						.GT,
						start
					}, &tokens);
				}
			case '<': 
				new_r := utf8.rune_at_pos(source_string, index);
				if new_r == '=' {
					index += 1;
					pack_token(IToken {
						.OP,
						.LE,
						start
					}, &tokens);
				} else {
					pack_token(IToken {
						.OP,
						.LT,
						start
					}, &tokens);
				}
			case '=':
				new_r := utf8.rune_at_pos(source_string, index);
				if new_r == '=' {
					index += 1;
					pack_token(IToken {
						.OP,
						.EQ,
						start
					}, &tokens);
				} else {
					pack_token(IToken {
						.OP,
						.SET,
						start
					}, &tokens);
				}

			case '/': {
				r = utf8.rune_at_pos(source_string, index);
				if r == '/' {
					for index < len(source_string) {
						r = utf8.rune_at_pos(source_string, index);
						if r == '\r' || r == '\n' do break;
						index += 1;
					}
				} else {
					pack_token(IToken {
						.OP,
						.FDIV,
						start
					}, &tokens);
				}
			}
			case '(': {
				pack_token(IToken {
					.PAR_OPEN,
					nil,
					start
				}, &tokens);
			}
			case ')': {
				pack_token(IToken {
					.PAR_CLOSE,
					nil,
					start
				}, &tokens);
			}
			case '{': {
				pack_token(IToken {
					.CB_OPEN,
					nil,
					start
				}, &tokens);
			}
			case '}': {
				pack_token(IToken {
					.CB_CLOSE,
					nil,
					start
				}, &tokens);
			}
			case ',': {
				pack_token(IToken {
					.COMMA,
					nil,
					start
				}, &tokens);
			}
			case ':': {
				pack_token(IToken {
					.COLON,
					nil,
					start
				}, &tokens);
			}
			case '\"': {
				for index < len(source_string) {
					new_r := utf8.rune_at_pos(source_string, index);

					if new_r == r {
						break;
					} 

					index += 1;
				}

				if index < len(source_string) {
					index += 1;
					pack_token(IToken {
						.STR,
						source_string[start+1:index-1],
						start
					}, &tokens);
				} else {
					fmt.println("Unclosed string.");
				}
			}
			case ';': {
				pack_token(IToken {
					.SEMICOLON,
					nil,
					start
				}, &tokens);
			}

			case: {
				if unicode.is_digit(r) {
					pre_dot := true;

					for index < len(source_string) {
						r = utf8.rune_at_pos(source_string, index);

						if r == '.' {
							if !pre_dot do break;

							pre_dot = false;
							index += 1;
						} else if unicode.is_digit(r) {
							index += 1;
						} else {
							break;
						}
					}
					float_number, ok := strconv.parse_f32(source_string[start:index]);
					if ok {
						pack_token(IToken {
							.NUMBER,
							float_number,
							start
						}, &tokens);
					}
				} else if r == '_'  || ((i32(r) >= i32('a') && i32(r) <= i32('z')) || (i32(r) >= i32('A') && i32(r) <= i32('Z'))){
					for index <= len(source_string) {
						r = utf8.rune_at_pos(source_string, index);

						if r == '_'  || ((i32(r) >= i32('0') && i32(r) <= i32('9')) || (i32(r) >= i32('a') && i32(r) <= i32('z')) || (i32(r) >= i32('A') && i32(r) <= i32('Z'))){
							index += 1;
						} else {
							break;
						}
					}

					word := source_string[start:index];
					switch word {
						case "fn": {
							pack_token(IToken {
								.FN,
								nil,
								start
							}, &tokens);
						}
						case "var": {
							pack_token(IToken {
								.VAR,
								nil,
								start
							}, &tokens);
						}
						case "return": {
							pack_token(IToken {
								.RET,
								nil,
								start
							}, &tokens);
						}
						case: {
							pack_token(IToken {
								.IDENT,
								word,
								start
							}, &tokens);
						}
					}
				} 			
			}
		}
	}

	pack_token(IToken {
		.EOF,
		nil,
		len(source_string) + 1
	}, &tokens);

	return;
}
