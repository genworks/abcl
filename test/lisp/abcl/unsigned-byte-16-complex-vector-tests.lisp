(in-package #:abcl.test.lisp)

;;; An adjustable, fill-pointer or displaced vector of element type
;;; (UNSIGNED-BYTE 16) has that element type (CLHS 15.1.2.1: the upgraded
;;; element type is independent of adjustability, fill pointers and
;;; displacement).  ABCL had no such vector and made a ComplexVector, of
;;; element type T, that stored anything.  Under both allocation
;;; policies, NIO buffers (the default) and primitive arrays.

(defun ub16-vector-test-with-policy (policy thunk)
  (let ((old (java:jfield "org.armedbear.lisp.Java$Buffers" "active")))
    (unwind-protect
         (progn
           (setf (java:jfield "org.armedbear.lisp.Java$Buffers" "active")
                 (java:jfield "org.armedbear.lisp.Java$Buffers$AllocationPolicy" policy))
           (funcall thunk))
      (setf (java:jfield "org.armedbear.lisp.Java$Buffers" "active") old))))

(defun ub16-vector-test-vectors ()
  (let ((et '(unsigned-byte 16))
        (contents '(1 2 3 60000)))
    (list (cons :adjustable
                (make-array 4 :element-type et :adjustable t :initial-contents contents))
          (cons :fill-pointer
                (make-array 4 :element-type et :fill-pointer 4 :initial-contents contents))
          (cons :adjustable-fill-pointer
                (make-array 4 :element-type et :fill-pointer 4 :adjustable t
                              :initial-contents contents))
          (cons :displaced
                (make-array 4 :element-type et
                              :displaced-to (make-array 5 :element-type et
                                                          :initial-contents (cons 0 contents))
                              :displaced-index-offset 1))
          (cons :adjusted-to-displaced
                (adjust-array (make-array 2 :element-type et) 4
                              :displaced-to (make-array 4 :element-type et
                                                          :initial-contents contents))))))

(deftest unsigned-byte-16-vector.element-type
    (let ((wrong '()))
      (dolist (policy '("NIO" "PRIMITIVE_ARRAY") (nreverse wrong))
        (dolist (entry (ub16-vector-test-with-policy policy #'ub16-vector-test-vectors))
          (destructuring-bind (kind . v) entry
            (unless (and (equal (array-element-type v) '(unsigned-byte 16))
                         (typep v '(vector (unsigned-byte 16)))
                         (equal (coerce v 'list) '(1 2 3 60000)))
              (push (list policy kind (array-element-type v) (coerce v 'list)) wrong))))))
  nil)

(deftest unsigned-byte-16-vector.stores
    (let ((wrong '()))
      (dolist (policy '("NIO" "PRIMITIVE_ARRAY") (nreverse wrong))
        (dolist (entry (ub16-vector-test-with-policy policy #'ub16-vector-test-vectors))
          (destructuring-bind (kind . v) entry
            (setf (aref v 0) 65535)
            (let ((refused (loop for bad in (list 65536 -1 'a)
                                 collect (handler-case (progn (setf (aref v 1) bad) :stored)
                                           (type-error () :refused)))))
              (unless (and (eql (aref v 0) 65535) (eql (aref v 1) 2)
                           (equal refused '(:refused :refused :refused)))
                (push (list policy kind (aref v 0) (aref v 1) refused) wrong)))))))
  nil)

(deftest unsigned-byte-16-vector.displaced-writes-through
    (ub16-vector-test-with-policy
     "NIO"
     (lambda ()
       (let* ((target (make-array 4 :element-type '(unsigned-byte 16)))
              (v (make-array 2 :element-type '(unsigned-byte 16)
                               :displaced-to target :displaced-index-offset 2)))
         (setf (aref v 1) 777)
         (fill v 5)
         (multiple-value-bind (to offset) (array-displacement v)
           (list (coerce target 'list) (eq to target) offset)))))
  ((0 0 5 5) t 2))

(deftest unsigned-byte-16-vector.new-vectors
    ;; SUBSEQ, REVERSE, VECTOR-PUSH-EXTEND and ADJUST-ARRAY keep the type
    (let ((wrong '()))
      (dolist (policy '("NIO" "PRIMITIVE_ARRAY") (nreverse wrong))
        (let ((r (ub16-vector-test-with-policy
                  policy
                  (lambda ()
                    (let ((v (make-array 2 :element-type '(unsigned-byte 16)
                                           :fill-pointer 0 :adjustable t)))
                      (dotimes (i 5) (vector-push-extend (* 1000 i) v))
                      (let ((s (subseq v 1 3))
                            (r (reverse v))
                            (a (adjust-array v 7 :initial-element 9)))
                        (list (array-element-type s) (typep s 'simple-array) (coerce s 'list)
                              (array-element-type r) (typep r 'simple-array) (coerce r 'list)
                              (array-element-type a) (array-dimension a 0))))))))
          (unless (equal r '((unsigned-byte 16) t (1000 2000)
                             (unsigned-byte 16) t (4000 3000 2000 1000 0)
                             (unsigned-byte 16) 7))
            (push (list policy r) wrong)))))
  nil)
