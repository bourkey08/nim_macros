#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                                Macros for targeting the javascript backend in Nim.
#------------------------------------------------------------------------------------------------------------------------------------------------------
import nodejs, jsffi
import macros
macro eJS*(body: untyped): untyped =
    result = newStmtList()
    
    for stmt in body:
        if stmt.kind == nnkProcDef:
            # Get the procedure name
            let procName = stmt[0]
            
            # Create the emit statement
            let emitStr = "exports.`" & $procName & "` = `" & $procName & "`;"
            let emitStmt = newNimNode(nnkPragma).add(
                newNimNode(nnkExprColonExpr).add(
                ident"emit",
                newStrLitNode(emitStr)
                )
            )
            
            # Clone the procedure and add exportc pragma
            var newProc = stmt.copy()
            
            # Find or create pragma node
            if newProc[4].kind != nnkPragma:
                newProc[4] = newNimNode(nnkPragma)
            
            # Add exportc pragma
            newProc[4].add(ident"exportc")
            
            # Add emit statement and modified procedure to result
            result.add(emitStmt)
            result.add(newProc)