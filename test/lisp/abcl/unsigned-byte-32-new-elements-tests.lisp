(in-package #:abcl.test.lisp)

;;; Under the primitive-array allocation policy an adjustable
;;; (UNSIGNED-BYTE 32) vector keeps its elements as Lisp objects, and the
;;; places ADJUST-ARRAY (with no initial element) and VECTOR-PUSH-EXTEND
;;; added held Java null: AREF of one returned no Lisp object at all, and
;;; COPY-SEQ or REVERSE of the vector failed.

(defun ub32-new-elements-test-primitive (thunk)
  ;; in a thread of its own: a Java null met by a Lisp function throws a
  ;; Java exception, which ends the thread and reads as :CRASHED
  (let ((old (java:jfield "org.armedbear.lisp.Java$Buffers" "active"))
        (result :crashed))
    (unwind-protect
         (progn
           (setf (java:jfield "org.armedbear.lisp.Java$Buffers" "active")
                 (java:jfield "org.armedbear.lisp.Java$Buffers$AllocationPolicy"
                              "PRIMITIVE_ARRAY"))
           (threads:thread-join
            (threads:make-thread (lambda () (setf result (funcall thunk)))))
           result)
      (setf (java:jfield "org.armedbear.lisp.Java$Buffers" "active") old))))

(defun ub32-new-elements-test-all-ub32-p (v)
  ;; every place up to the capacity, past any fill pointer
  (loop for i below (array-dimension v 0)
        always (handler-case (typep (aref v i) '(unsigned-byte 32))
                 (error () nil))))

(deftest unsigned-byte-32-new-elements.adjust
    (ub32-new-elements-test-primitive
     (lambda ()
       (let* ((et '(unsigned-byte 32))
              (grown (adjust-array (make-array 2 :element-type et :adjustable t
                                                 :initial-contents '(7 8))
                                   5))
              (target (make-array 3 :element-type et :initial-contents '(1 2 3)))
              (undisplaced (adjust-array (make-array 2 :element-type et :adjustable t
                                                       :displaced-to target)
                                         4)))
         (list (ub32-new-elements-test-all-ub32-p grown)
               (subseq (coerce grown 'list) 0 2)
               (handler-case (length (copy-seq grown)) (error () :error))
               (handler-case (length (reverse grown)) (error () :error))
               (ub32-new-elements-test-all-ub32-p undisplaced)
               (subseq (coerce undisplaced 'list) 0 2)))))
  (t (7 8) 5 5 t (1 2)))

(deftest unsigned-byte-32-new-elements.vector-push-extend
    (ub32-new-elements-test-primitive
     (lambda ()
       (let ((v (make-array 1 :element-type '(unsigned-byte 32)
                              :adjustable t :fill-pointer 0)))
         (dotimes (i 3) (vector-push-extend (+ 100 i) v))
         (list (coerce v 'list) (ub32-new-elements-test-all-ub32-p v)))))
  ((100 101 102) t))
