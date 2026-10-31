(in-package #:abcl.test.lisp)

;;; DEFSTRUCT defines a source transform for each writer, (SETF ACCESSOR),
;;; which compiled code applies instead of calling the setf function.
;;; A transform for a (SETF NAME) was never found until it was kept on
;;; NAME's plist; these check the compiled writers' behavior.

(defstruct ss-object a (b 0 :type fixnum))
(defstruct (ss-sub (:include ss-object)) c)
(defstruct (ss-vector (:type vector)) a b)
(defstruct (ss-list (:type list)) a b)

(deftest struct-setf.transform-registered
    (list (and (sys::source-transform '(setf ss-object-a)) t)
          (and (sys::source-transform '(setf ss-vector-a)) t))
  (t t))

(deftest struct-setf.compiled-writers
    (let ((write (compile nil '(lambda (o s v l)
                                (list (setf (ss-object-a o) :a)
                                      (setf (ss-object-b o) 7)
                                      (setf (ss-object-a s) :inherited)
                                      (setf (ss-sub-c s) :c)
                                      (setf (ss-vector-b v) :vb)
                                      (setf (ss-list-b l) :lb)
                                      (incf (ss-object-b o)))))))
      (let ((o (make-ss-object))
            (s (make-ss-sub))
            (v (make-ss-vector))
            (l (make-ss-list)))
        (list (funcall write o s v l)
              (list (ss-object-a o) (ss-object-b o))
              (list (ss-sub-a s) (ss-sub-c s))
              (ss-vector-b v)
              (ss-list-b l))))
  ((:a 7 :inherited :c :vb :lb 8) (:a 8) (:inherited :c) :vb :lb))

(deftest struct-setf.wrong-structure
    ;; The transform keeps the writer's check of the instance's type.
    (let ((write (compile nil '(lambda (x) (setf (ss-sub-c x) 1)))))
      (handler-case (progn (funcall write (make-ss-object)) :no-error)
        (error () :error)))
  :error)

;;; The inline expansion of a (SETF NAME) function is kept too.
(deftest struct-setf.setf-inline-expansion-kept
    (progn
      (setf (sys::inline-expansion '(setf ss-inline-test)) '(lambda (v x) (setf (car x) v)))
      (equal (sys::inline-expansion '(setf ss-inline-test))
             '(lambda (v x) (setf (car x) v))))
  t)
