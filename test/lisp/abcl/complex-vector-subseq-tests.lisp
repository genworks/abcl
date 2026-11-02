(in-package #:abcl.test.lisp)

;;; SUBSEQ of a vector is a fresh simple array of rank one with the same
;;; actual array element type (CLHS SUBSEQ); COPY-SEQ and REVERSE alike.
;;; Of an adjustable, fill-pointer or displaced (UNSIGNED-BYTE 8) or 32
;;; vector, SUBSEQ (and REVERSE, for 32) made a vector of element type T.
;;; Under both allocation policies, NIO buffers (the default) and
;;; primitive arrays.

(defun subseq-test-with-policy (policy thunk)
  (let ((old (java:jfield "org.armedbear.lisp.Java$Buffers" "active")))
    (unwind-protect
         (progn
           (setf (java:jfield "org.armedbear.lisp.Java$Buffers" "active")
                 (java:jfield "org.armedbear.lisp.Java$Buffers$AllocationPolicy" policy))
           (funcall thunk))
      (setf (java:jfield "org.armedbear.lisp.Java$Buffers" "active") old))))

(defun subseq-test-vectors (et contents)
  (list (make-array 4 :element-type et :adjustable t :initial-contents contents)
        (make-array 4 :element-type et :fill-pointer 4 :initial-contents contents)
        (make-array 4 :element-type et
                      :displaced-to (make-array 5 :element-type et
                                                  :initial-contents (cons (first contents)
                                                                          contents))
                      :displaced-index-offset 1)))

(deftest complex-vector-subseq.element-type
    (let ((wrong '()))
      (dolist (policy '("NIO" "PRIMITIVE_ARRAY") (nreverse wrong))
        (dolist (case '(((unsigned-byte 8) (1 2 3 200))
                        ((unsigned-byte 32) (1 2 3 4000000000))
                        (bit (0 1 1 0))
                        (character (#\a #\b #\c #\d))
                        (t (a b c d))))
          (destructuring-bind (et contents) case
            (let ((want (upgraded-array-element-type et)))
              (dolist (v (subseq-test-with-policy
                          policy (lambda () (subseq-test-vectors et contents))))
                (dolist (op (list (list :subseq (subseq v 1 3) (subseq contents 1 3))
                                  (list :copy-seq (copy-seq v) contents)
                                  (list :reverse (reverse v) (reverse contents))))
                  (destructuring-bind (name r expected) op
                    (unless (and (equal (array-element-type r) want)
                                 (typep r 'simple-array)
                                 (equal (coerce r 'list) expected))
                      (push (list policy et name (adjustable-array-p v)
                                  (array-has-fill-pointer-p v)
                                  (array-element-type r) (coerce r 'list))
                            wrong))))))))))
  nil)
