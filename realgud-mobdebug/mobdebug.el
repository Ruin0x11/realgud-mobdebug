;; Copyright (C) 2019 Free Software Foundation, Inc
;; Author: Rocky Bernstein <rocky@gnu.org>

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;  `realgud:mobdebug' Main interface to "node inspect" debugger via Emacs

(require 'cl-lib)
(require 'load-relative)
(require 'realgud)
(require-relative-list '("core" "track-mode") "realgud:mobdebug-")

;; This is needed, or at least the docstring part of it is needed to
;; get the customization menu to work in Emacs 25.
(defgroup realgud:mobdebug nil
  "The realgud interface to the mobdebug debugger"
  :group 'realgud
  :version "25.1")

;; -------------------------------------------------------------------
;; User-definable variables
;;

(defcustom realgud:mobdebug-command-name
  "bash /home/ruin/build/work/realgud-mobdebug/glue.sh love"
  "File name for executing the Javascript debugger and command options.
This should be an executable on your path, or an absolute file name."
  :type 'string
  :group 'realgud:mobdebug)

;; -------------------------------------------------------------------
;; The end.
;;

(declare-function mobdebug-track-mode     'realgud-mobdebug-track-mode)
(declare-function mobdebug-query-cmdline  'realgud:mobdebug-core)
(declare-function mobdebug-parse-cmd-args 'realgud:mobdebug-core)

;;;###autoload
(defun realgud:mobdebug (&optional opt-cmd-line no-reset)
  "Invoke the mobdebug shell debugger and start the Emacs user interface.

String OPT-CMD-LINE specifies how to run mobdebug.

OPT-CMD-LINE is treated like a shell string; arguments are
tokenized by `split-string-and-unquote'.  The tokenized string is
parsed by `mobdebug-parse-cmd-args' and path elements found by that
are expanded using `realgud:expand-file-name-if-exists'.

Normally, command buffers are reused when the same debugger is
reinvoked inside a command buffer with a similar command.  If we
discover that the buffer has prior command-buffer information and
NO-RESET is nil, then that information which may point into other
buffers and source buffers which may contain marks and fringe or
marginal icons is reset.  See `loc-changes-clear-buffer' to clear
fringe and marginal icons."
  (interactive)
  (let ((cmd-buf
	 (realgud:run-debugger "mobdebug"
			       'mobdebug-query-cmdline 'mobdebug-parse-cmd-args
			       'realgud:mobdebug-minibuffer-history
			       opt-cmd-line no-reset)))
    (if cmd-buf
    	(with-current-buffer cmd-buf
    	  ;; FIXME should allow customization whether to do or not
    	  ;; and also only do if hook is not already there.
          (realgud-command "basedir %s" default-directory nil nil)
          (realgud-command "step" nil nil nil)
    	  )
      )
    ))

(defalias 'mobdebug 'realgud:mobdebug)

(provide-me "realgud-")
