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

main :: proc() {

	source_builder := strings.make_builder();

	source_data, ok := os.read_entire_file("example/basic.ct");

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

	/* parser_err: bool; */
	/* build_node, parser_err = compiler.build_tokens(&tokens); */

	p_e := compiler.parse_file(&tokens);

	compiler.analyse(&compiler.file_statements);

	/* compiler.interpret(&compiler.file_statements); */

	/* if parser_err do return; */

	/* ast_error: bool; */
	/* actions, ast_error = compiler.compile(build_node); */

	/* if ast_error do return; */

	/* vm.execute(actions); */

}
