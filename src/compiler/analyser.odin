package compiler;

import "core:fmt";

ANALYSER_DEBUG :: false;

set_to_default_value :: proc(decl: ^Decl_Var) -> bool {
	switch decl.type {
		case string:
			str_node := new_ast(Expr_Str, decl.pos);
			str_node.content = "";

			decl.expr = str_node;
		case f32:
			numb_node := new_ast(Expr_Numb, decl.pos);
			numb_node.value = 14;

			decl.expr = numb_node;
		case: {
			fmt.println("cannot set", decl.type, "to default value");
			return true;
		}
	}
	return false;
}

analyse_decl_var :: proc(decl_var: ^Decl_Var) -> bool {
	if decl_var.expr == nil && decl_var.type == nil {
		fmt.println("cannot determine type of", decl_var.name);
		return true;
	}

	if decl_var.type != nil && decl_var.expr == nil {
		set_to_default_value(decl_var);
	}

	err := resolve_expr_type(decl_var.expr);
	if err do return true;


	if decl_var.type != nil && (decl_var.type != decl_var.expr.type) {
		fmt.println("expected", decl_var.type, "got", decl_var.expr.type);
		return true;
	}

	decl_var.type = decl_var.expr.type;

	decl_var.derived = decl_var^;
	
	return false;
}

current_scope: Scope_Info;
analyse :: proc(ast: ^[dynamic] ^Node) -> (err: bool) {
	for stmt in ast {
		defer current_scope.pos += 1;
		switch v in stmt.derived {
			case Decl_Var: {
				decl_var: ^Decl_Var = auto_cast stmt;
				err := analyse_decl_var(decl_var);
				if err do return true;
			}
			case Decl_Fn: {
				decl_fn: ^Decl_Fn = auto_cast stmt;

				old_pos := current_scope.pos;
				current_scope.pos = 0;
				current_scope.scope += 1;
				for stmt in decl_fn.block.stmts {
					err := analyse_stmt(stmt);
					if err do return true;
					current_scope.pos += 1;
				}
				current_scope.scope -= 1;
				current_scope.pos = old_pos;

			}
			case: {
				fmt.println("You can't do anything in file scope. Kinda.");
				fmt.println(v);
				return true;
			}
		}
	}

	if ANALYSER_DEBUG { 
		index := 0;
		for stmt in ast {
			fmt.println(index, ": ", stmt.derived);
			switch v in stmt.derived {
				case Decl_Fn: {
					for i in 0..<len(v.block.stmts) {
						fmt.println("\t", v.block.stmts[i].derived);
					}
				}
				case:
			}
			index += 1;
		}
	}

	return;
}


analyse_stmt :: proc(stmt: ^Stmt) -> bool {

	switch v in stmt.derived {
		case Decl_Var: {
			decl_var: ^Decl_Var = auto_cast stmt;
			err := analyse_decl_var(decl_var);
			if err do return true;
		}
		case Stmt_Discard: {
			stmt_d: ^Stmt_Discard = auto_cast stmt;
			
			//analyse for arguments
		}
		case: {
			fmt.println("Can't analyse stmt");
			fmt.println(v);
			return true;
		}
	}
	
	return false;
}


resolve_expr_type :: proc(expr: ^Expr) -> bool {
	if expr.type != nil do return false;

	switch v in expr.derived {
		case Expr_Str: {
			expr.type = string;
		}
		case Expr_Numb:{
			expr.type = f32;
		}
		case Expr_Ident: {
			expr_ident: ^Expr_Ident = auto_cast expr;
			decl: ^Decl_Var = auto_cast declarations[v.name];

			if v.name in declarations {
				is_decl_visible := false;

				if decl.scope.scope == 0 {
					is_decl_visible = true;
				}

				if decl.scope.scope < current_scope.scope {
					is_decl_visible = true;
				}

				if decl.scope.scope == current_scope.scope {
					if decl.scope.pos < current_scope.pos {
						is_decl_visible = true;
					}
				}


				if !is_decl_visible {
					fmt.println("trying to access not yet defined variable", v.name);
					return true;
				}

				resolve_expr_type(decl.expr);
				expr_ident.type = decl.expr.type;

			} else {
				fmt.println("not defined", v.name);
				return true;
			}
		}
		case Expr_Op: {
			expr_op: ^Expr_Op = auto_cast expr;

			err1 := resolve_expr_type(expr_op.left);
			if err1 do return true;

			err2 := resolve_expr_type(expr_op.right);
			if err2 do return true;

			if expr_op.left.type != expr_op.right.type {
				fmt.println("cannot op on different types");
				fmt.println(expr_op.left);
				fmt.println(expr_op.right);
				return true;
			}

			expr_op.type = expr_op.left.type;
		}	
		case: {
			fmt.println("cannot resolve type of", v);
			return true;
		}
	}

	return false;
}
