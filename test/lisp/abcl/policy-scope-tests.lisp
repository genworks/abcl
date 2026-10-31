(in-package #:abcl.test.lisp)

;;; An OPTIMIZE declaration in a function's body governs that body only.
;;; (compile 'f) on an interpreted function used to leave its declared
;;; policy in place globally, so everything compiled afterwards ran at,
;;; for example, SAFETY 0.

(defun current-policy ()
  (list sys::*speed* sys::*safety* sys::*debug* sys::*space*))

(defun restore-policy (policy)
  (destructuring-bind (speed safety debug space) policy
    (proclaim `(optimize (speed ,speed) (safety ,safety)
                         (debug ,debug) (space ,space)))))

(deftest policy-scope.compile-named-function
    (let ((before (current-policy)))
      (unwind-protect
           (progn
             (eval '(defun policy-scope-test-function ()
                     (declare (optimize (speed 3) (safety 0) (debug 0) (space 3)))
                     1))
             (compile 'policy-scope-test-function)
             (list (policy-scope-test-function)
                   (equal before (current-policy))))
        (restore-policy before)))
  (1 t))

(deftest policy-scope.compile-locally
    (let ((before (current-policy)))
      (unwind-protect
           (progn
             (funcall (compile nil '(lambda ()
                                     (locally (declare (optimize (safety 0) (speed 3)))
                                       2))))
             (equal before (current-policy)))
        (restore-policy before)))
  t)
