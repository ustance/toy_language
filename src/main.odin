package main;

import "core:fmt"

import "core:strings"
import "core:os"
import "core:unicode"
import "core:unicode/utf8"
import "core:strconv"

import "compiler"
import "vm"

IToken :: compiler.IToken;
/* IAction :: compiler.IAction; */

tokens: [dynamic] IToken; // result of lexer
/* actions: [dynamic]^IAction; //result of ast_builder */

test_func :: proc() {
	
}

main :: proc() {

	source_builder := strings.make_builder();

	source_data, ok := os.read_entire_file("example/basic.ct");

	test_func();

	if !ok {
		fmt.println("\nError reading a file!\n");
		return;
	}

	strings.write_bytes(&source_builder, source_data);

	source_string := strings.to_string(source_builder);

	fmt.println("\nbasic.ct:\n");
	fmt.println(source_string);

	lex_err: bool;
	tokens, lex_err = compiler.lex_things(source_string);

	if lex_err do return;

	p_e := compiler.parse_file(&tokens);
	if !p_e do return;

	a_e := compiler.analyse(&compiler.file_statements);
	if a_e do return;

	compiler.interpret(&compiler.file_statements);
}
