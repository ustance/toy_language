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

	pos: Line_Info,
}

Line_Info :: struct {
	pos: i32,
	line: i32,
}

DEBUG :: false;

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

	current_pos: i32 = 0;
	current_line: i32 = 0;

	index := 0;
	for index < len(source_string) {
		start := index;
		r := utf8.rune_at_pos(source_string, index);

		index += 1;
		defer current_pos += 1;

		switch r {
			case ' ', '\r': {}

			case '\n': {
				current_pos = -1;
				current_line += 1;
			}

			case '+':
				pack_token(IToken {
					.OP,
					.ADD,
					{current_pos, current_line}
				}, &tokens);
			case '-':
				pack_token(IToken {
					.OP,
					.SUB,
					{current_pos, current_line}
				}, &tokens);
			case '*':
				pack_token(IToken {
					.OP,
					.MUL,
					{current_pos, current_line}
				}, &tokens);
			case '!': 
				new_r := utf8.rune_at_pos(source_string, index);
				if new_r == '=' {
					index += 1;
					pack_token(IToken {
						.OP,
						.NE,
						{current_pos, current_line}
					}, &tokens);
				}
			case '>': 
				new_r := utf8.rune_at_pos(source_string, index);
				if new_r == '=' {
					index += 1;
					pack_token(IToken {
						.OP,
						.GE,
						{current_pos, current_line}
					}, &tokens);
				} else {
					pack_token(IToken {
						.OP,
						.GT,
						{current_pos, current_line}
					}, &tokens);
				}
			case '<': 
				new_r := utf8.rune_at_pos(source_string, index);
				if new_r == '=' {
					index += 1;
					pack_token(IToken {
						.OP,
						.LE,
						{current_pos, current_line}
					}, &tokens);
				} else {
					pack_token(IToken {
						.OP,
						.LT,
						{current_pos, current_line}
					}, &tokens);
				}
			case '=':
				new_r := utf8.rune_at_pos(source_string, index);
				if new_r == '=' {
					index += 1;
					pack_token(IToken {
						.OP,
						.EQ,
						{current_pos, current_line}
					}, &tokens);
				} else {
					pack_token(IToken {
						.OP,
						.SET,
						{current_pos, current_line}
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
						{current_pos, current_line}
					}, &tokens);
				}
			}
			case '(': {
				pack_token(IToken {
					.PAR_OPEN,
					nil,
					{current_pos, current_line}
				}, &tokens);
			}
			case ')': {
				pack_token(IToken {
					.PAR_CLOSE,
					nil,
					{current_pos, current_line}
				}, &tokens);
			}
			case '{': {
				pack_token(IToken {
					.CB_OPEN,
					nil,
					{current_pos, current_line}
				}, &tokens);
			}
			case '}': {
				pack_token(IToken {
					.CB_CLOSE,
					nil,
					{current_pos, current_line}
				}, &tokens);
			}
			case ',': {
				pack_token(IToken {
					.COMMA,
					nil,
					{current_pos, current_line}
				}, &tokens);
			}
			case ':': {
				pack_token(IToken {
					.COLON,
					nil,
					{current_pos, current_line}
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
						{current_pos, current_line}
					}, &tokens);
				} else {
					fmt.println("Unclosed string.");
				}
			}
			case ';': {
				pack_token(IToken {
					.SEMICOLON,
					nil,
					{current_pos, current_line}
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
							{current_pos, current_line}
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
								{current_pos, current_line}
							}, &tokens);
						}
						case "var": {
							pack_token(IToken {
								.VAR,
								nil,
								{current_pos, current_line}
							}, &tokens);
						}
						case "return": {
							pack_token(IToken {
								.RET,
								nil,
								{current_pos, current_line}
							}, &tokens);
						}
						case: {
							pack_token(IToken {
								.IDENT,
								word,
								{current_pos, current_line}
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
		{i32(len(source_string)+1), current_line+1}
	}, &tokens);

	return;
}
