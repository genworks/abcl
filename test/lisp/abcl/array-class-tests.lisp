(in-package #:abcl.test.lisp)

;;; The class named C and the type C hold the same objects (CLHS 4.3.8),
;;; for every standard array class and every kind of array.  An array of
;;; rank zero was of the type SIMPLE-ARRAY but not of the class: its
;;; CLASS-OF said ARRAY, adjustable or not.

(defparameter *array-class-names*
  '(array simple-array vector simple-vector string simple-string
    base-string simple-base-string bit-vector simple-bit-vector))

(defun array-class-test-arrays ()
  (let ((out '()))
    (dolist (et '(t bit character base-char (unsigned-byte 8) (unsigned-byte 16)
                  (unsigned-byte 32) (signed-byte 8) (signed-byte 32) fixnum
                  single-float double-float) (nreverse out))
      (dolist (dims '(() (3) (2 2) (2 2 2)))
        (push (make-array dims :element-type et) out)
        (push (make-array dims :element-type et :adjustable t) out)
        (push (make-array dims :element-type et
                               :displaced-to (make-array (reduce #'* dims)
                                                         :element-type et))
              out)
        (when (= (length dims) 1)
          (push (make-array dims :element-type et :fill-pointer 1) out))))))

(deftest array-class.class-and-type-agree
    (let ((wrong '()))
      (dolist (a (array-class-test-arrays) wrong)
        (dolist (c *array-class-names*)
          (unless (eq (not (typep a c)) (not (typep a (find-class c))))
            (push (list (array-dimensions a) (array-element-type a)
                        (adjustable-array-p a) c (class-name (class-of a)))
                  wrong)))))
  nil)

(deftest array-class.zero-rank
    (let ((simple (make-array '() :initial-element 1))
          (adjustable (make-array '() :initial-element 1 :adjustable t)))
      (list (class-name (class-of simple))
            (typep simple (find-class 'simple-array))
            (class-name (class-of adjustable))
            (typep adjustable (find-class 'simple-array))
            (typep adjustable (find-class 'array))))
  (simple-array t array nil t))

(defgeneric array-class-test-kind (x)
  (:method ((x array)) :array)
  (:method ((x simple-array)) :simple-array))

(deftest array-class.zero-rank-dispatch
    (list (array-class-test-kind (make-array '() :initial-element 1))
          (array-class-test-kind (make-array '() :initial-element 1 :adjustable t)))
  (:simple-array :array))
