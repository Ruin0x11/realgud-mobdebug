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

;;; mobdebug debugger

(eval-when-compile (require 'cl-lib))   ;For setf.

(require 'load-relative)
(require 'realgud)
(require 'realgud-lang-js)
(require 'ansi-color)

(defvar realgud:mobdebug-pat-hash)
(declare-function make-realgud-loc-pat (realgud-loc))

(defvar realgud:mobdebug-pat-hash (make-hash-table :test 'equal)
  "Hash key is the what kind of pattern we want to match:
backtrace, prompt, etc.  The values of a hash entry is a
realgud-loc-pat struct")

;; before a command prompt.
;; For example:
;;   break in /home/indutny/Code/git/indutny/myscript.js:1
;;   frame change in file:///tmp/typescript-service.js:295
(setf (gethash "loc" realgud:mobdebug-pat-hash)
      (make-realgud-loc-pat
       :regexp (format
		"\\(> \\)?Paused at file %s line %s"
		"\\([^ ]+\\)"
		realgud:regexp-captured-num)
       :alt-file-group 2
       :alt-line-group 3
       :file-group 2
       :line-group 3))


;; Regular expression that describes a mobdebug command prompt
;; For example:
;;   debug>
(setf (gethash "prompt" realgud:mobdebug-pat-hash)
      (make-realgud-loc-pat
       :regexp (format "> ")
       ))

;; Need an improved setbreak for this.
;; ;;  Regular expression that describes a "breakpoint set" line
;; ;;   3 const armlet = require('armlet');
;; ;; * 4 const client = new armlet.Client(
;; ;; ^^^^
;; ;;
(setf (gethash "brkpt-set" realgud:mobdebug-pat-hash)
      (make-realgud-loc-pat
       :regexp (format
                "\\(> \\)?Breakpoint %s at file %s line %s"
                realgud:regexp-captured-num
                "\\([^ ]+\\)"
                realgud:regexp-captured-num)
       :num 2
       :alt-file-group 3
       :alt-line-group 4
       :file-group 3
       :line-group 4))

;; Regular expression that describes a V8 backtrace line.
;; For example:
;;    at repl:1:7
;;    at Interface.controlEval (/src/external-vcs/github/trepanjs/lib/interface.js:352:18)
;;    at REPLServer.b [as eval] (domain.js:183:18)
(setf (gethash "lang-backtrace" realgud:mobdebug-pat-hash)
  realgud:js-backtrace-loc-pat)

;; Regular expression that describes a debugger "delete" (breakpoint)
;; response.
;; For example:
;;   Removed 1 breakpoint(s).
(setf (gethash "brkpt-del" realgud:mobdebug-pat-hash)
      (make-realgud-loc-pat
       :regexp (format
                "\\(> \\)?Removed breakpoints? \\(\\([0-9]+ *\\)+\\)\n"
                realgud:regexp-captured-num
                "\\([^ ]+\\)"
                realgud:regexp-captured-num)
       :num 2
       :alt-file-group 3
       :alt-line-group 4
       :file-group 3
       :line-group 4))


(defconst realgud:mobdebug-frame-module-regexp "\\(nil\\)?\"\\([^ \t\n]+\\)\"")
(defconst realgud:mobdebug-frame-file-regexp   "\"\\([^ \t\n]+\\)\"")
(defconst realgud:mobdebug-frame-num-regexp    "-?\\([0-9]+\\)")
(defconst realgud:mobdebug-frame-thing-regexp   "\"\\([^ \t\n]*\\)\"")
(defconst realgud:mobdebug-frame-source-regexp   "\"\\(\\[string \\\\\\\\\"\\)?\\([^ \t\n]+\\)\\(\\\\\"]\\)?\"")

;; Regular expression that describes a debugger "backtrace" command line.
;;
;; {nil, "boot.lua", 576, 577, "Lua", "", "[string \\"boot.lua\"]"}
;; {"xpcall", "=[C]", -1, -1, "C", "global", "[C]"}
;; {nil, "boot.lua", 771, 784, "Lua", "", "[string \\"boot.lua\"]"}
;; {"xpcall", "=[C]", -1, -1, "C", "global", "[C]"}
;; {nil, "boot.lua", 760, 793, "Lua", "", "[string \\"boot.lua\"]"}
;; {"load", "main.lua", 12, 17, "Lua", "field", "main.lua"}
;;
;; For example:
;; #0 module.js:380:17
;; #1 dbgtest.js:3:9
;; #2 Module._compile module.js:456:26
;;
;; and with a newer node inspect:
;;
;; #0 file:///tmp/module.js:380:17
;; #1 file:///tmp/dbgtest.js:3:9
;; #2 Module._compile file:///tmpmodule.js:456:26
(setf (gethash "debugger-backtrace" realgud:mobdebug-pat-hash)
      (make-realgud-loc-pat
       :regexp (format "{%s, %s, %s, %s, %s, %s, %s}"
                       realgud:mobdebug-frame-module-regexp
                       realgud:mobdebug-frame-file-regexp
                       realgud:mobdebug-frame-num-regexp
                       realgud:mobdebug-frame-num-regexp
                       realgud:mobdebug-frame-file-regexp
                       realgud:mobdebug-frame-thing-regexp
                       realgud:mobdebug-frame-source-regexp)
       ;;        :num 1
       :function-group 2
       :file-group 3
       :line-group 4
       :char-offset-group 5))

(defconst realgud:mobdebug-debugger-name "mobdebug" "Name of debugger.")

;; ;; Regular expression that for a termination message.
;; (setf (gethash "termination" realgud:mobdebug-pat-hash)
;;        "^mobdebug: That's all, folks...\n")

(setf (gethash "font-lock-keywords" realgud:mobdebug-pat-hash)
      '(
	;; The frame number and first type name, if present.
	;; E.g. ->0 in file `/etc/init.d/apparmor' at line 35
	;;      --^-
	("^\\(->\\|##\\)\\([0-9]+\\) "
	 (2 realgud-backtrace-number-face))

	;; File name.
	;; E.g. ->0 in file `/etc/init.d/apparmor' at line 35
	;;          ---------^^^^^^^^^^^^^^^^^^^^-
	("[ \t]+\\(Paused at \\) `\\(.+\\)'"
	 (2 realgud-file-name-face))

	;; File name.
	;; E.g. ->0 in file `/etc/init.d/apparmor' at line 35
	;;                                         --------^^
	;; Line number.
	("[ \t]+ line \\([0-9]+\\)$"
	 (1 realgud-line-number-face))
	))

(setf (gethash "mobdebug" realgud-pat-hash)
      realgud:mobdebug-pat-hash)

;;  Prefix used in variable names (e.g. short-key-mode-map) for
;; this debugger

(setf (gethash "mobdebug" realgud:variable-basename-hash)
      "realgud:mobdebug")

(defvar realgud:mobdebug-command-hash (make-hash-table :test 'equal)
  "Hash key is command name like 'finish' and the value is
the mobdebug command to use, like 'out'.")

(setf (gethash realgud:mobdebug-debugger-name
	       realgud-command-hash)
      realgud:mobdebug-command-hash)

(setf (gethash "backtrace"        realgud:mobdebug-command-hash) "stack")
(setf (gethash "break"            realgud:mobdebug-command-hash) "setb %X %l")
(setf (gethash "delete"           realgud:mobdebug-command-hash) "delb %p")
(setf (gethash "delete-all"       realgud:mobdebug-command-hash) "dellallb")
(setf (gethash "continue"         realgud:mobdebug-command-hash) "run")
(setf (gethash "eval"             realgud:mobdebug-command-hash) "eval '%s'")
(setf (gethash "finish"           realgud:mobdebug-command-hash) "out")
(setf (gethash "info-breakpoints" realgud:mobdebug-command-hash) "listb")
(setf (gethash "kill"             realgud:mobdebug-command-hash) "done")
(setf (gethash "quit"             realgud:mobdebug-command-hash) "exit")
(setf (gethash "basedir"          realgud:mobdebug-command-hash) "basedir %s")

;; We need aliases for step and next because the default would
;; do step 1 and mobdebug doesn't handle this. And if it did,
;; it would probably look like step(1).
(setf (gethash "step"       realgud:mobdebug-command-hash) "step")
(setf (gethash "next"       realgud:mobdebug-command-hash) "over")

;; Unsupported features:
(setf (gethash "break-fn"   realgud:mobdebug-command-hash) "*not-implemented*")
(setf (gethash "until"      realgud:mobdebug-command-hash) "*not-implemented*")
(setf (gethash "tbreak"     realgud:mobdebug-command-hash) "*not-implemented*")
(setf (gethash "shell"      realgud:mobdebug-command-hash) "*not-implemented*")
(setf (gethash "jump"       realgud:mobdebug-command-hash) "*not-implemented*")
(setf (gethash "up"         realgud:mobdebug-command-hash) "*not-implemented*")
(setf (gethash "down"       realgud:mobdebug-command-hash) "*not-implemented*")
(setf (gethash "frame"      realgud:mobdebug-command-hash) "*not-implemented*")

(setf (gethash "mobdebug" realgud-command-hash) realgud:mobdebug-command-hash)
(setf (gethash "mobdebug" realgud-pat-hash) realgud:mobdebug-pat-hash)

(provide-me "realgud:mobdebug-")
