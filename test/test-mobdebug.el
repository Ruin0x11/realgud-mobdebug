;; Press C-x C-e at the end of the next line to run this file test non-interactively
;; (test-simple-run "emacs -batch -L %s -l %s" (file-name-directory (locate-library "test-simple.elc")) buffer-file-name)

(require 'test-simple)
(load-file "../realgud-mobdebug/mobdebug.el")

(eval-when-compile (defvar test:run-process-save))

(declare-function mobdebug-parse-cmd-args 'realgud:mobdebug)
(declare-function mobdebug                'realgud:mobdebug)
(declare-function __FILE__              'load-relative)

(test-simple-start)

;; Save value realgud:run-process and change it to something we want
(setq test:run-process-save (symbol-function 'realgud:run-process))
(defun realgud:run-process(debugger-name script-filename cmd-args
					 minibuf-history &optional no-reset)
  "Fake realgud:run-process used in testing"
  (note
   (format "%s %s %s" debugger-name script-filename cmd-args))
  (assert-equal "node" debugger-name "debugger name gets passed")
  (let ((expanded-name (expand-file-name "./gcd.js")))
    (assert-equal  expanded-name script-filename "file name check")
    ))

(note "mobdebug-parse-cmd-args")
(assert-equal '(("node") nil ("inspect" "foo"))
	      (mobdebug-parse-cmd-args '("node" "inspect" "foo")))

;; FIXME: need to mock remove-ansi-schmutz in realgud:mobdebug
;; (realgud:mobdebug "node inspect ./gcd.js 3 5")

;; Restore the old value of realgud:run-process
(fset 'realgud:run-process test:run-process-save)

(end-tests)
