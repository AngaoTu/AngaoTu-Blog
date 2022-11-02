; ModuleID = '<swift-imported-modules>'
source_filename = "<swift-imported-modules>"
target datalayout = "e-m:o-i64:64-i128:128-n32:64-S128"
target triple = "arm64-apple-macosx12.0.0"

%T4main12BaseProtocolP = type { [24 x i8], %swift.type*, i8** }
%swift.type = type { i64 }
%swift.protocol_conformance_descriptor = type { i32, i32, i32, i32 }
%swift.protocol_requirement = type { i32, i32 }
%objc_class = type { %objc_class*, %objc_class*, %swift.opaque*, %swift.opaque*, %swift.opaque* }
%swift.opaque = type opaque
%swift.method_descriptor = type { i32, i32 }
%T4main9TestClassC = type <{ %swift.refcounted, %TSi }>
%swift.refcounted = type { %swift.type*, i64 }
%TSi = type <{ i64 }>
%swift.protocolref = type { i32 }
%swift.type_metadata_record = type { i32 }
%swift.metadata_response = type { %swift.type*, i64 }
%"main.TestClass.x.modify : Swift.Int with unmangled suffix ".Frame"" = type { [24 x i8] }

@"main.test : main.BaseProtocol" = hidden global %T4main12BaseProtocolP zeroinitializer, align 8
@"protocol conformance descriptor for main.TestClass : main.BaseProtocol in main" = hidden constant %swift.protocol_conformance_descriptor { i32 trunc (i64 sub (i64 ptrtoint (<{ i32, i32, i32, i32, i32, i32, %swift.protocol_requirement }>* @"protocol descriptor for main.BaseProtocol" to i64), i64 ptrtoint (%swift.protocol_conformance_descriptor* @"protocol conformance descriptor for main.TestClass : main.BaseProtocol in main" to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint (<{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>* @"nominal type descriptor for main.TestClass" to i64), i64 ptrtoint (i32* getelementptr inbounds (%swift.protocol_conformance_descriptor, %swift.protocol_conformance_descriptor* @"protocol conformance descriptor for main.TestClass : main.BaseProtocol in main", i32 0, i32 1) to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint ([2 x i8*]* @"protocol witness table for main.TestClass : main.BaseProtocol in main" to i64), i64 ptrtoint (i32* getelementptr inbounds (%swift.protocol_conformance_descriptor, %swift.protocol_conformance_descriptor* @"protocol conformance descriptor for main.TestClass : main.BaseProtocol in main", i32 0, i32 2) to i64)) to i32), i32 0 }, section "__TEXT,__const", align 4
@"protocol witness table for main.TestClass : main.BaseProtocol in main" = hidden constant [2 x i8*] [i8* bitcast (%swift.protocol_conformance_descriptor* @"protocol conformance descriptor for main.TestClass : main.BaseProtocol in main" to i8*), i8* bitcast (void (%T4main9TestClassC**, %swift.type*, i8**)* @"protocol witness for main.BaseProtocol.test() -> () in conformance main.TestClass : main.BaseProtocol in main" to i8*)], align 8
@"\01l_entry_point" = private constant { i32 } { i32 trunc (i64 sub (i64 ptrtoint (i32 (i32, i8**)* @main to i64), i64 ptrtoint ({ i32 }* @"\01l_entry_point" to i64)) to i32) }, section "__TEXT, __swift5_entry, regular, no_dead_strip", align 4
@"symbolic main.BaseProtocol" = linkonce_odr hidden constant <{ [22 x i8], i8 }> <{ [22 x i8] c"main.BaseProtocol", i8 0 }>, section "__TEXT,__swift5_typeref, regular, no_dead_strip", align 2
@"reflection metadata field descriptor main.BaseProtocol" = internal constant { i32, i32, i16, i16, i32 } { i32 trunc (i64 sub (i64 ptrtoint (<{ [22 x i8], i8 }>* @"symbolic main.BaseProtocol" to i64), i64 ptrtoint ({ i32, i32, i16, i16, i32 }* @"reflection metadata field descriptor main.BaseProtocol" to i64)) to i32), i32 0, i16 4, i16 12, i32 0 }, section "__TEXT,__swift5_fieldmd, regular, no_dead_strip", align 4
@0 = private constant [5 x i8] c"main\00"
@"module descriptor main" = linkonce_odr hidden constant <{ i32, i32, i32 }> <{ i32 0, i32 0, i32 trunc (i64 sub (i64 ptrtoint ([5 x i8]* @0 to i64), i64 ptrtoint (i32* getelementptr inbounds (<{ i32, i32, i32 }>, <{ i32, i32, i32 }>* @"module descriptor main", i32 0, i32 2) to i64)) to i32) }>, section "__TEXT,__const", align 4
@1 = private constant [13 x i8] c"BaseProtocol\00"
@"protocol descriptor for main.BaseProtocol" = hidden constant <{ i32, i32, i32, i32, i32, i32, %swift.protocol_requirement }> <{ i32 65603, i32 trunc (i64 sub (i64 ptrtoint (<{ i32, i32, i32 }>* @"module descriptor main" to i64), i64 ptrtoint (i32* getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, %swift.protocol_requirement }>, <{ i32, i32, i32, i32, i32, i32, %swift.protocol_requirement }>* @"protocol descriptor for main.BaseProtocol", i32 0, i32 1) to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint ([13 x i8]* @1 to i64), i64 ptrtoint (i32* getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, %swift.protocol_requirement }>, <{ i32, i32, i32, i32, i32, i32, %swift.protocol_requirement }>* @"protocol descriptor for main.BaseProtocol", i32 0, i32 2) to i64)) to i32), i32 0, i32 1, i32 0, %swift.protocol_requirement { i32 17, i32 0 } }>, section "__TEXT,__const", align 4
@"direct field offset for main.TestClass.x : Swift.Int" = hidden constant i64 16, align 8
@"value witness table for Builtin.NativeObject" = external global i8*, align 8
@"metaclass for main.TestClass" = hidden global %objc_class { %objc_class* @"OBJC_METACLASS_$_Swift._SwiftObject", %objc_class* @"OBJC_METACLASS_$_Swift._SwiftObject", %swift.opaque* @_objc_empty_cache, %swift.opaque* null, %swift.opaque* bitcast ({ i32, i32, i32, i32, i8*, i8*, i8*, i8*, i8*, i8*, i8* }* @_METACLASS_DATA_main.TestClass to %swift.opaque*) }, align 8
@"OBJC_CLASS_$_Swift._SwiftObject" = external global %objc_class, align 8
@_objc_empty_cache = external global %swift.opaque
@"OBJC_METACLASS_$_Swift._SwiftObject" = external global %objc_class, align 8
@2 = private unnamed_addr constant [20 x i8] c"main.TestClass\00"
@_METACLASS_DATA_main.TestClass = internal constant { i32, i32, i32, i32, i8*, i8*, i8*, i8*, i8*, i8*, i8* } { i32 129, i32 40, i32 40, i32 0, i8* null, i8* getelementptr inbounds ([20 x i8], [20 x i8]* @2, i64 0, i64 0), i8* null, i8* null, i8* null, i8* null, i8* null }, section "__DATA, __objc_const", align 8
@3 = private unnamed_addr constant [2 x i8] c"x\00"
@4 = private unnamed_addr constant [1 x i8] zeroinitializer
@_IVARS_main.TestClass = internal constant { i32, i32, [1 x { i64*, i8*, i8*, i32, i32 }] } { i32 32, i32 1, [1 x { i64*, i8*, i8*, i32, i32 }] [{ i64*, i8*, i8*, i32, i32 } { i64* @"direct field offset for main.TestClass.x : Swift.Int", i8* getelementptr inbounds ([2 x i8], [2 x i8]* @3, i64 0, i64 0), i8* getelementptr inbounds ([1 x i8], [1 x i8]* @4, i64 0, i64 0), i32 3, i32 8 }] }, section "__DATA, __objc_const", align 8
@_DATA_main.TestClass = internal constant { i32, i32, i32, i32, i8*, i8*, i8*, i8*, { i32, i32, [1 x { i64*, i8*, i8*, i32, i32 }] }*, i8*, i8* } { i32 128, i32 16, i32 24, i32 0, i8* null, i8* getelementptr inbounds ([20 x i8], [20 x i8]* @2, i64 0, i64 0), i8* null, i8* null, { i32, i32, [1 x { i64*, i8*, i8*, i32, i32 }] }* @_IVARS_main.TestClass, i8* null, i8* null }, section "__DATA, __objc_const", align 8
@5 = private constant [10 x i8] c"TestClass\00"
@"nominal type descriptor for main.TestClass" = hidden constant <{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }> <{ i32 -2147483568, i32 trunc (i64 sub (i64 ptrtoint (<{ i32, i32, i32 }>* @"module descriptor main" to i64), i64 ptrtoint (i32* getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>, <{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>* @"nominal type descriptor for main.TestClass", i32 0, i32 1) to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint ([10 x i8]* @5 to i64), i64 ptrtoint (i32* getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>, <{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>* @"nominal type descriptor for main.TestClass", i32 0, i32 2) to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint (%swift.metadata_response (i64)* @"type metadata accessor for main.TestClass" to i64), i64 ptrtoint (i32* getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>, <{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>* @"nominal type descriptor for main.TestClass", i32 0, i32 3) to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint ({ i32, i32, i16, i16, i32, i32, i32, i32 }* @"reflection metadata field descriptor main.TestClass" to i64), i64 ptrtoint (i32* getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>, <{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>* @"nominal type descriptor for main.TestClass", i32 0, i32 4) to i64)) to i32), i32 0, i32 2, i32 16, i32 6, i32 1, i32 10, i32 11, i32 5, %swift.method_descriptor { i32 18, i32 trunc (i64 sub (i64 ptrtoint (i64 (%T4main9TestClassC*)* @"main.TestClass.x.getter : Swift.Int" to i64), i64 ptrtoint (i32* getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>, <{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>* @"nominal type descriptor for main.TestClass", i32 0, i32 13, i32 1) to i64)) to i32) }, %swift.method_descriptor { i32 19, i32 trunc (i64 sub (i64 ptrtoint (void (i64, %T4main9TestClassC*)* @"main.TestClass.x.setter : Swift.Int" to i64), i64 ptrtoint (i32* getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>, <{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>* @"nominal type descriptor for main.TestClass", i32 0, i32 14, i32 1) to i64)) to i32) }, %swift.method_descriptor { i32 20, i32 trunc (i64 sub (i64 ptrtoint ({ i8*, %TSi* } (i8*, %T4main9TestClassC*)* @"main.TestClass.x.modify : Swift.Int" to i64), i64 ptrtoint (i32* getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>, <{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>* @"nominal type descriptor for main.TestClass", i32 0, i32 15, i32 1) to i64)) to i32) }, %swift.method_descriptor { i32 16, i32 trunc (i64 sub (i64 ptrtoint (void (%T4main9TestClassC*)* @"main.TestClass.test() -> ()" to i64), i64 ptrtoint (i32* getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>, <{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>* @"nominal type descriptor for main.TestClass", i32 0, i32 16, i32 1) to i64)) to i32) }, %swift.method_descriptor { i32 1, i32 trunc (i64 sub (i64 ptrtoint (%T4main9TestClassC* (%swift.type*)* @"main.TestClass.__allocating_init() -> main.TestClass" to i64), i64 ptrtoint (i32* getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>, <{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>* @"nominal type descriptor for main.TestClass", i32 0, i32 17, i32 1) to i64)) to i32) } }>, section "__TEXT,__const", align 4
@"full type metadata for main.TestClass" = internal global <{ void (%T4main9TestClassC*)*, i8**, i64, %objc_class*, %swift.opaque*, %swift.opaque*, %swift.opaque*, i32, i32, i32, i16, i16, i32, i32, <{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>*, i8*, i64, i64 (%T4main9TestClassC*)*, void (i64, %T4main9TestClassC*)*, { i8*, %TSi* } (i8*, %T4main9TestClassC*)*, void (%T4main9TestClassC*)*, %T4main9TestClassC* (%swift.type*)* }> <{ void (%T4main9TestClassC*)* @"main.TestClass.__deallocating_deinit", i8** @"value witness table for Builtin.NativeObject", i64 ptrtoint (%objc_class* @"metaclass for main.TestClass" to i64), %objc_class* @"OBJC_CLASS_$_Swift._SwiftObject", %swift.opaque* @_objc_empty_cache, %swift.opaque* null, %swift.opaque* bitcast (i8* getelementptr (i8, i8* bitcast ({ i32, i32, i32, i32, i8*, i8*, i8*, i8*, { i32, i32, [1 x { i64*, i8*, i8*, i32, i32 }] }*, i8*, i8* }* @_DATA_main.TestClass to i8*), i64 2) to %swift.opaque*), i32 2, i32 0, i32 24, i16 7, i16 0, i32 144, i32 16, <{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>* @"nominal type descriptor for main.TestClass", i8* null, i64 16, i64 (%T4main9TestClassC*)* @"main.TestClass.x.getter : Swift.Int", void (i64, %T4main9TestClassC*)* @"main.TestClass.x.setter : Swift.Int", { i8*, %TSi* } (i8*, %T4main9TestClassC*)* @"main.TestClass.x.modify : Swift.Int", void (%T4main9TestClassC*)* @"main.TestClass.test() -> ()", %T4main9TestClassC* (%swift.type*)* @"main.TestClass.__allocating_init() -> main.TestClass" }>, align 8
@"symbolic _____ 4main9TestClassC" = linkonce_odr hidden constant <{ i8, i32, i8 }> <{ i8 1, i32 trunc (i64 sub (i64 ptrtoint (<{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>* @"nominal type descriptor for main.TestClass" to i64), i64 ptrtoint (i32* getelementptr inbounds (<{ i8, i32, i8 }>, <{ i8, i32, i8 }>* @"symbolic _____ 4main9TestClassC", i32 0, i32 1) to i64)) to i32), i8 0 }>, section "__TEXT,__swift5_typeref, regular, no_dead_strip", align 2
@"symbolic Si" = linkonce_odr hidden constant <{ [2 x i8], i8 }> <{ [2 x i8] c"Si", i8 0 }>, section "__TEXT,__swift5_typeref, regular, no_dead_strip", align 2
@6 = private constant [2 x i8] c"x\00", section "__TEXT,__swift5_reflstr, regular, no_dead_strip"
@"reflection metadata field descriptor main.TestClass" = internal constant { i32, i32, i16, i16, i32, i32, i32, i32 } { i32 trunc (i64 sub (i64 ptrtoint (<{ i8, i32, i8 }>* @"symbolic _____ 4main9TestClassC" to i64), i64 ptrtoint ({ i32, i32, i16, i16, i32, i32, i32, i32 }* @"reflection metadata field descriptor main.TestClass" to i64)) to i32), i32 0, i16 1, i16 12, i32 1, i32 2, i32 trunc (i64 sub (i64 ptrtoint (<{ [2 x i8], i8 }>* @"symbolic Si" to i64), i64 ptrtoint (i32* getelementptr inbounds ({ i32, i32, i16, i16, i32, i32, i32, i32 }, { i32, i32, i16, i16, i32, i32, i32, i32 }* @"reflection metadata field descriptor main.TestClass", i32 0, i32 6) to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint ([2 x i8]* @6 to i64), i64 ptrtoint (i32* getelementptr inbounds ({ i32, i32, i16, i16, i32, i32, i32, i32 }, { i32, i32, i16, i16, i32, i32, i32, i32 }* @"reflection metadata field descriptor main.TestClass", i32 0, i32 7) to i64)) to i32) }, section "__TEXT,__swift5_fieldmd, regular, no_dead_strip", align 4
@"_swift_FORCE_LOAD_$_swiftFoundation_$_main" = weak_odr hidden constant void ()* @"_swift_FORCE_LOAD_$_swiftFoundation"
@"_swift_FORCE_LOAD_$_swiftObjectiveC_$_main" = weak_odr hidden constant void ()* @"_swift_FORCE_LOAD_$_swiftObjectiveC"
@"_swift_FORCE_LOAD_$_swiftDarwin_$_main" = weak_odr hidden constant void ()* @"_swift_FORCE_LOAD_$_swiftDarwin"
@"_swift_FORCE_LOAD_$_swiftCoreFoundation_$_main" = weak_odr hidden constant void ()* @"_swift_FORCE_LOAD_$_swiftCoreFoundation"
@"_swift_FORCE_LOAD_$_swiftDispatch_$_main" = weak_odr hidden constant void ()* @"_swift_FORCE_LOAD_$_swiftDispatch"
@"_swift_FORCE_LOAD_$_swiftXPC_$_main" = weak_odr hidden constant void ()* @"_swift_FORCE_LOAD_$_swiftXPC"
@"_swift_FORCE_LOAD_$_swiftIOKit_$_main" = weak_odr hidden constant void ()* @"_swift_FORCE_LOAD_$_swiftIOKit"
@"_swift_FORCE_LOAD_$_swiftCoreGraphics_$_main" = weak_odr hidden constant void ()* @"_swift_FORCE_LOAD_$_swiftCoreGraphics"
@"protocol descriptor runtime record for main.BaseProtocol" = private constant %swift.protocolref { i32 trunc (i64 sub (i64 ptrtoint (<{ i32, i32, i32, i32, i32, i32, %swift.protocol_requirement }>* @"protocol descriptor for main.BaseProtocol" to i64), i64 ptrtoint (%swift.protocolref* @"protocol descriptor runtime record for main.BaseProtocol" to i64)) to i32) }, section "__TEXT, __swift5_protos, regular", align 4
@"protocol conformance descriptor runtime record for main.TestClass : main.BaseProtocol in main" = private constant i32 trunc (i64 sub (i64 ptrtoint (%swift.protocol_conformance_descriptor* @"protocol conformance descriptor for main.TestClass : main.BaseProtocol in main" to i64), i64 ptrtoint (i32* @"protocol conformance descriptor runtime record for main.TestClass : main.BaseProtocol in main" to i64)) to i32), section "__TEXT, __swift5_proto, regular", align 4
@"nominal type descriptor runtime record for main.TestClass" = private constant %swift.type_metadata_record { i32 trunc (i64 sub (i64 ptrtoint (<{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>* @"nominal type descriptor for main.TestClass" to i64), i64 ptrtoint (%swift.type_metadata_record* @"nominal type descriptor runtime record for main.TestClass" to i64)) to i32) }, section "__TEXT, __swift5_types, regular", align 4
@__swift_reflection_version = linkonce_odr hidden constant i16 3
@"objc_classestype metadata for main.TestClass" = internal global i8* bitcast (%swift.type* @"type metadata for main.TestClass" to i8*), section "__DATA,__objc_classlist,regular,no_dead_strip", align 8
@llvm.used = appending global [17 x i8*] [i8* bitcast (i32 (i32, i8**)* @main to i8*), i8* bitcast ({ i32 }* @"\01l_entry_point" to i8*), i8* bitcast ({ i32, i32, i16, i16, i32 }* @"reflection metadata field descriptor main.BaseProtocol" to i8*), i8* bitcast ({ i32, i32, i16, i16, i32, i32, i32, i32 }* @"reflection metadata field descriptor main.TestClass" to i8*), i8* bitcast (void ()** @"_swift_FORCE_LOAD_$_swiftFoundation_$_main" to i8*), i8* bitcast (void ()** @"_swift_FORCE_LOAD_$_swiftObjectiveC_$_main" to i8*), i8* bitcast (void ()** @"_swift_FORCE_LOAD_$_swiftDarwin_$_main" to i8*), i8* bitcast (void ()** @"_swift_FORCE_LOAD_$_swiftCoreFoundation_$_main" to i8*), i8* bitcast (void ()** @"_swift_FORCE_LOAD_$_swiftDispatch_$_main" to i8*), i8* bitcast (void ()** @"_swift_FORCE_LOAD_$_swiftXPC_$_main" to i8*), i8* bitcast (void ()** @"_swift_FORCE_LOAD_$_swiftIOKit_$_main" to i8*), i8* bitcast (void ()** @"_swift_FORCE_LOAD_$_swiftCoreGraphics_$_main" to i8*), i8* bitcast (%swift.protocolref* @"protocol descriptor runtime record for main.BaseProtocol" to i8*), i8* bitcast (i32* @"protocol conformance descriptor runtime record for main.TestClass : main.BaseProtocol in main" to i8*), i8* bitcast (%swift.type_metadata_record* @"nominal type descriptor runtime record for main.TestClass" to i8*), i8* bitcast (i16* @__swift_reflection_version to i8*), i8* bitcast (i8** @"objc_classestype metadata for main.TestClass" to i8*)], section "llvm.metadata"

@"protocol requirements base descriptor for main.BaseProtocol" = hidden alias %swift.protocol_requirement, getelementptr (%swift.protocol_requirement, %swift.protocol_requirement* getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, %swift.protocol_requirement }>, <{ i32, i32, i32, i32, i32, i32, %swift.protocol_requirement }>* @"protocol descriptor for main.BaseProtocol", i32 0, i32 6), i32 -1)
@"method descriptor for main.TestClass.x.getter : Swift.Int" = hidden alias %swift.method_descriptor, getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>, <{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>* @"nominal type descriptor for main.TestClass", i32 0, i32 13)
@"method descriptor for main.TestClass.x.setter : Swift.Int" = hidden alias %swift.method_descriptor, getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>, <{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>* @"nominal type descriptor for main.TestClass", i32 0, i32 14)
@"method descriptor for main.TestClass.x.modify : Swift.Int" = hidden alias %swift.method_descriptor, getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>, <{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>* @"nominal type descriptor for main.TestClass", i32 0, i32 15)
@"method descriptor for main.TestClass.test() -> ()" = hidden alias %swift.method_descriptor, getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>, <{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>* @"nominal type descriptor for main.TestClass", i32 0, i32 16)
@"method descriptor for main.TestClass.__allocating_init() -> main.TestClass" = hidden alias %swift.method_descriptor, getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>, <{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>* @"nominal type descriptor for main.TestClass", i32 0, i32 17)
@"type metadata for main.TestClass" = hidden alias %swift.type, bitcast (i64* getelementptr inbounds (<{ void (%T4main9TestClassC*)*, i8**, i64, %objc_class*, %swift.opaque*, %swift.opaque*, %swift.opaque*, i32, i32, i32, i16, i16, i32, i32, <{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>*, i8*, i64, i64 (%T4main9TestClassC*)*, void (i64, %T4main9TestClassC*)*, { i8*, %TSi* } (i8*, %T4main9TestClassC*)*, void (%T4main9TestClassC*)*, %T4main9TestClassC* (%swift.type*)* }>, <{ void (%T4main9TestClassC*)*, i8**, i64, %objc_class*, %swift.opaque*, %swift.opaque*, %swift.opaque*, i32, i32, i32, i16, i16, i32, i32, <{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>*, i8*, i64, i64 (%T4main9TestClassC*)*, void (i64, %T4main9TestClassC*)*, { i8*, %TSi* } (i8*, %T4main9TestClassC*)*, void (%T4main9TestClassC*)*, %T4main9TestClassC* (%swift.type*)* }>* @"full type metadata for main.TestClass", i32 0, i32 2) to %swift.type*)

define i32 @main(i32 %0, i8** %1) #0 {
entry:
  %2 = bitcast i8** %1 to i8*
  %3 = call swiftcc %swift.metadata_response @"type metadata accessor for main.TestClass"(i64 0) #7
  %4 = extractvalue %swift.metadata_response %3, 0
  %5 = call swiftcc %T4main9TestClassC* @"main.TestClass.__allocating_init() -> main.TestClass"(%swift.type* swiftself %4)
  store %swift.type* %4, %swift.type** getelementptr inbounds (%T4main12BaseProtocolP, %T4main12BaseProtocolP* @"main.test : main.BaseProtocol", i32 0, i32 1), align 8
  store i8** getelementptr inbounds ([2 x i8*], [2 x i8*]* @"protocol witness table for main.TestClass : main.BaseProtocol in main", i32 0, i32 0), i8*** getelementptr inbounds (%T4main12BaseProtocolP, %T4main12BaseProtocolP* @"main.test : main.BaseProtocol", i32 0, i32 2), align 8
  store %T4main9TestClassC* %5, %T4main9TestClassC** bitcast (%T4main12BaseProtocolP* @"main.test : main.BaseProtocol" to %T4main9TestClassC**), align 8
  ret i32 0
}

; Function Attrs: noinline nounwind readnone
define hidden swiftcc %swift.metadata_response @"type metadata accessor for main.TestClass"(i64 %0) #1 {
entry:
  %1 = call %objc_class* @objc_opt_self(%objc_class* bitcast (i64* getelementptr inbounds (<{ void (%T4main9TestClassC*)*, i8**, i64, %objc_class*, %swift.opaque*, %swift.opaque*, %swift.opaque*, i32, i32, i32, i16, i16, i32, i32, <{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>*, i8*, i64, i64 (%T4main9TestClassC*)*, void (i64, %T4main9TestClassC*)*, { i8*, %TSi* } (i8*, %T4main9TestClassC*)*, void (%T4main9TestClassC*)*, %T4main9TestClassC* (%swift.type*)* }>, <{ void (%T4main9TestClassC*)*, i8**, i64, %objc_class*, %swift.opaque*, %swift.opaque*, %swift.opaque*, i32, i32, i32, i16, i16, i32, i32, <{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>*, i8*, i64, i64 (%T4main9TestClassC*)*, void (i64, %T4main9TestClassC*)*, { i8*, %TSi* } (i8*, %T4main9TestClassC*)*, void (%T4main9TestClassC*)*, %T4main9TestClassC* (%swift.type*)* }>* @"full type metadata for main.TestClass", i32 0, i32 2) to %objc_class*))
  %2 = bitcast %objc_class* %1 to %swift.type*
  %3 = insertvalue %swift.metadata_response undef, %swift.type* %2, 0
  %4 = insertvalue %swift.metadata_response %3, i64 0, 1
  ret %swift.metadata_response %4
}

define hidden swiftcc void @"(extension in main):main.BaseProtocol.test() -> ()"(%swift.type* %Self, i8** %Self.BaseProtocol, %swift.opaque* noalias nocapture swiftself %0) #0 {
entry:
  %Self1 = alloca %swift.type*, align 8
  %self.debug = alloca %swift.opaque*, align 8
  %1 = bitcast %swift.opaque** %self.debug to i8*
  call void @llvm.memset.p0i8.i64(i8* align 8 %1, i8 0, i64 8, i1 false)
  store %swift.type* %Self, %swift.type** %Self1, align 8
  store %swift.opaque* %0, %swift.opaque** %self.debug, align 8
  ret void
}

define hidden swiftcc i64 @"variable initialization expression of main.TestClass.x : Swift.Int"() #0 {
entry:
  ret i64 10
}

define hidden swiftcc i64 @"main.TestClass.x.getter : Swift.Int"(%T4main9TestClassC* swiftself %0) #0 {
entry:
  %access-scratch = alloca [24 x i8], align 8
  %1 = getelementptr inbounds %T4main9TestClassC, %T4main9TestClassC* %0, i32 0, i32 1
  %2 = bitcast [24 x i8]* %access-scratch to i8*
  call void @llvm.lifetime.start.p0i8(i64 -1, i8* %2)
  %3 = bitcast %TSi* %1 to i8*
  call void @swift_beginAccess(i8* %3, [24 x i8]* %access-scratch, i64 32, i8* null) #5
  %._value = getelementptr inbounds %TSi, %TSi* %1, i32 0, i32 0
  %4 = load i64, i64* %._value, align 8
  call void @swift_endAccess([24 x i8]* %access-scratch) #5
  %5 = bitcast [24 x i8]* %access-scratch to i8*
  call void @llvm.lifetime.end.p0i8(i64 -1, i8* %5)
  ret i64 %4
}

define hidden swiftcc void @"main.TestClass.x.setter : Swift.Int"(i64 %0, %T4main9TestClassC* swiftself %1) #0 {
entry:
  %access-scratch = alloca [24 x i8], align 8
  %2 = getelementptr inbounds %T4main9TestClassC, %T4main9TestClassC* %1, i32 0, i32 1
  %3 = bitcast [24 x i8]* %access-scratch to i8*
  call void @llvm.lifetime.start.p0i8(i64 -1, i8* %3)
  %4 = bitcast %TSi* %2 to i8*
  call void @swift_beginAccess(i8* %4, [24 x i8]* %access-scratch, i64 33, i8* null) #5
  %._value = getelementptr inbounds %TSi, %TSi* %2, i32 0, i32 0
  store i64 %0, i64* %._value, align 8
  call void @swift_endAccess([24 x i8]* %access-scratch) #5
  %5 = bitcast [24 x i8]* %access-scratch to i8*
  call void @llvm.lifetime.end.p0i8(i64 -1, i8* %5)
  ret void
}

; Function Attrs: noinline
define hidden swiftcc { i8*, %TSi* } @"main.TestClass.x.modify : Swift.Int"(i8* noalias dereferenceable(32) %0, %T4main9TestClassC* swiftself %1) #2 {
entry:
  %FramePtr = bitcast i8* %0 to %"main.TestClass.x.modify : Swift.Int with unmangled suffix ".Frame""*
  %access-scratch = getelementptr inbounds %"main.TestClass.x.modify : Swift.Int with unmangled suffix ".Frame"", %"main.TestClass.x.modify : Swift.Int with unmangled suffix ".Frame""* %FramePtr, i32 0, i32 0
  %2 = getelementptr inbounds %T4main9TestClassC, %T4main9TestClassC* %1, i32 0, i32 1
  %3 = bitcast [24 x i8]* %access-scratch to i8*
  call void @llvm.lifetime.start.p0i8(i64 -1, i8* %3)
  %4 = bitcast %TSi* %2 to i8*
  call void @swift_beginAccess(i8* %4, [24 x i8]* %access-scratch, i64 33, i8* null) #5
  %5 = bitcast void (i8*, i1)* @"main.TestClass.x.modify : Swift.Int with unmangled suffix ".resume.0"" to i8*
  %6 = insertvalue { i8*, %TSi* } undef, i8* %5, 0
  %7 = insertvalue { i8*, %TSi* } %6, %TSi* %2, 1
  ret { i8*, %TSi* } %7
}

define internal swiftcc void @"main.TestClass.x.modify : Swift.Int with unmangled suffix ".resume.0""(i8* noalias nonnull align 8 dereferenceable(32) %0, i1 %1) #0 {
entryresume.0:
  %FramePtr = bitcast i8* %0 to %"main.TestClass.x.modify : Swift.Int with unmangled suffix ".Frame""*
  %vFrame = bitcast %"main.TestClass.x.modify : Swift.Int with unmangled suffix ".Frame""* %FramePtr to i8*
  %access-scratch = getelementptr inbounds %"main.TestClass.x.modify : Swift.Int with unmangled suffix ".Frame"", %"main.TestClass.x.modify : Swift.Int with unmangled suffix ".Frame""* %FramePtr, i32 0, i32 0
  br i1 %1, label %4, label %2

2:                                                ; preds = %entryresume.0
  call void @swift_endAccess([24 x i8]* %access-scratch) #5
  %3 = bitcast [24 x i8]* %access-scratch to i8*
  call void @llvm.lifetime.end.p0i8(i64 -1, i8* %3)
  br label %CoroEnd

4:                                                ; preds = %entryresume.0
  call void @swift_endAccess([24 x i8]* %access-scratch) #5
  %5 = bitcast [24 x i8]* %access-scratch to i8*
  call void @llvm.lifetime.end.p0i8(i64 -1, i8* %5)
  br label %CoroEnd

CoroEnd:                                          ; preds = %2, %4
  ret void
}

define hidden swiftcc void @"main.TestClass.test() -> ()"(%T4main9TestClassC* swiftself %0) #0 {
entry:
  %self.debug = alloca %T4main9TestClassC*, align 8
  %1 = bitcast %T4main9TestClassC** %self.debug to i8*
  call void @llvm.memset.p0i8.i64(i8* align 8 %1, i8 0, i64 8, i1 false)
  store %T4main9TestClassC* %0, %T4main9TestClassC** %self.debug, align 8
  ret void
}

define hidden swiftcc %swift.refcounted* @"main.TestClass.deinit"(%T4main9TestClassC* swiftself %0) #0 {
entry:
  %self.debug = alloca %T4main9TestClassC*, align 8
  %1 = bitcast %T4main9TestClassC** %self.debug to i8*
  call void @llvm.memset.p0i8.i64(i8* align 8 %1, i8 0, i64 8, i1 false)
  store %T4main9TestClassC* %0, %T4main9TestClassC** %self.debug, align 8
  %2 = bitcast %T4main9TestClassC* %0 to %swift.refcounted*
  ret %swift.refcounted* %2
}

define hidden swiftcc void @"main.TestClass.__deallocating_deinit"(%T4main9TestClassC* swiftself %0) #0 {
entry:
  %self.debug = alloca %T4main9TestClassC*, align 8
  %1 = bitcast %T4main9TestClassC** %self.debug to i8*
  call void @llvm.memset.p0i8.i64(i8* align 8 %1, i8 0, i64 8, i1 false)
  store %T4main9TestClassC* %0, %T4main9TestClassC** %self.debug, align 8
  %2 = call swiftcc %swift.refcounted* @"main.TestClass.deinit"(%T4main9TestClassC* swiftself %0)
  %3 = bitcast %swift.refcounted* %2 to %T4main9TestClassC*
  %4 = bitcast %T4main9TestClassC* %3 to %swift.refcounted*
  call void @swift_deallocClassInstance(%swift.refcounted* %4, i64 24, i64 7)
  ret void
}

define hidden swiftcc %T4main9TestClassC* @"main.TestClass.__allocating_init() -> main.TestClass"(%swift.type* swiftself %0) #0 {
entry:
  %1 = call noalias %swift.refcounted* @swift_allocObject(%swift.type* %0, i64 24, i64 7) #5
  %2 = bitcast %swift.refcounted* %1 to %T4main9TestClassC*
  %3 = call swiftcc %T4main9TestClassC* @"main.TestClass.init() -> main.TestClass"(%T4main9TestClassC* swiftself %2)
  ret %T4main9TestClassC* %3
}

; Function Attrs: argmemonly nofree nounwind willreturn writeonly
declare void @llvm.memset.p0i8.i64(i8* nocapture writeonly, i8, i64, i1 immarg) #3

; Function Attrs: argmemonly nofree nosync nounwind willreturn
declare void @llvm.lifetime.start.p0i8(i64 immarg, i8* nocapture) #4

; Function Attrs: nounwind
declare void @swift_beginAccess(i8*, [24 x i8]*, i64, i8*) #5

; Function Attrs: nounwind
declare void @swift_endAccess([24 x i8]*) #5

; Function Attrs: argmemonly nofree nosync nounwind willreturn
declare void @llvm.lifetime.end.p0i8(i64 immarg, i8* nocapture) #4

declare swiftcc void @"coroutine continuation prototype for @escaping @convention(thin) @convention(method) @yield_once (@guaranteed main.TestClass) -> (@yields @inout Swift.Int)"(i8* noalias dereferenceable(32), i1) #0

declare i8* @malloc(i64)

declare void @free(i8*)

; Function Attrs: nounwind
declare token @llvm.coro.id.retcon.once(i32, i32, i8*, i8*, i8*, i8*) #5

; Function Attrs: nounwind
declare i8* @llvm.coro.begin(token, i8* writeonly) #5

; Function Attrs: nounwind
declare i1 @llvm.coro.suspend.retcon.i1(...) #5

; Function Attrs: nounwind
declare i1 @llvm.coro.end(i8*, i1) #5

; Function Attrs: nounwind
declare void @swift_deallocClassInstance(%swift.refcounted*, i64, i64) #5

; Function Attrs: nounwind
declare %swift.refcounted* @swift_allocObject(%swift.type*, i64, i64) #5

define hidden swiftcc %T4main9TestClassC* @"main.TestClass.init() -> main.TestClass"(%T4main9TestClassC* swiftself %0) #0 {
entry:
  %self.debug = alloca %T4main9TestClassC*, align 8
  %1 = bitcast %T4main9TestClassC** %self.debug to i8*
  call void @llvm.memset.p0i8.i64(i8* align 8 %1, i8 0, i64 8, i1 false)
  store %T4main9TestClassC* %0, %T4main9TestClassC** %self.debug, align 8
  %2 = getelementptr inbounds %T4main9TestClassC, %T4main9TestClassC* %0, i32 0, i32 1
  %._value = getelementptr inbounds %TSi, %TSi* %2, i32 0, i32 0
  store i64 10, i64* %._value, align 8
  ret %T4main9TestClassC* %0
}

define internal swiftcc void @"protocol witness for main.BaseProtocol.test() -> () in conformance main.TestClass : main.BaseProtocol in main"(%T4main9TestClassC** noalias nocapture swiftself dereferenceable(8) %0, %swift.type* %Self, i8** %SelfWitnessTable) #0 {
entry:
  %1 = load %T4main9TestClassC*, %T4main9TestClassC** %0, align 8
  %2 = getelementptr inbounds %T4main9TestClassC, %T4main9TestClassC* %1, i32 0, i32 0, i32 0
  %3 = load %swift.type*, %swift.type** %2, align 8
  %4 = bitcast %swift.type* %3 to void (%T4main9TestClassC*)**
  %5 = getelementptr inbounds void (%T4main9TestClassC*)*, void (%T4main9TestClassC*)** %4, i64 14
  %6 = load void (%T4main9TestClassC*)*, void (%T4main9TestClassC*)** %5, align 8, !invariant.load !52
  call swiftcc void %6(%T4main9TestClassC* swiftself %1) #8
  ret void
}

; Function Attrs: nounwind
declare %objc_class* @objc_opt_self(%objc_class*) #5

declare extern_weak void @"_swift_FORCE_LOAD_$_swiftFoundation"()

declare extern_weak void @"_swift_FORCE_LOAD_$_swiftObjectiveC"()

declare extern_weak void @"_swift_FORCE_LOAD_$_swiftDarwin"()

declare extern_weak void @"_swift_FORCE_LOAD_$_swiftCoreFoundation"()

declare extern_weak void @"_swift_FORCE_LOAD_$_swiftDispatch"()

declare extern_weak void @"_swift_FORCE_LOAD_$_swiftXPC"()

declare extern_weak void @"_swift_FORCE_LOAD_$_swiftIOKit"()

declare extern_weak void @"_swift_FORCE_LOAD_$_swiftCoreGraphics"()

; Function Attrs: alwaysinline
define private void @coro.devirt.trigger(i8* %0) #6 {
entry:
  ret void
}

attributes #0 = { "frame-pointer"="non-leaf" "no-trapping-math"="true" "probe-stack"="__chkstk_darwin" "stack-protector-buffer-size"="8" "target-cpu"="apple-a12" "target-features"="+aes,+crc,+crypto,+fp-armv8,+fullfp16,+lse,+neon,+ras,+rcpc,+rdm,+sha2,+v8.3a,+zcm,+zcz" }
attributes #1 = { noinline nounwind readnone "frame-pointer"="none" "no-trapping-math"="true" "probe-stack"="__chkstk_darwin" "stack-protector-buffer-size"="8" "target-cpu"="apple-a12" "target-features"="+aes,+crc,+crypto,+fp-armv8,+fullfp16,+lse,+neon,+ras,+rcpc,+rdm,+sha2,+v8.3a,+zcm,+zcz" }
attributes #2 = { noinline "frame-pointer"="non-leaf" "no-trapping-math"="true" "probe-stack"="__chkstk_darwin" "stack-protector-buffer-size"="8" "target-cpu"="apple-a12" "target-features"="+aes,+crc,+crypto,+fp-armv8,+fullfp16,+lse,+neon,+ras,+rcpc,+rdm,+sha2,+v8.3a,+zcm,+zcz" }
attributes #3 = { argmemonly nofree nounwind willreturn writeonly }
attributes #4 = { argmemonly nofree nosync nounwind willreturn }
attributes #5 = { nounwind }
attributes #6 = { alwaysinline }
attributes #7 = { nounwind readnone }
attributes #8 = { noinline }

!llvm.module.flags = !{!0, !1, !2, !3, !4, !5, !6, !7, !8, !9, !10, !11, !12, !13, !14, !15}
!swift.module.flags = !{!16}
!llvm.asan.globals = !{!17, !18, !19, !20, !21, !22, !23, !24, !25, !26, !27, !28, !29, !30}
!llvm.linker.options = !{!31, !32, !33, !34, !35, !36, !37, !38, !39, !40, !41, !42, !43, !44, !45, !46, !47, !48, !49, !50, !51}

!0 = !{i32 2, !"SDK Version", [2 x i32] [i32 12, i32 3]}
!1 = !{i32 1, !"Objective-C Version", i32 2}
!2 = !{i32 1, !"Objective-C Image Info Version", i32 0}
!3 = !{i32 1, !"Objective-C Image Info Section", !"__DATA,__objc_imageinfo,regular,no_dead_strip"}
!4 = !{i32 4, !"Objective-C Garbage Collection", i32 84281088}
!5 = !{i32 1, !"Objective-C Class Properties", i32 64}
!6 = !{i32 1, !"Objective-C Enforce ClassRO Pointer Signing", i8 0}
!7 = !{i32 1, !"wchar_size", i32 4}
!8 = !{i32 1, !"branch-target-enforcement", i32 0}
!9 = !{i32 1, !"sign-return-address", i32 0}
!10 = !{i32 1, !"sign-return-address-all", i32 0}
!11 = !{i32 1, !"sign-return-address-with-bkey", i32 0}
!12 = !{i32 7, !"PIC Level", i32 2}
!13 = !{i32 7, !"uwtable", i32 1}
!14 = !{i32 7, !"frame-pointer", i32 1}
!15 = !{i32 1, !"Swift Version", i32 7}
!16 = !{!"standard-library", i1 false}
!17 = !{%swift.protocol_conformance_descriptor* @"protocol conformance descriptor for main.TestClass : main.BaseProtocol in main", null, null, i1 false, i1 true}
!18 = !{<{ [22 x i8], i8 }>* @"symbolic main.BaseProtocol", null, null, i1 false, i1 true}
!19 = !{{ i32, i32, i16, i16, i32 }* @"reflection metadata field descriptor main.BaseProtocol", null, null, i1 false, i1 true}
!20 = !{<{ i32, i32, i32 }>* @"module descriptor main", null, null, i1 false, i1 true}
!21 = !{<{ i32, i32, i32, i32, i32, i32, %swift.protocol_requirement }>* @"protocol descriptor for main.BaseProtocol", null, null, i1 false, i1 true}
!22 = !{<{ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor, %swift.method_descriptor }>* @"nominal type descriptor for main.TestClass", null, null, i1 false, i1 true}
!23 = !{<{ i8, i32, i8 }>* @"symbolic _____ 4main9TestClassC", null, null, i1 false, i1 true}
!24 = !{<{ [2 x i8], i8 }>* @"symbolic Si", null, null, i1 false, i1 true}
!25 = !{[2 x i8]* @6, null, null, i1 false, i1 true}
!26 = !{{ i32, i32, i16, i16, i32, i32, i32, i32 }* @"reflection metadata field descriptor main.TestClass", null, null, i1 false, i1 true}
!27 = !{%swift.protocolref* @"protocol descriptor runtime record for main.BaseProtocol", null, null, i1 false, i1 true}
!28 = !{i32* @"protocol conformance descriptor runtime record for main.TestClass : main.BaseProtocol in main", null, null, i1 false, i1 true}
!29 = !{%swift.type_metadata_record* @"nominal type descriptor runtime record for main.TestClass", null, null, i1 false, i1 true}
!30 = !{i8** @"objc_classestype metadata for main.TestClass", null, null, i1 false, i1 true}
!31 = !{!"-lswiftFoundation"}
!32 = !{!"-lswiftCore"}
!33 = !{!"-lswift_Concurrency"}
!34 = !{!"-lswiftObjectiveC"}
!35 = !{!"-lswiftDarwin"}
!36 = !{!"-framework", !"Foundation"}
!37 = !{!"-lswiftCoreFoundation"}
!38 = !{!"-framework", !"CoreFoundation"}
!39 = !{!"-lswiftDispatch"}
!40 = !{!"-framework", !"Combine"}
!41 = !{!"-framework", !"CoreServices"}
!42 = !{!"-framework", !"Security"}
!43 = !{!"-lswiftXPC"}
!44 = !{!"-framework", !"CFNetwork"}
!45 = !{!"-framework", !"DiskArbitration"}
!46 = !{!"-lswiftIOKit"}
!47 = !{!"-framework", !"IOKit"}
!48 = !{!"-lswiftCoreGraphics"}
!49 = !{!"-framework", !"CoreGraphics"}
!50 = !{!"-lswiftSwiftOnoneSupport"}
!51 = !{!"-lobjc"}
!52 = !{}
