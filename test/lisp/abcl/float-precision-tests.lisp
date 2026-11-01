(in-package #:abcl.test.lisp)

;;; FLOAT-PRECISION is less than FLOAT-DIGITS for a denormalized float
;;; (CLHS FLOAT-DIGITS); it returned 24 or 53 for every nonzero float.

(deftest float-precision.normalized
    (mapcar #'float-precision
            (list 1.0 -2.5 least-positive-normalized-single-float
                  most-positive-single-float 1d0 least-positive-normalized-double-float))
  (24 24 24 24 53 53))

(deftest float-precision.denormalized
    (mapcar #'float-precision
            (list least-positive-single-float (* 6 least-positive-single-float)
                  (* 3 least-positive-single-float) 5.77921e-40
                  least-positive-double-float 1.870987d-318
                  (- least-positive-double-float)))
  (1 3 2 19 1 19 1))

(deftest float-precision.zero
    (mapcar #'float-precision (list 0.0 -0.0 0d0))
  (0 0 0))

(deftest float-precision.denormalized-below-digits
    ;; every denormal power of two, single and double
    (list (loop for i from 0 below 23
                for x = (* least-positive-single-float (expt 2 i))
                unless (= (float-precision x) (1+ i)) collect i)
          (loop for i from 0 below 52
                for x = (* least-positive-double-float (expt 2 i))
                unless (= (float-precision x) (1+ i)) collect i))
  (nil nil))
