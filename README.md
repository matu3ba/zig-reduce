# zig-reduce

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
