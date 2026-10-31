# ABCL, common-lisp.net edition

This branch is Armed Bear Common Lisp's `master` with a set of
performance and correctness changes merged in, built and published by
common-lisp.net while they wait for review upstream.  It is not an
official ABCL release: report problems with these changes here, and
everything else to [armedbear/abcl](https://github.com/armedbear/abcl).

`(lisp-implementation-version)` reports `1.9.3-clnet.N`.  Each change
is a branch off upstream `master`, merged here unchanged except for
conflicts in the test lists; when upstream merges or refuses one, it is
dropped from the next edition.

## Changes

Submitted upstream:

| Change | Upstream |
|---|---|
| `EXT:COMPARE-AND-SWAP` on VarHandles (locks on Java 8): `car`, `cdr`, `svref`, `symbol-value`, `slot-value`, structure slots | PR #766, issue #92 |
| `LENGTH`, `ELT`, `SUBSEQ`, `REVERSE`, `NREVERSE` and `EVAL` compiled instead of interpreted | PR #768, issue #767 |
| `MAKE-INSTANCE` about twice as fast for standard classes | PR #770, issue #769 |
| Per-call frame marker without allocation or locking | PR #772, issue #771 |
| Closures made by top-level `DEFVAR`, `DEFPARAMETER`, `(SETF FDEFINITION)` and `(SETF GET)` compiled | PR #775, issue #773 |
| Compiled `MAPCAR`/`MAPC` evaluate the function form once | PR #776, issue #774 |
| Loops kept compilable by HotSpot's on-stack replacement | PR #778, issue #777 |
| Direct slot reads under metaclasses that do not customize slot access | PR #780, issue #779 |
| `GETHASH` and `(SETF GETHASH)` compiled to a static call | PR #782, issue #781 |

Not yet submitted:

| Change |
|---|
| `(THE type form)` checked inline for common types and structure types |
| A function's `OPTIMIZE` declarations no longer leak into the global policy when it is compiled with `(compile 'f)` |
| `(SETF accessor)` source transforms (DEFSTRUCT writers) and `(SETF name)` inline expansions found again |
| HotSpot's C1 compiler no longer refuses functions containing `HANDLER-CASE`, `IGNORE-ERRORS` or `RESTART-CASE` |
| No shared cons counter: consing scales across threads; `TIME` reports bytes consed |
| `PARSE-INTEGER` about 5 times faster |
| Integers in fixnum range converted from Java `BigInteger`s are fixnums (were neither `EQL` nor `=` to the same fixnum) |
| `FLOOR`, `CEILING`, `ROUND` and `REM` compiled to static calls, 4-10 times faster; `TRUNCATE` of `most-negative-fixnum` by -1 no longer wraps (added in 1.9.3-clnet.2) |

Each change has its own tests in `test/lisp/abcl/`.  The edition passes
the same tests as `master` plus its own, and gives the same results on
the ANSI test suite run compiled.

## Building

As upstream: `ant` builds `dist/abcl.jar`.  Images built from this
branch are published as `clfoundation/abcl:1.9.3-clnet-*`; see
[cl-docker-images/abcl](https://gitlab.common-lisp.net/cl-docker-images/abcl).
