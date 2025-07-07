package hl

ASTLiteralStrNode :: struct {
    value: string,
}

ast_node_lit_str_make :: proc(value: string) -> ASTLiteralStrNode {
    return { value = value }
}

ASTCmdNode :: struct {
    cmd: string,
    args: [dynamic]ASTLiteralStrNode,
}

ast_node_cmd_make :: proc(
    cmd: string, allocator := context.allocator
) -> ASTCmdNode {
    return {
        cmd = cmd,
        args = make([dynamic]ASTLiteralStrNode, allocator),
    }
}

ast_node_cmd_append_arg :: proc(p_node: ^ASTCmdNode, arg_node: ASTLiteralStrNode) {
    append(&p_node.args, arg_node)
}

// AST_Op_Type :: enum {
//     Add, Sub, Mul, Div,
// }

// ASTOpNode :: struct {
//     type: AST_Op_Type,
//     lhs, rhs: ^ASTExprNode,
// }
//
// ast_node_op_make :: proc(
//     type: AST_Op_Type, lhs, rhs: ^ASTExprNode, allocator := context.allocator
// ) -> (p_node: ^ASTOpNode) {
//     p_node = new(ASTOpNode, allocator)
//     p_node.type = type
//     p_node.lhs = lhs
//     p_node.rhs = rhs
//
//     return
// }

ASTSeqNode :: struct {
    sequence: [dynamic]ASTNode,
}

ast_node_seq_make :: proc(allocator := context.allocator) -> ASTSeqNode {
    return {
        sequence = make([dynamic]ASTNode, allocator),
    }
}

ast_node_seq_append :: proc(p_node: ^ASTSeqNode, append_node: ASTNode) {
    append(&p_node.sequence, append_node)
}

ASTExprNode :: union {
    ASTLiteralStrNode,
}

ASTNode :: union {
    ASTSeqNode,
    ASTLiteralStrNode,
    ASTCmdNode,
    // ASTOpNode,
}



// ASTNodeType :: enum {
//     sequence, op, cmd,
// }
//
// ASTNodeOpDataType :: enum {
//     add, sub, mul, div,
// }
//
// ASTNodeOpData :: struct {
//     type: ASTNodeOpDataType,
//     lhs, rhs: Token,
// }
//
// ASTNodeCmdData :: struct {
//     cmd: Token,
//     args: [dynamic]Token,
// }
//
// ASTNodeSequenceData :: struct {
//     sequence: [dynamic]^ASTNode,
// }
//
// ASTNodeData :: union {
//     ASTNodeSequenceData,
//     ASTNodeOpData,
//     ASTNodeCmdData,
// }
//
// ASTNode :: struct {
//     type: ASTNodeType,
//     data: ASTNodeData,
//     parent: ^ASTNode,
// }
//
// ast_node_make :: proc(type: ASTNodeType, parent: ^ASTNode = nil, data: ASTNodeData = nil) -> (p_node: ^ASTNode) {
//     p_node = new(ASTNode)
//
//     p_node.type = type
//     p_node.data = data
//     p_node.parent = parent
//     // p_node.children = nil
//
//     return
// }
//
// ast_node_free_recursive :: proc(p_node: ^ASTNode) {
//     assert(p_node != nil, "the given ast node to free cannot be nil")
//     // assert(len(p_node.children) != 0, "The given node's children has an orphan dynamic child list")
//
//     // if p_node.children != nil {
//     //     // clean all children, delete the children list first
//     //     for p_child_node in p_node.children {
//     //         ast_node_free_recursive(p_node)
//     //     }
//     //
//     //     delete(p_node.children)
//     // }
//
//     free(p_node)
// }
