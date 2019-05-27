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

(eval-when-compile (require 'cl-lib))

(require 'load-relative)
(require 'realgud)

(declare-function realgud:expand-file-name-if-exists 'realgud-core)
(declare-function realgud-lang-mode? 'realgud-lang)
(declare-function realgud-parse-command-arg 'realgud-core)
(declare-function realgud-query-cmdline 'realgud-core)

;; FIXME: I think the following could be generalized and moved to
;; realgud-... probably via a macro.
(declare-function realgud:expand-file-name-if-exists 'realgud-core)
(declare-function realgud-parse-command-arg  'realgud-core)
(declare-function realgud-query-cmdline      'realgud-core)
(declare-function realgud-suggest-invocation 'realgud-core)

;; FIXME: I think the following could be generalized and moved to
;; realgud-... probably via a macro.
(defvar realgud:mobdebug-minibuffer-history nil
  "Minibuffer history list for the command `mobdebug'.")

(easy-mmode-defmap realgud:mobdebug-minibuffer-local-map
  '(("\C-i" . comint-dynamic-complete-filename))
  "Keymap for minibuffer prompting of mobdebug startup command."
  :inherit minibuffer-local-map)

;; FIXME: I think this code and the keymaps and history
;; variable chould be generalized, perhaps via a macro.
(defun mobdebug-query-cmdline (&optional opt-debugger)
  (realgud-query-cmdline
   'realgud:mobdebug-suggest-invocation
   realgud:mobdebug-minibuffer-local-map
   'realgud:mobdebug-minibuffer-history
   opt-debugger))

;;; FIXME: DRY this with other *-parse-cmd-args routines
(defun mobdebug-parse-cmd-args (orig-args)
  "Parse command line ORIG-ARGS for the name of script to debug.

ORIG-ARGS should contain a tokenized list of the command line to run.

We return the a list containing
* the name of the debugger given (e.g. mobdebug) and its arguments ,
  a list of strings
* the script name and its arguments - list of strings

For example for the following input:
  (map 'list 'symbol-name
   '(node --interactive --debugger-port 5858 /tmp mobdebug ./gcd.js a b))

we might return:
   ((\"node\" \"--interactive\" \"--debugger-port\" \"5858\") nil
    (\"/tmp/gcd.js\" \"a\" \"b\"))

Note that path elements have been expanded via `expand-file-name'."

  ;; Parse the following kind of pattern:
  ;;  node mobdebug-options script-name script-options
  (let (
	(args orig-args)
	(pair)          ;; temp return from
	(node-two-args '("-debugger_port" "C" "D" "i" "l" "m" "-module" "x"))
	;; node doesn't have any optional two-arg options
	(node-opt-two-args '())

	;; One dash is added automatically to the below, so
	;; h is really -h and -debugger_port is really --debugger_port.
	(mobdebug-two-args '("-debugger_port"))
	(mobdebug-opt-two-args '())

	;; Things returned
	(script-name nil)
	(debugger-name nil)
	(interpreter-args '())
	(script-args '())
	)
    (if (not (and args))
	;; Got nothing: return '(nil, nil, nil)
	(list interpreter-args nil script-args)
      ;; else
      (let* ((file (nth 3 args))
             (filename (if (directory-name-p file) file file)))
        (list (subseq args 0 2) (list (nth 2 args)) (list filename))))
    ))

;; To silence Warning: reference to free variable
(defvar realgud:mobdebug-command-name)

(defun realgud:mobdebug-file-search-upward (directory file)
  "Search DIRECTORY for FILE and return its full path if found, or NIL if not.

If FILE is not found in DIRECTORY, the parent of DIRECTORY will be searched."
  (let ((parent-dir (file-truename (concat (file-name-directory directory) "../")))
        (current-path (if (not (string= (substring directory (- (length directory) 1)) "/"))
                         (concat directory "/" file)
                         (concat directory file))))
    (if (file-exists-p current-path)
        current-path
        (when (and (not (string= (file-truename directory) parent-dir))
                   (< (length parent-dir) (length (file-truename directory))))
          (realgud:mobdebug-file-search-upward parent-dir file)))))

(defun realgud:mobdebug-suggest-invocation (debugger-name)
  "Suggest a mobdebug command invocation via `realgud-suggest-invocaton'."
  (if-let ((love-main-file (realgud:mobdebug-file-search-upward default-directory "main.lua")))
      (concat realgud:mobdebug-command-name " " love-main-file)
    (realgud-suggest-invocation realgud:mobdebug-command-name
                                realgud:mobdebug-minibuffer-history
                                "lua" "\\.lua$")))

(defun realgud:mobdebug-remove-ansi-shmutz()
  "Remove ASCII escape sequences that node.js 'decorates' in
prompts and interactive output."
  (add-to-list
   'comint-preoutput-filter-functions
   (lambda (output)
     (replace-regexp-in-string "\033\\[[0-9]+[GKJ]" "" output)))
  )

(defun realgud:mobdebug-reset ()
  "Mobdebug cleanup - remove debugger's internal buffers (frame,
breakpoints, etc.)."
  (interactive)
  ;; (mobdebug-breakpoint-remove-all-icons)
  (dolist (buffer (buffer-list))
    (when (string-match "\\*mobdebug-[a-z]+\\*" (buffer-name buffer))
      (let ((w (get-buffer-window buffer)))
        (when w
          (delete-window w)))
      (kill-buffer buffer))))

;; (defun mobdebug-reset-keymaps()
;;   "This unbinds the special debugger keys of the source buffers."
;;   (interactive)
;;   (setcdr (assq 'mobdebug-debugger-support-minor-mode minor-mode-map-alist)
;; 	  mobdebug-debugger-support-minor-mode-map-when-deactive))


(defun realgud:mobdebug-customize ()
  "Use `customize' to edit the settings of the `mobdebug' debugger."
  (interactive)
  (customize-group 'realgud:mobdebug))

(provide-me "realgud:mobdebug-")
