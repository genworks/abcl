(in-package #:abcl.test.lisp)

;;; A constant compiled into an unboxed (:int, :long, :float, :double)
;;; place that it does not fit stopped the compiler: LOOP's destructuring
;;; gives each typed variable an initial value (IF ... (CAR ...) NIL), and
;;; the unreachable NIL could not be compiled as a fixnum.  Such a constant
;;; now signals a TYPE-ERROR at run time, if it is ever reached.

(deftest unboxed-constant.loop-destructuring
    (list (funcall (compile nil '(lambda ()
                                  (loop with (a b) of-type (fixnum fixnum) = '(3 4)
                                        return (+ a b)))))
          (funcall (compile nil '(lambda ()
                                  (loop with (x y) of-type (double-float double-float)
                                          = '(1d0 2d0)
                                        return (+ x y)))))
          (funcall (compile nil '(lambda ()
                                  (loop for (a b) of-type (fixnum fixnum) in '((1 2) (3 4))
                                        sum (* a b))))))
  (7 3d0 14))

(deftest unboxed-constant.reached-signals
    ;; The declaration is violated, and the violation is caught at run time.
    (let ((f (compile nil '(lambda (x)
                            (let ((a (if x 1 nil)))
                              (declare (fixnum a))
                              (+ a 1))))))
      (list (funcall f t)
            (handler-case (funcall f nil) (type-error () :type-error))))
  (2 :type-error))

(deftest unboxed-constant.double
    (let ((f (compile nil '(lambda (x)
                            (let ((d (if x 2.5d0 'none)))
                              (declare (double-float d))
                              (* d 2))))))
      (list (funcall f t)
            (handler-case (funcall f nil) (type-error () :type-error))))
  (5d0 :type-error))
