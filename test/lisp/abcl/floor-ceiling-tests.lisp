(in-package #:abcl.test.lisp)

;;; Compiled FLOOR, CEILING, ROUND and REM call static methods that divide
;;; two fixnums themselves and hand everything else to the functions.
;;; These compare compiled calls with the functions called through
;;; FUNCALL.

(defparameter *floor-ceiling-numbers*
  (list 0 1 -1 2 -2 6 -6 7 -7 13 -13 100 -100
        most-positive-fixnum most-negative-fixnum
        (1+ most-positive-fixnum) (1- most-negative-fixnum)
        (expt 10 20) (- (expt 10 20))
        1/3 -7/2 2.5 -2.5f0 7.25d0 -7.25d0))

(defparameter *floor-ceiling-divisors*
  (list 1 -1 2 -2 3 -3 7 -7 most-positive-fixnum most-negative-fixnum
        (expt 10 10) 1/2 -2/3 0.5 -1.5d0))

(deftest floor-ceiling.compiled-matches-primitive
    (let ((compiled (compile nil '(lambda (n d)
                                   (list (multiple-value-list (floor n d))
                                         (multiple-value-list (ceiling n d))
                                         (multiple-value-list (round n d))
                                         (floor n d)
                                         (ceiling n d)
                                         (round n d)
                                         (multiple-value-list (rem n d))))))
          (mismatches '()))
      (dolist (n *floor-ceiling-numbers*)
        (dolist (d *floor-ceiling-divisors*)
          (let ((expected (list (multiple-value-list (funcall #'floor n d))
                                (multiple-value-list (funcall #'ceiling n d))
                                (multiple-value-list (funcall #'round n d))
                                (funcall #'floor n d)
                                (funcall #'ceiling n d)
                                (funcall #'round n d)
                                (multiple-value-list (funcall #'rem n d))))
                (actual (funcall compiled n d)))
            (unless (equal expected actual)
              (push (list n d expected actual) mismatches)))))
      mismatches)
  nil)

(deftest floor-ceiling.fixnum-signs
    (funcall (compile nil '(lambda ()
                            (loop for (n d) in '((7 2) (-7 2) (7 -2) (-7 -2) (6 3) (-6 3)
                                                 (0 5) (-2147483648 -1) (-2147483648 1))
                                  collect (list (multiple-value-list (floor n d))
                                                (multiple-value-list (ceiling n d)))))))
  (((3 1) (4 -1)) ((-4 1) (-3 -1)) ((-4 -1) (-3 1)) ((3 -1) (4 1))
   ((2 0) (2 0)) ((-2 0) (-2 0)) ((0 0) (0 0))
   ((2147483648 0) (2147483648 0)) ((-2147483648 0) (-2147483648 0))))

(deftest floor-ceiling.round-ties-to-even
    (funcall (compile nil '(lambda ()
                            (loop for (n d) in '((5 2) (7 2) (-5 2) (-7 2) (5 -2) (-7 -2)
                                                 (1 3) (2 3) (-2 3) (6 4) (10 4))
                                  collect (multiple-value-list (round n d))))))
  ((2 1) (4 -1) (-2 -1) (-4 1) (-2 1) (4 1)
   (0 1) (1 -1) (-1 1) (2 -2) (2 2)))

(deftest floor-ceiling.one-argument
    (funcall (compile nil '(lambda (x)
                            (list (multiple-value-list (floor x))
                                  (multiple-value-list (ceiling x)))))
             -7/2)
  ((-4 1/2) (-3 -1/2)))

(deftest floor-ceiling.mvb
    (funcall (compile nil '(lambda (n d)
                            (multiple-value-bind (q r) (floor n d)
                              (multiple-value-bind (cq cr) (ceiling n d)
                                (list q r cq cr)))))
             -17 5)
  (-4 3 -3 -2))

(deftest floor-ceiling.division-by-zero
    (let ((f (compile nil '(lambda (n d) (floor n d))))
          (c (compile nil '(lambda (n d) (ceiling n d)))))
      (list (handler-case (funcall f 1 0) (division-by-zero () :division-by-zero))
            (handler-case (funcall c 1 0) (division-by-zero () :division-by-zero))))
  (:division-by-zero :division-by-zero))
