(in-package #:abcl.test.lisp)

;;; EXPT returned a zero or one base unchanged, without float or complex
;;; contagion: (expt 0 2.0) was 0, (expt 1 2.0) was 1.

(deftest expt-contagion.zero-base
    ;; as ANSI EXPT.29: a zero to a positive power is (* zero power)
    (loop for x in '(0 0.0 0.0d0 #c(0.0 0.0) #c(0.0d0 0.0d0))
          append (loop for y in '(2 2.0 2.0d0 #c(2 2) #c(2 1/2) #c(2.0 0.5) #c(2.0d0 0.5d0))
                       unless (eql (* x y) (expt x y))
                         collect (list x y (expt x y))))
  nil)

(deftest expt-contagion.one-base
    (list (expt 1 2.0) (expt 1 2.0d0) (expt 1 3) (expt 1.0 3) (expt 1.0d0 2.0)
          (expt 1 #c(1.0 1.0)))
  (1.0 1.0d0 1 1.0 1.0d0 #c(1.0 0.0)))

(deftest expt-contagion.zero-base-error
    ;; "For all other values of x, 0^x is an error": a zero base to a
    ;; power whose real part is zero or negative.  Master returned 0.
    (loop for (x y) in '((0 -2) (0.0 -2.0) (0 -2.0) (0.0d0 -1) (0 #c(-1 1))
                         (0 #c(0 1)) (0.0 #c(0.0 2.0)) (#c(0.0 0.0) -1))
          collect (handler-case (list :no-error (expt x y))
                    (division-by-zero () :division-by-zero)))
  (:division-by-zero :division-by-zero :division-by-zero :division-by-zero
   :division-by-zero :division-by-zero :division-by-zero :division-by-zero))

(deftest expt-contagion.zero-power
    ;; a zero power is one of the contagion type, whatever the base
    (list (expt 0 0) (expt 0.0 0) (expt 0 0.0) (expt 0.0d0 0.0) (expt 2 0) (expt 2.0 0))
  (1 1.0 1.0 1.0d0 1 1.0))
