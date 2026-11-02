(in-package #:abcl.test.lisp)

;;; ADJUST-ARRAY of a simple specialized vector with :DISPLACED-TO keeps
;;; the vector's element type (CLHS 15.1.2.1, ADJUST-ARRAY); for
;;; (UNSIGNED-BYTE 8) and 32 it made a plain ComplexVector, element type
;;; T.  Under both allocation policies, NIO buffers (the default) and
;;; primitive arrays.

(defun displaced-adjust-test-with-policy (policy thunk)
  (let ((old (java:jfield "org.armedbear.lisp.Java$Buffers" "active")))
    (unwind-protect
         (progn
           (setf (java:jfield "org.armedbear.lisp.Java$Buffers" "active")
                 (java:jfield "org.armedbear.lisp.Java$Buffers$AllocationPolicy" policy))
           (funcall thunk))
      (setf (java:jfield "org.armedbear.lisp.Java$Buffers" "active") old))))

(deftest displaced-adjust.element-type
    (let ((wrong '()))
      (dolist (policy '("NIO" "PRIMITIVE_ARRAY") (nreverse wrong))
        (dolist (case '(((unsigned-byte 8) 1 2 3 4 200)
                        ((unsigned-byte 32) 1 2 3 4 4000000000)
                        (bit 0 1 0 1 1)
                        (character #\a #\b #\c #\d #\z)
                        (t a b c d z)))
          (destructuring-bind (et e0 e1 e2 e3 new) case
            (let ((r (displaced-adjust-test-with-policy
                      policy
                      (lambda ()
                        (let* ((target (make-array 4 :element-type et
                                                     :initial-contents (list e0 e1 e2 e3)))
                               (v (adjust-array (make-array 4 :element-type et) 3
                                                :displaced-to target
                                                :displaced-index-offset 1)))
                          (setf (aref v 0) new)
                          (list (equal (array-element-type v)
                                       (upgraded-array-element-type et))
                                (coerce v 'list)
                                (aref target 1)
                                (multiple-value-list (array-displacement v))))))))
              (unless (and (first r)
                           (equal (second r) (list new e2 e3))
                           (eql (third r) new)
                           (eql (second (fourth r)) 1))
                (push (list policy et r) wrong)))))))
  nil)
