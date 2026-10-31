(in-package #:abcl.test.lisp)

;;; A non-local GO is caught by its TAGBODY's handler, which now
;;; transfers to the tag through a dispatch ahead of the body rather
;;; than jumping to the tag from the handler.  These check that compiled
;;; non-local GOs still reach the right tag, restore the dynamic
;;; environment, and pass through TAGBODYs they do not target.

(defun compile-tagbody-test (lambda-form)
  (compile nil lambda-form))

(deftest tagbody-dispatch.several-tags
    (let ((f (compile-tagbody-test
              '(lambda (which)
                (let ((trail '()))
                  (tagbody
                     (push :start trail)
                     (funcall (lambda ()
                                (case which
                                  (1 (go one))
                                  (2 (go two))
                                  (3 (go three)))))
                     (push :fell-through trail)
                     (go done)
                   one (push :one trail) (go done)
                   two (push :two trail) (go done)
                   three (push :three trail)
                   done)
                  (nreverse trail))))))
      (mapcar f '(0 1 2 3)))
  ((:start :fell-through) (:start :one) (:start :two) (:start :three)))

(deftest tagbody-dispatch.backward-go
    ;; A non-local GO to a tag earlier in the body, repeatedly.
    (funcall (compile-tagbody-test
              '(lambda ()
                (let ((n 0))
                  (tagbody
                   again
                     (funcall (lambda () (when (< (incf n) 5) (go again)))))
                  n))))
  5)

(deftest tagbody-dispatch.reentered
    ;; The TAGBODY entered again normally after a non-local GO falls
    ;; through to its first form, not to the last tag reached.
    (funcall (compile-tagbody-test
              '(lambda ()
                (let ((trail '()))
                  (dotimes (i 3)
                    (tagbody
                       (push (list :enter i) trail)
                       (funcall (lambda () (when (evenp i) (go skip))))
                       (push (list :body i) trail)
                     skip))
                  (nreverse trail)))))
  ((:enter 0) (:enter 1) (:body 1) (:enter 2)))

(defvar *tagbody-dispatch-special* :outer)

(deftest tagbody-dispatch.specials-restored
    (funcall (compile-tagbody-test
              '(lambda ()
                (let ((seen nil))
                  (tagbody
                     (let ((*tagbody-dispatch-special* :inner))
                       (funcall (lambda () (go out))))
                   out
                     (setf seen *tagbody-dispatch-special*))
                  seen))))
  :outer)

(deftest tagbody-dispatch.outer-tagbody
    ;; A GO aimed at an outer TAGBODY passes through an inner one that
    ;; has non-local tags of its own.
    (funcall (compile-tagbody-test
              '(lambda (k)
                (let ((trail '()))
                  (tagbody
                     (tagbody
                        (funcall (lambda () (funcall k (lambda () (go outer)))
                                   (go inner)))
                      inner
                        (push :inner trail))
                     (push :after-inner trail)
                   outer
                     (push :outer trail))
                  (nreverse trail))))
             #'funcall)
  (:outer))

(deftest tagbody-dispatch.handler-case
    (let ((f (compile-tagbody-test
              '(lambda (x)
                (list (handler-case (car x) (error () :error))
                      (ignore-errors (car x))
                      (restart-case (if (consp x) (car x) (invoke-restart 'r))
                        (r () :restarted)))))))
      (list (funcall f '(1)) (funcall f 2)))
  ((1 1 1) (:error nil :restarted)))
