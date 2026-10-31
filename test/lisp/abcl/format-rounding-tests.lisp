(in-package #:abcl.test.lisp)

;;; ~F and ~E with a digit count round the exact value of the float, not
;;; its shortest decimal digits.  Cutting those digits and rounding them
;;; again printed (format nil "~,6,,0e" 64.79735) -- the single-float
;;; 64.797348... -- as 0.647974e+2, and 9.999 at two digits as 10.0.  A
;;; mantissa that rounds up to the next power of ten moves into the
;;; exponent: 9.96 at one digit is 1.0e+1, not 10.e+0.  The ANSI test
;;; FORMAT.E.26 checks this rounding on random floats.

(defun format-rounding (control x)
  (let ((*read-default-float-format* 'single-float))
    (format nil control x)))

(deftest format-rounding.cases
    (mapcar (lambda (c) (format-rounding (first c) (second c)))
            '(("~,6,,0e" 64.79735) ("~,2f" 2.675) ("~,2f" 2.675d0) ("~,1f" 0.05)
              ("~,2f" 9.999) ("~,0f" 2.5) ("~,3e" 1.0) ("~,2e" 123456.0)
              ("~,1e" 9.96) ("~,2e" 9.996) ("~,1e" 0.0996) ("~,0e" 9.6)
              ("~,1,,2e" 9.96) ("~,1,,0e" 0.996) ("~9,2e" 9.996)
              ;; digits a scaled float got wrong, and an exponent taken
              ;; from the exact value (the single-float 1.0e-5 is just
              ;; below 1.0e-5) that disagreed with the digits
              ("~,7,,0e" 9.462335e-13) ("~,7,,0e" 5.6077955e12)
              ("~e" 1.0e-5) ("~,3e" 1.0e-5) ("~e" 1d-300)))
  ("0.647973e+2" "2.67" "2.67" "0.1"
   "10.00" "3." "1.000e+0" "1.23e+5"
   "1.0e+1" "1.00e+1" "1.0e-1" "1.e+1"
   "10.e+0" "0.1e+1" "  1.00e+1"
   "0.9462335e-12" "0.5607795e+13"
   "1.0e-5" "1.000e-5" "1.0d-300"))

(deftest format-rounding.padding-unchanged
    ;; Where the shortest digits already fit, zeros pad them as before,
    ;; rather than the float's full binary expansion.
    (list (format-rounding "~,2f" 1d23) (format-rounding "~,2f" 1e20)
          (format-rounding "~,4f" 1.37))
  ("100000000000000000000000.00" "100000000000000000000.00" "1.3700"))

(defun format-rounding-expected-f (x d)
  (multiple-value-bind (int frac)
      (floor (floor (+ (* (rational x) (expt 10 d)) 1/2)) (expt 10 d))
    (format nil "~d.~v,'0d" int d frac)))

(defun format-rounding-expected-e (x d)
  ;; ~,dE of positive X: one digit before the point, D after.
  (let* ((r (rational x))
         (e (floor (log x 10))))
    (loop while (>= r (* 10 (expt 10 e))) do (incf e))
    (loop while (< r (expt 10 e)) do (decf e))
    (let ((m (floor (+ (* (/ r (expt 10 e)) (expt 10 d)) 1/2))))
      (when (>= m (expt 10 (1+ d)))
        (setf m (floor (+ (/ m 10) 1/2)))
        (incf e))
      (multiple-value-bind (int frac) (floor m (expt 10 d))
        (format nil "~d.~v,'0de~:[+~;-~]~d" int d frac (minusp e) (abs e))))))

(defparameter *format-rounding-floats*
  (loop for i from 1 to 400
        collect (* (float i 1f0) 1.2917f0)
        collect (/ 7.31f0 (float i 1f0))))

(deftest format-rounding.f-sweep
    (let ((wrong '()))
      (dolist (x *format-rounding-floats*)
        (dolist (d '(1 2 3))
          (let ((control (format nil "~~,~df" d)))
            (unless (string= (format-rounding control x)
                             (format-rounding-expected-f x d))
              (push (list x d (format-rounding control x)) wrong)))))
      wrong)
  nil)

(deftest format-rounding.e-sweep
    (let ((wrong '()))
      (dolist (x *format-rounding-floats*)
        (dolist (d '(1 2 3 4))
          (let ((control (format nil "~~,~de" d)))
            (unless (string= (format-rounding control x)
                             (format-rounding-expected-e x d))
              (push (list x d (format-rounding control x)
                          (format-rounding-expected-e x d))
                    wrong)))))
      wrong)
  nil)
