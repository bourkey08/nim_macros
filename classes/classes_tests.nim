#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                                    Implements tests cases for the classes macros
#------------------------------------------------------------------------------------------------------------------------------------------------------

import std/[tables]

#Include the benchmarking logic
include "../benchmark.nim"

#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                                                Define test classes
#------------------------------------------------------------------------------------------------------------------------------------------------------
class MyBaseClass:
    var test: int32 = 8
    let x: uint64 = 1234

    var thisName: string = "test name"

    constructor:
        echo "MyBaseClass constructor called"

    func setName(name: string) =
        self.thisName = name

    func getTest(): string = 
        return "Hello from MyBaseClass"

    func add(x: uint32, y: uint64): string = 
        return $(x.int64 + y.int64())

    proc getName(): string = 
        return self.thisName

    method getName2(): string = 
        return "MyBaseClass"

class TestClass2:
    var testId: int
    let testName: string = "TestClass2"
    const testConst: string = "TestClass2Const"

    constructor(id: int, name: string):
        self.testId = id
        echo name
        echo "TestClass2 constructor called with id: ", id

class MyClass(MyBaseClass):
    var stateTbl: Table[string, string]

    constructor():
        echo "Running"
        self.stateTbl["name"] = "Hello World"

    func getName(): string = 
        return self.stateTbl["name"]

    method getName2(): string = 
        return self.stateTbl["name"]

    #Uncomment this to override the property on the base class with this one
    #[
    method getTest(): string = 
        return "Hello from MyClass"
    ]#


#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                                                Test class functionality
#------------------------------------------------------------------------------------------------------------------------------------------------------
block:
    let myObj = newMyBaseClass()
    let myObj2 = newTestClass2(42, "testing")

    echo myObj[]
    echo myObj.x

    echo "---"
    echo myObj.getTest()
    echo myObj.add(5.uint32, 10.uint64)

    echo "---"
    echo myObj.getName()
    myObj.setName("Newer Name")
    echo myObj.getName()

    let obj3 = newMyClass()

    echo obj3.getName()
    echo obj3.getTest()


#------------------------------------------------------------------------------------------------------------------------------------------------------
#                                                                        Perf tests
#------------------------------------------------------------------------------------------------------------------------------------------------------

when defined(bench):
    #-------------------- Define required Types and classes for the benchmark tests -------------------
    const TEST_COUNT = 100_000_000

    type BenchTest = ref object of RootObj
        name: string

    proc getName(self: BenchTest): string =
        return self.name

    type BenchTest2 = ref object of BenchTest
        name2: string

    proc getName2(self: BenchTest2): string =
        return self.name2

    class BenchTestBase:
        var name: string

        constructor(name: string):
            self.name = name

        proc getName(): string =
            return self.name


    class BenchTestDerived(BenchTestBase):
        var name2: string

        constructor(name: string):
            self.name = name


    #----------------------------------- Define the actual benchmarks ----------------------------------
    benchmark "Types - 1 Lvl - Getter", TEST_COUNT:
        setup:
            let obj = BenchTest(name: "Hello World")

        discard obj.getName()

    benchmark "Classes - 1 Lvl - Getter", TEST_COUNT:
        setup:
            let obj = newBenchTestBase("Hello World")

        discard obj.getName()

    benchmark "Types - 2 Lvl - Getter", TEST_COUNT:
        setup:
            let obj = BenchTest2(name2: "Hello World")

        discard obj.getName2()

    benchmark "Classes - 2 Lvl - Getter", TEST_COUNT:
        setup:
            let obj = newBenchTestDerived("Hello World")

        discard obj.getName()

    benchmark "Types - 1 Lvl - Constructor", TEST_COUNT:
        let obj = BenchTest(name: "Hello World")

    benchmark "Classes - 1 Lvl - Constructor", TEST_COUNT:
        let obj = newBenchTestBase("Hello World")

    benchmark "Types - 2 Lvl - Constructor", TEST_COUNT:
        let obj = BenchTest2(name2: "Hello World")

    benchmark "Classes - 2 Lvl - Constructor", TEST_COUNT:
        let obj = newBenchTestDerived("Hello World")

quit()