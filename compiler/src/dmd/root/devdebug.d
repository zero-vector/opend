module dmd.root.devdebug;

/+
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║ [Dsymbol]                                                        ║
║ ━━━━┳━━━━                                                        ║
║     ┃                                                            ║
║     ┠─ [DebugSymbol]                                             ║
║     ┠─ [Import]                                                  ║
║     ┠─ [OverloadSet]                                             ║
║     ┠─ [VersionSymbol]                                           ║
║     ┠─ [AliasAssign]                                             ║
║     ┠─ [ExpressionDsymbol]                                       ║
║     ┠─ [StaticAssert]                                            ║
║     ┠─ [ScopeDsymbol]                                            ║
║     ┃        ┠─ [Package]                                        ║
║     ┃        ┃      ┖─ [Module]                                  ║
║     ┃        ┠─ [AggregateDeclaration]                           ║
║     ┃        ┃           ┠─ [ClassDeclaration]                   ║
║     ┃        ┃           ┠─ [InterfaceDeclaration]               ║
║     ┃        ┃           ┖─ [StructDeclaration]                  ║
║     ┃        ┃                    ┖─ [UnionDeclaration]          ║
║     ┃        ┠─ [TemplateDeclaration]                            ║
║     ┃        ┖─ [TemplateInstance]                               ║
║     ┃                    ┖─ [TemplateMixin]                      ║
║     ┠─ [Declaration]                                             ║
║     ┃        ┠─ [SymbolDeclaration]                              ║
║     ┃        ┠─ [FuncDeclaration]                                ║
║     ┃        ┃         ┠─ [NewDeclaration]                       ║
║     ┃        ┃         ┠─ [FuncAliasDeclaration]                 ║
║     ┃        ┃         ┠─ [OverDeclaration]                      ║
║     ┃        ┃         ┠─ [FuncLiteralDeclaration]               ║
║     ┃        ┃         ┠─ [CtorDeclaration]                      ║
║     ┃        ┃         ┠─ [PostBlitDeclaration]                  ║
║     ┃        ┃         ┠─ [DtorDeclaration]                      ║
║     ┃        ┃         ┠─ [StaticCtorDeclaration]                ║
║     ┃        ┃         ┠─ [StaticDtorDeclaration]                ║
║     ┃        ┃         ┠─ [SharedStaticCtorDeclaration]          ║
║     ┃        ┃         ┠─ [SharedStaticDtorDeclaration]          ║
║     ┃        ┃         ┠─ [InvariantDeclaration]                 ║
║     ┃        ┃         ┖─ [UnitTestDeclaration]                  ║
║     ┃        ┠─ [VarDeclaration]                                 ║
║     ┃        ┃        ┠─ [ThisDeclaration]                       ║
║     ┃        ┃        ┠─ [BitFieldDeclaration]                   ║
║     ┃        ┃        ┠─ [TypeInfoDeclaration]                   ║
║     ┃        ┃        ┖─ [EnumMember]                            ║
║     ┃        ┖─ [AliasDeclaration]                               ║
║     ┃                                                            ║
║     ┖─ [AttribDeclaration]                                       ║
║              ┠─ [CPPNamespaceDeclaration]                        ║
║              ┠─ [VisibilityDeclaration]                          ║
║              ┠─ [MixinDeclaration]                               ║
║              ┠─ [AnonDeclaration]                                ║
║              ┠─ [ConditionalDeclaration]                         ║
║              ┃         ┖─ [StaticIfDeclaration]                  ║
║              ┠─ [StorageClassDeclaration]                        ║
║              ┖─ [ForwardingAttribDeclaration]                    ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
+/

struct Debug {

    import core.interpolation;
    import std.meta;
    import std.traits;

    import std.stdio : write, writeln;
    import core.stdc.stdio : printf;


    import dmd.root.array;

    import AST = dmd.dsymbol;
    import dmd.dclass;
    import dmd.declaration;
    import dmd.denum;
    import dmd.dimport;
    import dmd.dmodule;
    import dmd.dversion;
    import dmd.dscope;
    import dmd.dstruct;
    import dmd.dtemplate;
    import dmd.errors;
    import dmd.expression;
    import dmd.func;


    // Colors
    enum TERM_COL : string {
        RED    = "\033[0;31m",
        LRED   = "\033[1;31m",
        GREEN  = "\033[1;32m",
        YELLOW = "\033[1;33m",
        BROWN  = "\033[0;33m",
        BLUE   = "\033[1;34m",
        PURPLE = "\033[0;35m",
        PINK   = "\033[1;35m",
        CYAN   = "\033[1;36m",
        CLEAR  = "\033[0m",
    }


    static void Info
        (string file = __FILE__, size_t line = __LINE__, ARGS...)
        (InterpolationHeader header, ARGS args, InterpolationFooter footer) {

        printf(TERM_COL.BLUE.ptr);
        printf("INFO    ");
        printf(TERM_COL.GREEN.ptr);
        write(i"$(file)($(line)) : ");

        printf(TERM_COL.CLEAR.ptr);

        static foreach (IDX, A; ARGS) {{
            static if (__traits(hasMember, A, "toPrettyChars")) {
                printf("%s", args[IDX].toPrettyChars());
            }
            else static if (__traits(hasMember, A, "toChars")) {
                printf("%s", args[IDX].toChars());
            }
            else {
                write(args[IDX]);
            }
        }}

        writeln("");
    }


    private enum IsClass(alias A) = is(A == class);
    private enum IsDsymbol(alias A) = is(A : AST.Dsymbol);


    static void Inspect
        (string file = __FILE__, size_t line = __LINE__, ARGS...)
        (InterpolationHeader header, ARGS args, InterpolationFooter footer) {

        printf(TERM_COL.YELLOW.ptr);
        printf("INSPECT ");
        printf(TERM_COL.GREEN.ptr);
        write(i"$(file)($(line)) : ");

        printf(TERM_COL.CLEAR.ptr);

        static foreach (IDX, A; ARGS) {{

            static if (IsDsymbol!A) {
                printf(TERM_COL.LRED.ptr);
                write("[", A.stringof, "]");
                printf(TERM_COL.CLEAR.ptr);
            }

            static if (is(A == InterpolatedExpression!code, string code)) {
                printf(TERM_COL.CYAN.ptr);
                write(i"$(code) => ");
                printf(TERM_COL.CLEAR.ptr);
            }
            else static if (is(A == InterpolatedLiteral!str, string str)) {
                // write(i"[$(str)] ");
            }
            else static if (__traits(hasMember, A, "toPrettyChars")) {
                printf("%s", args[IDX].toPrettyChars());
            }
            else static if (__traits(hasMember, A, "toChars")) {
                printf("%s", args[IDX].toChars());
            }
            else {
                write(args[IDX]);
            }
        }}

        printf("\n");
    }


    static void InspectHard
        (string file = __FILE__, size_t line = __LINE__, ARGS...)
        (InterpolationHeader header, ARGS args, InterpolationFooter footer) {

        printf(TERM_COL.YELLOW.ptr);
        printf("INSPECT ");
        printf(TERM_COL.GREEN.ptr);
        write(i"$(file)($(line)) : ");

        printf(TERM_COL.CLEAR.ptr);

        static foreach (IDX, A; ARGS) {{

            static if (is(A == InterpolatedExpression!code, string code)) {
                printf(TERM_COL.CYAN.ptr);
                write(i"$(code) => ");
                printf(TERM_COL.CLEAR.ptr);
            }
            else static if (is(A == InterpolatedLiteral!str, string str)) {
                // write(i"[$(str)] ");
            }
            else static if (__traits(hasMember, A, "toPrettyChars")) {
                printf("%s", args[IDX].toPrettyChars());
            }
            else static if (__traits(hasMember, A, "toChars")) {
                printf("%s", args[IDX].toChars());
            }
            else {
                write(args[IDX]);
            }

            static if (IsDsymbol!A) {

                printf("\n");

                // if (auto ti = args[IDX].isTemplateInstance) {
                //     PrintDsymbol(ti);
                // }
                // else if (auto td = args[IDX].isTemplateDeclaration) {
                //     PrintDsymbol(td);
                // }
                // else if (auto tu = args[IDX].isTupleDeclaration) {
                //     PrintDsymbol(tu);
                // }
                // else {
                //     PrintDsymbol(args[IDX]);
                // }

                {

                    // NOTE:
                    //  [*] final
                    //  [-] abstract

                    // Module -> Package -> ...
                    if (auto dsym = args[IDX].isModule()) PrintDsymbol(dsym);
                    // Package -> ScopeDsymbol -> Dsymbol
                    else if (auto dsym = args[IDX].isPackage()) PrintDsymbol(dsym);
                    // EnumMember -> VarDeclaration -> Declaration -> Dsymbol
                    else if (auto dsym = args[IDX].isEnumMember()) PrintDsymbol(dsym);
                    // [*] TemplateDeclaration -> ScopeDsymbol -> Dsymbol
                    else if (auto dsym = args[IDX].isTemplateDeclaration()) PrintDsymbol(dsym);
                    // [*] TemplateMixin -> TemplateInstance -> ...
                    else if (auto dsym = args[IDX].isTemplateMixin()) PrintDsymbol(dsym);
                    //     TemplateInstance -> ScopeDsymbol -> Dsymbol
                    else if (auto dsym = args[IDX].isTemplateInstance()) PrintDsymbol(dsym);
                    // [*] ForwardingAttribDeclaration -> AttribDeclaration -> Dsymbol
                    else if (auto dsym = args[IDX].isForwardingAttribDeclaration) PrintDsymbol(dsym);
                    // [*] Nspace -> ScopeDsymbol -> Dsymbol
                    else if (auto dsym = args[IDX].isNspace()) PrintDsymbol(dsym);
                    //     StorageClassDeclaration -> AttribDeclaration -> Dsymbol
                    else if (auto dsym = args[IDX].isStorageClassDeclaration()) PrintDsymbol(dsym);
                    // [*] ExpressionDsymbol -> Dsymbol
                    else if (auto dsym = args[IDX].isExpressionDsymbol()) PrintDsymbol(dsym);
                    // [*] AliasAssign -> Dsymbol
                    else if (auto dsym = args[IDX].isAliasAssign()) PrintDsymbol(dsym);
                    // [*] ThisDeclaration -> VarDeclaration -> Declaration -> Dsymbol
                    else if (auto dsym = args[IDX].isThisDeclaration()) PrintDsymbol(dsym);
                    //     BitFieldDeclaration -> VarDeclaration -> Declaration -> Dsymbol
                    else if (auto dsym = args[IDX].isBitFieldDeclaration()) PrintDsymbol(dsym);
                    //     TypeInfoDeclaration -> VarDeclaration -> Declaration -> Dsymbol
                    else if (auto dsym = args[IDX].isTypeInfoDeclaration()) PrintDsymbol(dsym);
                    // [*]  TupleDeclaration-> Declaration -> Dsymbol
                    else if (auto dsym = args[IDX].isTupleDeclaration()) PrintDsymbol(dsym);
                    // [*] UnpackDeclaration -> AttribDeclaration -> Dsymbol
                    else if (auto dsym = args[IDX].isUnpackDeclaration()) PrintDsymbol(dsym);
                    // [*] AliasDeclaration-> Declaration -> Dsymbol
                    else if (auto dsym = args[IDX].isAliasDeclaration()) PrintDsymbol(dsym);
                    // [*] FuncAliasDeclaration -> FuncDeclaration -> Declaration -> Dsymbol
                    else if (auto dsym = args[IDX].isFuncAliasDeclaration()) PrintDsymbol(dsym);
                    // [*] OverDeclaration -> Declaration -> Dsymbol
                    else if (auto dsym = args[IDX].isOverDeclaration()) PrintDsymbol(dsym);
                    // [*] FuncLiteralDeclaration -> FuncDeclaration -> Declaration -> Dsymbol
                    else if (auto dsym = args[IDX].isFuncLiteralDeclaration()) PrintDsymbol(dsym);
                    // [*] CtorDeclaration -> FuncDeclaration -> Declaration -> Dsymbol
                    else if (auto dsym = args[IDX].isCtorDeclaration()) PrintDsymbol(dsym);
                    // [*] PostBlitDeclaration -> FuncDeclaration -> Declaration -> Dsymbol
                    else if (auto dsym = args[IDX].isPostBlitDeclaration()) PrintDsymbol(dsym);
                    // [*] DtorDeclaration -> FuncDeclaration -> Declaration -> Dsymbol
                    else if (auto dsym = args[IDX].isDtorDeclaration()) PrintDsymbol(dsym);
                    // [*]  StaticCtorDeclaration -> FuncDeclaration -> Declaration -> Dsymbol
                    else if (auto dsym = args[IDX].isStaticCtorDeclaration()) PrintDsymbol(dsym);
                    // [*]  StaticDtorDeclaration -> FuncDeclaration -> Declaration -> Dsymbol
                    else if (auto dsym = args[IDX].isStaticDtorDeclaration()) PrintDsymbol(dsym);
                    // [*]  SharedStaticCtorDeclaration -> FuncDeclaration -> Declaration -> Dsymbol
                    else if (auto dsym = args[IDX].isSharedStaticCtorDeclaration) PrintDsymbol(dsym);
                    // [*]  SharedStaticDtorDeclaration -> FuncDeclaration -> Declaration -> Dsymbol
                    else if (auto dsym = args[IDX].isSharedStaticDtorDeclaration) PrintDsymbol(dsym);
                    // [*] InvariantDeclaration -> FuncDeclaration -> Declaration -> Dsymbol
                    else if (auto dsym = args[IDX].isInvariantDeclaration()) PrintDsymbol(dsym);
                    // [*] UnitTestDeclaration -> FuncDeclaration -> Declaration -> Dsymbol
                    else if (auto dsym = args[IDX].isUnitTestDeclaration()) PrintDsymbol(dsym);
                    // [*] NewDeclaration -> FuncDeclaration -> Declaration -> Dsymbol
                    else if (auto dsym = args[IDX].isNewDeclaration()) PrintDsymbol(dsym);
                    //     FuncDeclaration -> Declaration -> Dsymbol
                    else if (auto dsym = args[IDX].isFuncDeclaration()) PrintDsymbol(dsym);
                    // [*] VersionSymbol -> Dsymbol
                    else if (auto dsym = args[IDX].isVersionSymbol()) PrintDsymbol(dsym);
                    // [*] DebugSymbol -> Dsymbol
                    else if (auto dsym = args[IDX].isDebugSymbol()) PrintDsymbol(dsym);
                    // [*] UnionDeclaration -> StructDeclaration -> AggregateDeclaration -> ScopeDsymbol -> Dsymbol
                    else if (auto dsym = args[IDX].isUnionDeclaration()) PrintDsymbol(dsym);
                    //     StructDeclaration -> AggregateDeclaration -> ScopeDsymbol -> Dsymbol
                    else if (auto dsym = args[IDX].isStructDeclaration()) PrintDsymbol(dsym);
                    // [*] InterfaceDeclaration -> ClassDeclaration -> AggregateDeclaration -> ScopeDsymbol -> Dsymbol
                    else if (auto dsym = args[IDX].isInterfaceDeclaration()) PrintDsymbol(dsym);
                    //     ClassDeclaration -> AggregateDeclaration -> ScopeDsymbol -> Dsymbol
                    else if (auto dsym = args[IDX].isClassDeclaration()) PrintDsymbol(dsym);
                    // [*] ForwardingScopeDsymbol -> ScopeDsymbol -> Dsymbol
                    else if (auto dsym = args[IDX].isForwardingScopeDsymbol()) PrintDsymbol(dsym);
                    // [*] WithScopeSymbol -> ScopeDsymbol -> Dsymbol
                    else if (auto dsym = args[IDX].isWithScopeSymbol()) PrintDsymbol(dsym);
                    // [*] ArrayScopeSymbol -> ScopeDsymbol -> Dsymbol
                    else if (auto dsym = args[IDX].isArrayScopeSymbol()) PrintDsymbol(dsym);
                    //     Import -> Dsymbol
                    else if (auto dsym = args[IDX].isImport()) PrintDsymbol(dsym);
                    // [*] EnumDeclaration -> ScopeDsymbol -> Dsymbol
                    else if (auto dsym = args[IDX].isEnumDeclaration()) PrintDsymbol(dsym);
                    // [*] SymbolDeclaration -> Declaration -> Dsymbol
                    else if (auto dsym = args[IDX].isSymbolDeclaration()) PrintDsymbol(dsym);
                    // [*] CPPNamespaceDeclaration -> AttribDeclaration -> Dsymbol
                    else if (auto dsym = args[IDX].isCPPNamespaceDeclaration()) PrintDsymbol(dsym);
                    // [*] VisibilityDeclaration -> AttribDeclaration -> Dsymbol
                    else if (auto dsym = args[IDX].isVisibilityDeclaration()) PrintDsymbol(dsym);
                    // [*] OverloadSet -> Dsymbol
                    else if (auto dsym = args[IDX].isOverloadSet()) PrintDsymbol(dsym);
                    // [*] MixinDeclaration -> AttribDeclaration -> Dsymbol
                    else if (auto dsym = args[IDX].isMixinDeclaration()) PrintDsymbol(dsym);
                    //     AggregateDeclaration -> ScopeDsymbol -> Dsymbol
                    else if (auto dsym = args[IDX].isAggregateDeclaration()) PrintDsymbol(dsym);
                    //     AnonDeclaration -> AttribDeclaration -> Dsymbol
                    else if (auto dsym = args[IDX].isAnonDeclaration()) PrintDsymbol(dsym);
                    // [*] StaticIfDeclaration -> ConditionalDeclaration -> AttribDeclaration -> Dsymbol
                    else if (auto dsym = args[IDX].isStaticIfDeclaration()) PrintDsymbol(dsym);
                    // [-] AttribDeclaration - > Dsymbol
                    else if (auto dsym = args[IDX].isAttribDeclaration()) PrintDsymbol(dsym);
                    // [*] StaticAssert -> Dsymbol
                    else if (auto dsym = args[IDX].isStaticAssert()) PrintDsymbol(dsym);
                    //    VarDeclaration -> Declaration -> Dsymbol
                    else if (auto dsym = args[IDX].isVarDeclaration()) PrintDsymbol(dsym);
                    // Declaration -> Dsymbol
                    else if (auto dsym = args[IDX].isDeclaration()) PrintDsymbol(dsym);
                    // ScopeDsymbol -> Dsymbol
                    else if (auto dsym = args[IDX].isScopeDsymbol()) PrintDsymbol(dsym);
                    // Dsymbol
                    else PrintDsymbol(args[IDX]);
                }

            }

        }}

        printf("\n");
    }




    private static bool IsDmdArray(ARR)() {

        static if (isPointer!ARR) {
            alias X = PointerTarget!ARR;
        }
        else {
            alias X = ARR;
        }


        return __traits(isSame, TemplateOf!(X), Array);
    }


    private static bool IsPrintWorthyIdent(string ident) {

        if (ident.length == 0) return false;
        if (ident[0] == '_') return false;

        if ("ddocUnittestHashTable" == ident) return false;


        return true;
    }


    enum IsUnitTestDeclaration(alias A) = is(A : UnitTestDeclaration);


    private static bool IsPrintWorthyType(T)() {

        static if (IsUnitTestDeclaration!T) return false;

        return true;
    }

    private static bool IsUnimplemented(T)() {

        import dmd.dsymbol;
        import dmd.statement;
        import dmd.func;

        enum IsStatement(alias A)        = is(A : Statement);
        enum IsDsymbolTable(alias A)     = is(A : DsymbolTable);
        enum IsReturnStatement(alias A)  = is(A : ReturnStatement);


        static if (IsStatement!T)        return true;
        static if (IsDsymbolTable!T)     return true;
        static if (IsReturnStatement!T)  return true;

        return false;
    }




    private static void PrintDsymbol(T)(ref T sym) if (IsDsymbol!T) {

        scope(exit) printf(TERM_COL.CLEAR.ptr);

        printf(TERM_COL.YELLOW.ptr);

        enum  SPACE = " ";
        enum int SLH = T.stringof.length / 2;

        printf("%-*s[%s]\n", (32 - SLH), SPACE.ptr, T.stringof.ptr);


        static foreach (IDX, M; __traits(allMembers, T)) {{

            printf(TERM_COL.CYAN.ptr);

            enum IsType = isType!(__traits(getMember, T, M));

            static if (IsType) {
                // enum X = "(" ~ T.stringof ~ "." ~ M ~ ")";
                // enum Y = "typeof(" ~ T.stringof ~ "." ~ M ~ ")";
                alias MT = void;
            }
            else {
                alias MT = typeof(__traits(getMember, T, M));

                static if (isPointer!MT) {
                    alias MT_D = PointerTarget!MT;
                }
                else {
                    alias MT_D = MT;
                }
            }

            static if (is(MT == void)) {

            }
            else static if (isFunction!MT) {
                // LoogAtMeSenpai!(__traits(getMember, TA, M), M, (DEPTH + 2), __MOD, __LINE);
            }
            else static if (IsType) {
                // LoogAtMeSenpai!(MT, TA.stringof, (DEPTH + 2), __MOD, __LINE);
                printf("[%s]\n", M.ptr);
            }
            else {

                static if (IsPrintWorthyType!(MT) && IsPrintWorthyIdent(M)) {

                    // type first
                    {
                        printf(TERM_COL.PINK.ptr);
                        printf("%*s | ", 32, MT.stringof.ptr);
                    }

                    printf(TERM_COL.CYAN.ptr);

                    // MT m = void;
                    // LoogAtMeSenpai!(m, M, (DEPTH + 2), __MOD, __LINE);
                    printf("%s = ", M.ptr);

                    printf(TERM_COL.CLEAR.ptr);
                    static if (isArray!MT) {
                        printf("[%llu]", __traits(getMember, sym, M).length);
                    }
                    else static if (isAssociativeArray!MT) {
                        printf("[%llu]", __traits(getMember, sym, M).length);
                    }
                    else static if (IsUnimplemented!MT) {
                        printf("???");
                    }
                    else static if (IsDmdArray!MT) {

                        static if (isPointer!MT) {

                            if (__traits(getMember, sym, M) !is null) {
                                if (__traits(getMember, sym, M).length) {
                                    printf("[");
                                    foreach (i, ref it; *__traits(getMember, sym, M)) {
                                        static if (IsUnimplemented!(typeof(it))) {
                                            write("?, ");
                                        }
                                        else {
                                            write(it, ", ");
                                        }

                                        if (i > 16) {
                                            write(it, ", ...");
                                            break;
                                        }

                                    }
                                    printf("]");
                                }
                            }
                            else {
                                printf("null");
                            }
                        }
                        else {

                            printf("[%llu]", __traits(getMember, sym, M).length);

                            if (__traits(getMember, sym, M).length) {
                                printf("[");
                                foreach (i, ref it; __traits(getMember, sym, M)) {
                                    write(it, ", ");
                                    if (i > 16) {
                                        write(it, ", ...");
                                        break;
                                    }
                                }
                                printf("]");
                            }
                        }


                    }
                    else static if (isPointer!MT) {
                        static if (is (MT_D == const(char))) {
                            printf(`"%s"`, __traits(getMember, sym, M));
                        }
                        else {
                            printf("[%p]", __traits(getMember, sym, M));
                        }
                    }
                    else {
                        write(__traits(getMember, sym, M));
                    }

                    // Type on new line
                    {
                        // printf("\n");
                        // printf(TERM_COL.PINK.ptr);
                        // printf("  {%s}", MT.stringof.ptr);
                    }

                    printf("\n");
                }


            }


        }}

    }

    // private static void PrintDsymbol(T)(T sym) if (IsDsymbol!T) {

    // }



}