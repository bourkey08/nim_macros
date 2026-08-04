#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                                Implements generic classes using a python style syntax
#------------------------------------------------------------------------------------------------------------------------------------------------------

echo "Importing classes.nim, this is a work in progress and should not be used in production code yet, it is only for testing and development purposes"

import std/[macrocache, macros]

#TODO: Inheritence
#TODO: Type defs
#TODO: Constructors


macro class(name: untyped, body: untyped): untyped =
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

                if stmt[0][0].kind != nnkIdent:
                    raise newException(Exception, "Invalid variable name in class, must be an identifier")

                if stmt[0][1].kind != nnkIdent:
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
        var typeDef = quote do:
            type `name` = ref object

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
        #First get the constructor code from the body (it present, its optional)
        #Get the arguments to the constructor and replicate them below
        #Define all let symbols as read/write in constructor
        let constructorName = ident("new" & $name)
        result.add quote do:
            proc `constructorName`(): `name` =
                result = `name`()


class MyBaseClass:
    var test: int32 = 8
    let x: uint64 = 1234
    constructor:
        echo "MyBaseClass constructor called"

    func getTest(): string = 
        return "Hello from MyBaseClass"

    func getName(): string = 
        return "MyBaseClass"

    method getName2(): string = 
        return "MyBaseClass"

#[
class TestClass2:
    var testId: int
    let testName: string = "TestClass2"
    const testConst: string = "TestClass2Const"

    constructor(id: int):
        self.testId = id
        echo "TestClass2 constructor called with id: ", id
]#

#[
class MyClass(MyBaseClass):
    var stateTbl: Table[string, int]

    constructor():
        self.stateTbl["name"] = "Hello World"

    func getName(): string = 
        return self.stateTbl["name"]

    method getName2(): string = 
        return self.stateTbl["name"]
]#

let myObj = newMyBaseClass()
#let myObj2 = newTestClass2(42)

echo myObj[]
echo myObj.x


quit()