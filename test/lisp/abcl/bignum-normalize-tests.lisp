(in-package #:abcl.test.lisp)

;;; Bignum.getInstance(BigInteger) returns a fixnum for a value in fixnum
;;; range.  It used to return a Bignum for every value, so an integer that
;;; came from Java, or from SYS::%FLOAT-BITS, was neither EQL nor = to the
;;; same fixnum.

(defun java-big-integer (string)
  (java:jobject-lisp-value (java:jnew "java.math.BigInteger" string)))

(deftest bignum-normalize.from-java
    (loop for n in (list 0 5 -7 most-positive-fixnum most-negative-fixnum
                         (1+ most-positive-fixnum) (1- most-negative-fixnum)
                         (expt 10 30))
          for x = (java-big-integer (princ-to-string n))
          collect (list (eql x n) (= x n)
                        (eq (typep x 'fixnum) (typep n 'fixnum))))
  ((t t t) (t t t) (t t t) (t t t) (t t t) (t t t) (t t t) (t t t)))

(deftest bignum-normalize.lookups
    (let ((x (java-big-integer "5"))
          (table (make-hash-table)))
      (setf (gethash 5 table) :five)
      (list (gethash x table)
            (case x (5 :five) (t :other))
            (member x '(4 5 6))))
  (:five :five (5 6)))

(deftest bignum-normalize.float-bits
    (list (eql (sys::%float-bits 1.0f0) 1065353216)
          (eql (sys::%float-bits -1.0f0) -1082130432)
          (typep (sys::%float-bits 1.0f0) 'fixnum)
          (eql (sys::%float-bits 1d0) 4607182418800017408))
  (t t t t))
