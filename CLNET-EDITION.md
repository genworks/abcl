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

Submitted upstream, performance:

| Change | Upstream |
|---|---|
| `EXT:COMPARE-AND-SWAP` on VarHandles (locks on Java 8): `car`, `cdr`, `svref`, `symbol-value`, `slot-value`, structure slots | PR #766, issue #92 |
| `LENGTH`, `ELT`, `SUBSEQ`, `REVERSE`, `NREVERSE` and `EVAL` compiled instead of interpreted | PR #768, issue #767 |
| `MAKE-INSTANCE` about twice as fast for standard classes | PR #770, issue #769 |
| Per-call frame marker without allocation or locking | PR #772, issue #771 |
| Closures made by top-level `DEFVAR`, `DEFPARAMETER`, `(SETF FDEFINITION)` and `(SETF GET)` compiled (babel's encoders among them: a UTF-8 round trip 225 times faster) | PR #775, issue #773 |
| Compiled `MAPCAR`/`MAPC` evaluate the function form once | PR #776, issue #774 |
| Loops kept compilable by HotSpot's on-stack replacement | PR #778, issue #777 |
| Direct slot reads under metaclasses that do not customize slot access | PR #780, issue #779 |
| `GETHASH` and `(SETF GETHASH)` compiled to a static call | PR #782, issue #781 |
| No shared cons counter: consing scales across threads; `TIME` reports the thread's bytes consed | PR #804, issue #803 |

Submitted upstream, correctness:

| Change | Upstream |
|---|---|
| An integer in fixnum range is a fixnum, from Java `BigInteger`s and from `Bignum` products alike | PR #786, issue #785 |
| `FLOAT-PRECISION` counts a denormalized float's significant digits; `DECODE-FLOAT`'s significand stays in [1/2, 1) for them | PR #788, issue #787 |
| `SCALE-FLOAT` by an exponent outside the format's range (`(scale-float least-positive-double-float 1074)` was infinity) | PR #790, issue #789 |
| `SUBTYPEP` no longer gives sure but wrong answers when `ATOM` is one of the types | PR #792, issue #791 |
| The pretty printer keeps a `LOOP` form's last element, and the space before a dotted tail | PR #794, issue #793 |
| `SUBTYPEP`: an unspecified array element type is within no specified one (`vector` was within `(vector t)`) | PR #796, issue #795 |
| `TYPEP`: an adjustable array is of no compound `SIMPLE-ARRAY` type | PR #798, issue #797 |
| Arrays of rank 0 and of rank 2 or more keep their element type (a 2-D bit array held NIL and stored any object) | PR #800, issue #799 |
| `TRUNCATE`, `FLOOR`, `CEILING`, `ROUND` of `most-negative-fixnum` by -1 no longer wrap | PR #802, issue #801 |

Offered upstream as tests and variants on another contributor's open
pull requests, which cover the same ground:

| Change | Upstream |
|---|---|
| `EXPT` applies contagion to a zero or one base; zero to a power with a non-positive real part signals `DIVISION-BY-ZERO` | on PR #747 |
| `~F` and `~E` round a float's exact value once; `~E`'s exponent marker is the one `PRIN1` uses | on PR #744 |
| A constant that cannot fit an unboxed place becomes a run-time type check (`(loop with (a b) of-type (fixnum fixnum) = ...)` compiles) | on PR #740 |

Not submitted:

| Change |
|---|
| `(THE type form)` checked inline for common types and structure types |
| A function's `OPTIMIZE` declarations no longer leak into the global policy when it is compiled with `(compile 'f)` |
| `(SETF accessor)` source transforms (DEFSTRUCT writers) and `(SETF name)` inline expansions found again |
| HotSpot's C1 compiler no longer refuses functions containing `HANDLER-CASE`, `IGNORE-ERRORS` or `RESTART-CASE` (helps warm-up only) |
| `PARSE-INTEGER` about 5 times faster |
| `FLOOR`, `CEILING`, `ROUND` and `REM` compiled to static calls, 4-10 times faster in tight loops |

Not yet submitted, to follow once upstream has worked through the
pull requests above (specialized arrays, under both of ABCL's
allocation policies, NIO buffers and Java arrays, new in
1.9.3-clnet.5; pathnames new in 1.9.3-clnet.6):

| Change |
|---|
| A simple array of rank 0 is of the class `SIMPLE-ARRAY` (`(typep #0A1 (find-class 'simple-array))` was false) |
| `ADJUST-ARRAY` accepts an array's own `:element-type` (`(unsigned-byte 8)`, 16 and 32 were refused) |
| `ADJUST-ARRAY` of a simple `(unsigned-byte 16)` or 32 vector to a new length no longer ends the thread with a Java `ArrayStoreException` |
| Arrays of `(unsigned-byte 8)`, 16 and 32 refuse integers out of range (256 was stored as 0) |
| `ADJUST-ARRAY` of a simple `(unsigned-byte 8)` or 32 vector to a displaced one keeps the element type (it became `T`) |
| `SUBSEQ` and `REVERSE` of an adjustable, fill-pointer or displaced byte vector keep its element type |
| Adjustable, fill-pointer and displaced `(unsigned-byte 16)` vectors (their element type was `T`, and they stored any object) |
| The places `ADJUST-ARRAY` and `VECTOR-PUSH-EXTEND` add to an adjustable `(unsigned-byte 32)` vector hold 0, not a Java null |
| `:BACK` in a directory is written `..` in a namestring (`(:relative :back)` made the namestring of the root) |
| A pathname printed readably reads back as itself, or printing signals `PRINT-NOT-READABLE` (`(make-pathname :name "a.b")` printed as `#P"a.b"`, which reads back with name `"a"` and type `"b"`) |

1.9.3-clnet.4 corrected two things 1.9.3-clnet.3 got wrong:
`DECODE-FLOAT` of a denormalized float returned a significand below
1/2, and `(format nil "~,0f" 9.000087e7)` printed `90000872.`.

Each change has its own tests in `test/lisp/abcl/`.  The edition passes
the same tests as `master` plus its own, and gives the same results on
the ANSI test suite run compiled, less the tests its changes fix.

## Building

As upstream: `ant` builds `dist/abcl.jar`.  Images built from this
branch are published as `clfoundation/abcl:1.9.3-clnet-*`; see
[cl-docker-images/abcl](https://gitlab.common-lisp.net/cl-docker-images/abcl).
