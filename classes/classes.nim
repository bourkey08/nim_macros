#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                                Implements generic classes using a python style syntax
#------------------------------------------------------------------------------------------------------------------------------------------------------

import std/[macrocache, macros]

macro class(className: untyped, body: untyped): untyped =
    #Split the class name into its parts if its an extended class
    var name: NimNode
    var baseClass: NimNode = newNimNode(nnkEmpty)

    block:#Handle splitting up the class name into its parts if its an extended class
        if className.kind == nnkIdent:
            name = className
        elif className.kind == nnkCall and className[0].kind == nnkIdent and className[1].kind == nnkIdent:
            name = className[0]
            baseClass = className[1]
        else:
            raise newException(Exception, "Invalid class name, must be an identifier")

    result = newStmtList()

    #Returns the variables defined on the class, this will be any top level variable declarations
    proc getClassVars(body: NimNode): auto =    
        #Get a list of objects defined on the class, this will be any top level variable declarations
        var classVars: seq[tuple[
            isConst: bool,
            isLet: bool,
            name: string,
            nameIdent: NimNode,
            kind: NimNode,
            hasDefault: bool,
            defaultValue: NimNode
        ]] = @[]

        for stmt in body:
            if stmt.kind == nnkVarSection or stmt.kind == nnkLetSection or stmt.kind == nnkConstSection:
                #Validate the statement
                if stmt[0].len != 3:
                    raise newException(Exception, "Invalid variable declaration in class, must be of the form: var name: type = defaultValue")

                if stmt[0][0].kind != nnkIdent:#Variable name
                    raise newException(Exception, "Invalid variable name in class, must be an identifier")
                
                #Handle variable type
                if stmt[0][1].kind != nnkIdent and stmt[0][1].kind != nnkBracketExpr and stmt[0][1].kind != nnkDotExpr:
                    raise newException(Exception, "Invalid variable type in class, must be a type")                    
                
                #Get the default value if it exists
                var hasDefault = false
                var defaultValue: NimNode

                if stmt[0][2].kind == nnkEmpty:
                    hasDefault = false
                else:
                    hasDefault = true
                    defaultValue = stmt[0][2]

                #Get the name and type
                var nameIdent = stmt[0][0]
                var name = $nameIdent
                var kind = stmt[0][1]

                case stmt.kind:
                of nnkVarSection:
                    classVars.add (isConst: false, isLet: false, name: name, nameIdent: nameIdent, kind: kind, hasDefault: hasDefault, defaultValue: defaultValue)

                of nnkLetSection:
                    classVars.add (isConst: false, isLet: true, name: name, nameIdent: nameIdent, kind: kind, hasDefault: hasDefault, defaultValue: defaultValue)

                of nnkConstSection:
                    classVars.add (isConst: true, isLet: false, name: name, nameIdent: nameIdent, kind: kind, hasDefault: hasDefault, defaultValue: defaultValue)
                else:
                    raise newException(Exception, "Invalid variable declaration in class, must be of the form: var name: type = defaultValue")
                    
        return classVars

    let classVars = getClassVars(body)

    #Build the list of fields on the class object that are only settable in the constructor but then accecible in any func, proc or method
    #These are indicated by using let to define a global variable in the class body
    var letProps: seq[tuple[
        name: string,
        nameIdent: NimNode,
        realName: NimNode,#The actual object name in the type (randomized to avoid name collisions)
        kind: NimNode
    ]] = @[]

    block:#Define the type
        #Build the list of fields for the class type
        var fields = newNimNode(nnkRecList)
        for v in classVars:
            var nameIdent: NimNode
            var typeIdent: NimNode = v.kind

            if v.isConst:
                continue#Skip constants, they are handled seperatly

            elif v.isLet:#Treated as fields that can only be set in the constructor
                nameIdent = genSym(nskField, "let_" & v.name)#Hack to make assignment errors semi readable
                letProps.add (name: v.name, nameIdent: v.nameIdent, realName: nameIdent, kind: v.kind)
            else:
                nameIdent = v.nameIdent

            #Now add the field to the list of fields for the class type and set the default value if one is available
            if v.hasDefault:
                fields.add newIdentDefs(nameIdent, typeIdent, v.defaultValue)
            else:
                fields.add newIdentDefs(nameIdent, typeIdent)

        #Define the type itself
        var typeDef: NimNode
        if name.kind == nnkIdent:
            if baseClass.kind == nnkEmpty:#Base class
                typeDef = quote do:
                    type `name` = ref object of RootObj
            else:#Extended class
                typeDef = quote do:
                    type `name` = ref object of `baseClass`
        else:
            raise newException(Exception, "Invalid class name, must be an identifier")

        #Then set the fields for the type
        typeDef[0][2][0][2] = fields

        #Finally add the type to the result
        result.add typeDef

    block:#Define the getters on the type for the let properties
        for v in letProps:
            let thisNameIdent = v.nameIdent
            let realNameIdent = v.realName

            result.add quote do:
                #Template to allow reading the value with its standard name
                template `thisNameIdent`(self: `name`): untyped =
                    let val = self.`realNameIdent`
                    val

    block:#Build constructor function that is exposed
        #Iterate over all calls and check if they are the constructor
        var initCode: NimNode = newNimNode(nnkEmpty)#Will hold the body of the constructor
        var initArgs = newNimNode(nnkFormalParams)        

        for v in body:
            if v.kind == nnkCall:                
                if v[0].kind == nnkIdent:#Is of the format constructor: 
                    if $v[0] != "constructor":
                        continue

                    elif v.len <= 1:
                        continue
                    
                    #Set the constructor code, there are no args to deal with
                    initCode = newStmtList(v[1])


                elif v[0].kind == nnkObjConstr:#Is of the format constructor()                
                    let argsBody = v[0]

                    
                    #Make sure this is the constructor by checking the ident of the first object in args 
                    if argsBody[0].kind != nnkIdent:
                        continue
                    elif $argsBody[0] != "constructor":
                        continue
                    
                    #If the constructor takes any arguments then extract them now
                    if argsBody.len > 1:
                        for arg in argsBody[1..^1]:
                            if arg.len < 2:
                                raise newException(Exception, "Invalid argument definition for constructor: " & $name)

                            initArgs.add newIdentDefs(arg[0], arg[1])

        #First get the constructor code from the body (it present, its optional)
        #Get the arguments to the constructor and replicate them below
        #Define all let symbols as read/write in constructor
        let constructorName = ident("new" & $name)
        #Create the constructor
        var constNode = quote do:
            proc `constructorName`(): `name` =
                result = `name`()

                #Bind "self" locally
                template self(): untyped =
                    result
                
                `initCode`

        #Now if there are arguments for the constructor modify it to add them to its format params
        if initArgs.len > 0:
            for node in constNode:
                if node.kind == nnkFormalParams:
                    for arg in initArgs:
                        node.add arg   
                    break 

        #Finally add it to the result
        result.add constNode

    block:#Update all funcs, procs and methods to have access to self
        for v in body:
            case v.kind:
            of nnkProcDef, nnkFuncDef, nnkMethodDef:
                #Split out the function definition with its arguments, and the body
                let funcName = newIdentNode($v[0])
                let funcBody = newStmtList(v[4..^1])

                var funcArgs: seq[NimNode]
                var funcRet: NimNode
                var hasReturn = false

                for node in v:
                    if node.kind == nnkFormalParams:
                        if node[0].kind == nnkIdent:
                            funcRet = node[0]
                            hasReturn = true

                        if node.len > 1:
                            funcArgs = node[1..<node.len]
                        else:
                            funcArgs = @[]

                #Add the function definition
                var funcCall: NimNode
                let self = newIdentNode("self")

                case v.kind:
                of nnkProcDef:
                    funcCall = quote do:
                        proc `funcName`(`self`: `name`) =
                            `funcBody`
                of nnkFuncDef:
                    funcCall = quote do:
                        func `funcName`(`self`: `name`) =
                            `funcBody`
                of nnkMethodDef:
                    funcCall = quote do:
                        method `funcName`(`self`: `name`) =
                            `funcBody`
                else:
                    discard

                #Now add the return argument if there is one
                if hasReturn:
                    for node in funcCall:
                        if node.kind == nnkFormalParams:
                            node[0] = funcRet
                            break
                
                #Now add the remaining arguments if there are any
                if funcArgs.len > 0:                    
                    for node in funcCall:                        
                        if node.kind == nnkFormalParams:
                            for funcArg in funcArgs:
                                node.add funcArg
                            break

                #Finally add the function to the result
                result.add funcCall
            else:
                discard

#Include the tests if the appropriate flag is set, this is for development purposes only and should not be used in production code
when defined(blibdev_classes):
    include "./classes_tests.nim"