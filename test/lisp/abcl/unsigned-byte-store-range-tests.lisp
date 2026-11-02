(in-package #:abcl.test.lisp)

;;; An array of element type (UNSIGNED-BYTE 8) or (UNSIGNED-BYTE 16)
;;; holds only integers of that type (CLHS 15.1.2.1); storing 256 or 65536
;;; stored it modulo 2^8 or 2^16 instead of signaling a TYPE-ERROR.  Under
;;; both allocation policies, NIO buffers (the default) and primitive
;;; arrays, by interpreted and compiled stores alike.

(defun store-range-test-with-policy (policy thunk)
  (let ((old (java:jfield "org.armedbear.lisp.Java$Buffers" "active")))
    (unwind-protect
         (progn
           (setf (java:jfield "org.armedbear.lisp.Java$Buffers" "active")
                 (java:jfield "org.armedbear.lisp.Java$Buffers$AllocationPolicy" policy))
           (funcall thunk))
      (setf (java:jfield "org.armedbear.lisp.Java$Buffers" "active") old))))

(defun store-range-test-arrays (et)
  (append (list (make-array 3 :element-type et)
                (make-array '(2 2) :element-type et))
          ;; adjustable (UNSIGNED-BYTE 16) vectors are a case of their own
          (unless (equal et '(unsigned-byte 16))
            (list (make-array 3 :element-type et :adjustable t)
                  (make-array 3 :element-type et :fill-pointer 1)
                  (make-array '(2 2) :element-type et :adjustable t)))))

(defun store-range-test-store (array value compiled)
  ;; compiled with the value declared FIXNUM when it is one, which takes
  ;; the store path for a Java int
  (let ((subscripts (make-list (array-rank array) :initial-element 0)))
    (if compiled
        (funcall (compile nil `(lambda (a v)
                                 ,@(when (typep value 'fixnum)
                                     '((declare (type fixnum v))))
                                 (setf (aref a ,@subscripts) v)))
                 array value)
        (setf (apply #'aref array subscripts) value))
    (apply #'aref array subscripts)))

(deftest unsigned-byte-store-range.refused
    (let ((wrong '()))
      (dolist (policy '("NIO" "PRIMITIVE_ARRAY") (nreverse wrong))
        (dolist (case '(((unsigned-byte 8) 255 256) ((unsigned-byte 16) 65535 65536)
                        ((unsigned-byte 32) 4294967295 4294967296)))
          (destructuring-bind (et top too-big) case
            (dolist (a (store-range-test-with-policy
                        policy (lambda () (store-range-test-arrays et))))
              (dolist (compiled '(nil t))
                (let ((kept (store-range-test-store a top compiled)))
                  (unless (eql kept top)
                    (push (list policy et (array-dimensions a) compiled :top kept) wrong)))
                (dolist (bad (list too-big -1))
                  (let ((r (handler-case (progn (store-range-test-store a bad compiled) :stored)
                             (type-error () :refused))))
                    (unless (eq r :refused)
                      (push (list policy et (array-dimensions a) compiled bad r) wrong))))))))))
  nil)

(deftest unsigned-byte-store-range.initial-contents
    ;; a two-dimensional (UNSIGNED-BYTE 16) array kept its initial
    ;; contents modulo 256 under the primitive-array policy
    (store-range-test-with-policy
     "PRIMITIVE_ARRAY"
     (lambda ()
       (let ((a (make-array '(2 2) :element-type '(unsigned-byte 16)
                                   :initial-contents '((1000 2) (3 65535)))))
         (list (aref a 0 0) (aref a 1 1)))))
  (1000 65535))

(deftest unsigned-byte-store-range.adjust-initial-element
    (let ((wrong '()))
      (dolist (policy '("NIO" "PRIMITIVE_ARRAY") (nreverse wrong))
        (let ((r (store-range-test-with-policy
                  policy
                  (lambda ()
                    (handler-case
                        (progn (adjust-array (make-array 2 :element-type '(unsigned-byte 8))
                                             4 :initial-element 300)
                               :adjusted)
                      (type-error () :refused))))))
          (unless (eq r :refused) (push (list policy r) wrong)))))
  nil)
