# zig-reduce

As of now, it is unfeasible to not upstream this tool, because
- 1. we want to only render necessary parts
- 2. we dont want to reimplement or have effort to track upstream to get proper rendering,
     which is also used by the formatter.
- 3. only rendering necessary parts is relative non-invasive
     (1 comptime-optional check+datastructure before each big switch prong on the AST tag)
- 4. An iterative reimplementation would be complex with alot more state handling in
     each switch prong.
- 3. AstGen.zig contains the usability check and we want to use all possible checks
     to not being forced to write to the slow disk.
- 4. Libstd is missing basic combinatorics and graph processing.

The motivation for this tool is to bisect error sources from incorrect C codegen
in well defined test cases.
The scope is intentionally limited to keep it as basic building block for more
complex machinery once the "official lsp/repl" as query system is provided.

Hopefully, the approach is generally enough that it can be widely reused
for strongly typed languages and test systems with parser(s).
However, this would be only a nice-to-have.

phase 1: remove test blocks + related code to reproduce expected error code + output
- [ ] get AST
- [ ] get positions of all references, test blocks
- [ ] remove references, blocks
- [ ] compute, if references are still used in current file
- [ ] rollback logic to continue with next bisect
- [ ] statistics + keeping track of things for good efficiency
- [ ] Goal selection:
      * 1. Stop on first result.
      * 2. Return all results.
      * 3. Return all results.
      * 4. Print statistics + allow user to select timeout +

phase 2: deferred after results. again, reproduce expected error code + output
- open questions
  * Can we generalize anything to identify meaningful content to remove?
    - would be useful to speed things up
    - sounds very hard for codegen things
  * How do we interact with git bisecting, build system, external scripts?

Non-Goals
- Analyze transitive references. Keep test structure simple, dummie.
- Modifying stuff not in user-provided file. Developer can interact.
- Try to do things based on AST. Lsps were build for this.
