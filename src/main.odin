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
INode :: compiler.INode;
IAction :: compiler.IAction;

tokens: [dynamic] IToken; // result of lexer
build_node: ^compiler.INode; //result of parser
actions: [dynamic]^IAction; //result of ast_builder

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

	tokens = compiler.lex_things(source_string);

	err: bool;
	build_node, err = compiler.build_tokens(&tokens);

	fmt.println(build_node);

	/* err2: bool; */
	/* actions, err2 = compiler.compile(build_node); */

	/* vm.execute(actions); */

}
