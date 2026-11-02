(in-package #:abcl.test.lisp)

;;; ADJUST-ARRAY of a simple (UNSIGNED-BYTE 16) or (UNSIGNED-BYTE 32)
;;; vector to a new length threw java.lang.ArrayStoreException, which no
;;; Lisp handler sees: the thread died.  Each case runs in a thread of its
;;; own, so that a crash reads as :CRASHED rather than ending the run, and
;;; under both allocation policies, NIO buffers (the default, heap and
;;; direct) and primitive arrays.

(defun adjust-grow-test-isolated (thunk)
  (let* ((result :crashed)
         (thread (threads:make-thread (lambda () (setf result (funcall thunk))))))
    (threads:thread-join thread)
    result))

(defun adjust-grow-test-with-policy (policy thunk)
  (let ((old (java:jfield "org.armedbear.lisp.Java$Buffers" "active")))
    (unwind-protect
         (progn
           (setf (java:jfield "org.armedbear.lisp.Java$Buffers" "active")
                 (java:jfield "org.armedbear.lisp.Java$Buffers$AllocationPolicy" policy))
           (funcall thunk))
      (setf (java:jfield "org.armedbear.lisp.Java$Buffers" "active") old))))

(deftest adjust-simple-vector.grow
    (let ((wrong '()))
      (dolist (policy '("NIO" "PRIMITIVE_ARRAY") (nreverse wrong))
        (dolist (direct '(nil t))
          (dolist (et '((unsigned-byte 8) (unsigned-byte 16) (unsigned-byte 32)))
            (unless (and direct (string= policy "PRIMITIVE_ARRAY"))
              (let ((r (adjust-grow-test-with-policy
                        policy
                        (lambda ()
                          (adjust-grow-test-isolated
                           (lambda ()
                             (handler-case
                                 (let* ((v (make-array 3 :element-type et
                                                         :initial-contents '(1 2 3)
                                                         :nio-direct direct))
                                        (longer (adjust-array v 5 :initial-element 7))
                                        (shorter (adjust-array v 2))
                                        (no-initial (adjust-array v 4)))
                                   (list (coerce longer 'list)
                                         (coerce shorter 'list)
                                         (subseq (coerce no-initial 'list) 0 3)
                                         (equal (array-element-type longer) et)
                                         (length no-initial)))
                               (error (e) (list :error (type-of e))))))))))
                (unless (equal r '((1 2 3 7 7) (1 2) (1 2 3) t 4))
                  (push (list policy direct et r) wrong))))))))
  nil)
