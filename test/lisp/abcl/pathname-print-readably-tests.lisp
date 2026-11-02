(in-package #:abcl.test.lisp)

;;; A pathname printed with *PRINT-READABLY* reads back as a similar
;;; pathname, or printing signals PRINT-NOT-READABLE (CLHS
;;; *PRINT-READABLY*; 3.2.4.2.2).  #P"a.b" was printed for the name "a.b"
;;; and read back as name "a", type "b"; #P".txt" for the type "txt"
;;; alone, read back as the name ".txt".

(defun print-readably-test-components (p)
  (list (pathname-host p) (pathname-device p) (pathname-directory p)
        (pathname-name p) (pathname-type p)))

(deftest pathname-print-readably.reads-back-or-refuses
    (loop for args in '((:type "txt") (:name "a.b") (:name ".emacs")
                        (:name "a" :type "b") (:name "a.b" :type "c")
                        (:directory (:absolute "tmp"))
                        (:directory (:relative "x" "y") :name "z"))
          for p = (apply #'make-pathname args)
          for text = (handler-case (let ((*print-readably* t)) (prin1-to-string p))
                       (print-not-readable () nil))
          unless (or (null text)
                     (equal (print-readably-test-components (read-from-string text))
                            (print-readably-test-components p)))
            collect (list args text))
  nil)

(deftest pathname-print-readably.namestring-kept
    ;; a pathname that reads back keeps its #P"" form
    (let ((*print-readably* t))
      (list (prin1-to-string (make-pathname :name "a" :type "b"))
            (prin1-to-string (make-pathname :directory '(:relative "x") :name "z"))))
  ("#P\"a.b\"" "#P\"x/z\""))

(deftest pathname-print-readably.truename
    ;; a truename's device is :UNSPECIFIC and its namestring parses back
    ;; with device NIL; both mean no device, so it still prints as #P""
    (let* ((p (truename (user-homedir-pathname)))
           (text (let ((*print-readably* t)) (prin1-to-string p))))
      (list (string= "#P" (subseq text 0 2))
            (equal (namestring (read-from-string text)) (namestring p))))
  (t t))

(deftest pathname-print-readably.unreadable-printing-unchanged
    ;; without *PRINT-READABLY*, the namestring as before
    (let ((*print-readably* nil))
      (prin1-to-string (make-pathname :name "a.b")))
  "#P\"a.b\"")
