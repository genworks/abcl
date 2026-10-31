(in-package #:abcl.test.lisp)

;;; PARSE-INTEGER scans in Java (SYS::%PARSE-INTEGER).  These compare it
;;; with the Lisp scan it replaced, kept here as the reference, over
;;; whitespace, signs, radixes, bounds, JUNK-ALLOWED, the fixnum and
;;; 64-bit boundaries, non-ASCII digits and non-simple strings.

(defun reference-parse-integer (string &key (start 0) end (radix 10) junk-allowed)
  (when (null end)
    (setq end (length string)))
  (flet ((fail () (error 'parse-error)))
    (let ((index (do ((i start (1+ i)))
                     ((= i end)
                      (if junk-allowed
                          (return-from reference-parse-integer (values nil end))
                          (fail)))
                   (unless (sys::whitespacep (char string i)) (return i))))
          (minusp nil)
          (found-digit nil)
          (result 0))
      (let ((char (char string index)))
        (cond ((char= char #\-) (setq minusp t) (incf index))
              ((char= char #\+) (incf index))))
      (loop
        (when (= index end) (return nil))
        (let* ((char (char string index))
               (weight (digit-char-p char radix)))
          (cond (weight
                 (setq result (+ weight (* result radix))
                       found-digit t))
                (junk-allowed (return nil))
                ((sys::whitespacep char)
                 (do () ((= (setq index (1+ index)) end))
                   (unless (sys::whitespacep (char string index))
                     (fail)))
                 (return nil))
                (t (fail))))
        (incf index))
      (values (if found-digit
                  (if minusp (- result) result)
                  (if junk-allowed nil (fail)))
              index))))

(defun parse-integer-outcome (function string &rest keys)
  (handler-case (multiple-value-list (apply function string keys))
    (parse-error () :parse-error)
    (type-error () :type-error)))

(defparameter *parse-integer-strings*
  (let ((tab (string #\Tab)) (nl (string #\Newline)))
    (list "" " " "  " "0" "-0" "+0" "-" "+" "+-1" "--1" "1" "-1" "+1"
          "12345" " 12345 " (concatenate 'string tab "42" nl) "12 3" "12x"
          "x12" "1 x" "  -77  " "007"
          "2147483647" "2147483648" "-2147483648" "-2147483649"
          "9223372036854775807" "9223372036854775808" "-9223372036854775808"
          "-9223372036854775809" "92233720368547758070"
          "123456789012345678901234567890" "-123456789012345678901234567890"
          "ff" "FF" "zz" "Zz" "7fffffff" "80000000" "ffffffffffffffff"
          "10000000000000000" "1010" "102"
          (coerce (list (code-char #x661) (code-char #x662)) 'string) ; Arabic-Indic 1 2
          (coerce (list (code-char #xFF11) (code-char #xFF10)) 'string) ; fullwidth 1 0
          (coerce (list #\1 (code-char #xA0) #\2) 'string))))

(deftest parse-integer.matches-reference
    (let ((mismatches '()))
      (dolist (string *parse-integer-strings*)
        (dolist (radix '(2 8 10 16 36))
          (dolist (junk '(nil t))
            (let ((len (length string)))
              (dolist (bounds (list '() (list :start (min 1 len))
                                    (list :end (max 0 (1- len)))
                                    (list :start (min 1 len) :end (max (min 1 len) (1- len)))))
                (let* ((keys (list* :radix radix :junk-allowed junk bounds))
                       (new (apply #'parse-integer-outcome #'parse-integer string keys))
                       (old (apply #'parse-integer-outcome #'reference-parse-integer string keys)))
                  (unless (equal new old)
                    (push (list string keys new old) mismatches))))))))
      mismatches)
  nil)

(deftest parse-integer.non-simple-strings
    (let* ((base "xx-4096yy")
           (displaced (make-array 5 :element-type 'character
                                    :displaced-to base :displaced-index-offset 2))
           (filled (make-array 9 :element-type 'character :initial-contents "  31 junk"
                                 :fill-pointer 4)))
      (list (multiple-value-list (parse-integer displaced))
            (multiple-value-list (parse-integer filled))
            (multiple-value-list (parse-integer base :start 2 :end 7))))
  ((-4096 5) (31 4) (-4096 7)))

(deftest parse-integer.argument-errors
    (flet ((outcome (thunk)
             (handler-case (progn (funcall thunk) :no-error)
               (type-error () :type-error)
               (program-error () :program-error)
               (parse-error () :parse-error))))
      (list (outcome (lambda () (parse-integer 'abc)))
            (outcome (lambda () (parse-integer "12" :radix 37)))
            (outcome (lambda () (parse-integer "12" :radix 1)))
            (outcome (lambda () (parse-integer "123" :start 5)))
            (outcome (lambda () (parse-integer "123" :end 9)))
            (outcome (lambda () (parse-integer "123" :start 2 :end 1)))
            (outcome (lambda () (parse-integer "12" :foo 1)))
            (outcome (lambda () (parse-integer "12" :foo 1 :allow-other-keys t)))))
  (:type-error :type-error :type-error :type-error :type-error :type-error
   :program-error :no-error))
