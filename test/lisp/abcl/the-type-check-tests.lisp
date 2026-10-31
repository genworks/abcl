(in-package #:abcl.test.lisp)

;;; At SAFETY 1 and 2, (THE type form) for the types in
;;; JVM::*INLINE-CHECKED-TYPES* is checked inline (an instanceof or a
;;; virtual predicate) rather than through REQUIRE-TYPE.  Each such check
;;; must accept exactly the objects TYPEP accepts.

(defun compile-at-safety-1 (lambda-expression)
  "Compile LAMBDA-EXPRESSION at SAFETY 1 whatever the global policy, which
other tests may have changed."
  (destructuring-bind (lambda lambda-list &rest body) lambda-expression
    (compile nil `(,lambda ,lambda-list
                    (declare (optimize (safety 1)))
                    ,@body))))

(defstruct the-check-struct a)

(defun the-check-objects ()
  (list nil t :keyword 'symbol (make-symbol "U")
        0 1 -1 most-positive-fixnum most-negative-fixnum
        (1+ most-positive-fixnum) (1- most-negative-fixnum) (expt 2 100)
        1/2 -3/4 1.5f0 -0.0f0 1.5d0 -0.0d0 #c(1 2) #c(1.0 2.0)
        #\a #\Space (code-char 955)
        (list 1) (cons 1 2) '(1 2 3)
        (vector) (vector 1 2)
        (make-array 3 :adjustable t)
        (make-array 3 :fill-pointer 2)
        (make-array 3 :element-type 'double-float :initial-element 0d0)
        "" "abc" (make-string 2 :initial-element #\b)
        (make-array 3 :element-type 'character :adjustable t
                      :initial-element #\c)
        (make-array 3 :element-type 'character :fill-pointer 1
                      :initial-element #\d)
        #*101 (make-hash-table) (make-the-check-struct)
        #'car (lambda (x) x) *standard-output* (find-class 'cons)))

(deftest the.inline-checks.agree-with-typep
    (let ((mismatches '()))
      (dolist (type jvm::*inline-checked-types*)
        (let ((check (compile-at-safety-1 `(lambda (x)
                                     (declare (optimize (safety 1)))
                                     (the ,type x)
                                     t))))
          (dolist (object (the-check-objects))
            (let ((passes (handler-case (funcall check object)
                            (type-error () nil))))
              (unless (eq (and passes t) (and (typep object type) t))
                (push (list type object) mismatches))))))
      mismatches)
  nil)

(deftest the.inline-checks.type-error
    (let ((check (compile-at-safety-1 '(lambda (x) (the double-float x)))))
      (handler-case (progn (funcall check 1) :no-error)
        (type-error (e)
          (list (type-error-datum e) (type-error-expected-type e)))))
  (1 double-float))

(deftest the.inline-checks.value
    (let ((f (compile-at-safety-1 '(lambda (c) (+ (the double-float (car c)) 1d0)))))
      (list (funcall f (list 1.5d0))
            (handler-case (funcall f (list 1)) (type-error () :type-error))))
  (2.5d0 :type-error))

(defstruct the-check-fixnum-slot (n 0 :type fixnum))

(deftest the.inline-checks.fixnum-structure-slot
    ;; (the fixnum (structure-ref ...)) still checks when the value is
    ;; wanted boxed.
    (let ((s (make-the-check-fixnum-slot))
          (f (compile-at-safety-1 '(lambda (s) (list (the fixnum (sys:structure-ref s 0)))))))
      (setf (sys:structure-ref s 0) :not-a-fixnum)
      (handler-case (progn (funcall f s) :no-error)
        (type-error () :type-error)))
  :type-error)

;;; DERIVE-TYPE took a parameter or a MULTIPLE-VALUE-BIND variable that
;;; is never assigned to be of type NULL, from its absent INITFORM, so a
;;; check against a type containing NIL was dropped.
(deftest the.inline-checks.untyped-variables
    (list (handler-case (funcall (compile-at-safety-1 '(lambda (x) (the symbol x))) 0)
            (type-error () :type-error))
          (handler-case (funcall (compile-at-safety-1 '(lambda (x) (the list x))) 0)
            (type-error () :type-error))
          (handler-case (funcall (compile-at-safety-1 '(lambda (v)
                                                (multiple-value-bind (a) (values v)
                                                  (the list a))))
                                 0)
            (type-error () :type-error))
          (funcall (compile-at-safety-1 '(lambda (x) (the list x))) nil))
  (:type-error :type-error :type-error nil))

;;; A structure class name is checked inline too (DEFSTRUCT accessors
;;; wrap their instance in (THE name instance)), including instances of
;;; a structure that :INCLUDEs it.
(defstruct (the-check-sub-struct (:include the-check-struct)) b)
(defstruct the-check-other-struct c)

(deftest the.inline-checks.structure-types
    (let ((mismatches '())
          (objects (list* (make-the-check-sub-struct)
                          (make-the-check-other-struct)
                          (the-check-objects))))
      (dolist (type '(the-check-struct the-check-sub-struct the-check-other-struct))
        (let ((check (compile-at-safety-1 `(lambda (x) (the ,type x) t))))
          (dolist (object objects)
            (let ((passes (handler-case (funcall check object)
                            (type-error () nil))))
              (unless (eq (and passes t) (and (typep object type) t))
                (push (list type object) mismatches))))))
      mismatches)
  nil)
