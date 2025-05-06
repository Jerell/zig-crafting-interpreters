const ast_expr = @import("expressions.zig");

pub const Stmt = union(enum) {
    expression: ExpressionStmt,
    print: PrintStmt,
};

pub const ExpressionStmt = struct {
    expression: *ast_expr.Expr,
};

pub const PrintStmt = struct {
    expression: *ast_expr.Expr,
};
