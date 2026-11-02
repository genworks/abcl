(in-package #:abcl.test.lisp)

;;; ADJUST-ARRAY accepts :ELEMENT-TYPE when its upgraded type is the
;;; array's own (CLHS ADJUST-ARRAY).  For (UNSIGNED-BYTE 8), 16 and 32 it
;;; refused the array's very type, 'incompatible element type': the
;;; upgraded type was the caller's list, compared with == against the
;;; array's.

(defun adjust-array-element-type-test-arrays (et)
  (list (make-array 4 :element-type et :adjustable t)
        (make-array 4 :element-type et :adjustable t :fill-pointer 2)
        (make-array '(2 2) :element-type et :adjustable t)))

(deftest adjust-array-element-type.same-type
    (let ((wrong '()))
      (dolist (et '((unsigned-byte 8) (unsigned-byte 32) (unsigned-byte 16)
                    bit character t) (nreverse wrong))
        (dolist (a (adjust-array-element-type-test-arrays et))
          ;; vectors of (UNSIGNED-BYTE 16) are a case of their own
          (unless (and (equal et '(unsigned-byte 16)) (vectorp a))
            (let ((r (ignore-errors
                      (adjust-array a (if (vectorp a) 6 '(3 3))
                                    :element-type (copy-tree et)))))
              (unless (and r (equal (array-element-type r)
                                    (upgraded-array-element-type et)))
                (push (list et (array-dimensions a)) wrong)))))))
  nil)

(deftest adjust-array-element-type.equivalent-type
    ;; a type spelled otherwise that upgrades to the same
    (let ((v (make-array 4 :element-type '(unsigned-byte 8) :adjustable t)))
      (array-element-type
       (adjust-array v 6 :element-type '(integer 0 200))))
  (unsigned-byte 8))

(deftest adjust-array-element-type.other-type-refused
    (let ((v (make-array 4 :element-type '(unsigned-byte 8) :adjustable t)))
      (handler-case (progn (adjust-array v 6 :element-type 'character) :adjusted)
        (error () :refused)))
  :refused)

(deftest adjust-array-element-type.upgraded-is-shared
    ;; UPGRADED-ARRAY-ELEMENT-TYPE gives back the shared type, never the
    ;; list it was given, so an array's element type is never a caller's
    ;; list that the caller may change
    (let ((spec (list 'unsigned-byte 8)))
      (not (eq (upgraded-array-element-type spec) spec)))
  t)
