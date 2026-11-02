(in-package #:abcl.test.lisp)

;;; :BACK in a directory is written ".." in the namestring, as :UP is
;;; (CLHS 19.2.2.4.3); it wrote nothing, so (:RELATIVE :BACK) gave a
;;; namestring of the root, an absolute directory.

(deftest pathname-namestring-back.relative
    (let ((p (make-pathname :directory '(:relative :back) :name "z")))
      (list (namestring p)
            (first (pathname-directory (pathname (namestring p))))))
  ("../z" :relative))

(deftest pathname-namestring-back.inner
    (namestring (make-pathname :directory '(:absolute "a" :back "b") :name "z"))
  "/a/../b/z")

(deftest pathname-namestring-back.up-unchanged
    (namestring (make-pathname :directory '(:relative :up "b") :name "z"))
  "../b/z")
