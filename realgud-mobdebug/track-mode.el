;;; track-mode.el ---
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

;; mobdebug tracking a comint or eshell buffer.

(require 'load-relative)
(require 'realgud)

(declare-function realgud:track-set-debugger 'realgud-track-mode)
(declare-function realgud-track-mode-setup   'realgud-track-mode)
(declare-function realgud:remove-ansi-schmutz 'realgud:utils)

(require-relative-list '("core" "init") "realgud:mobdebug-")

(realgud-track-mode-vars "realgud:mobdebug")

(defun realgud:mobdebug-track-mode-hook()
  (if realgud:mobdebug-track-mode
      (progn
	(use-local-map realgud:mobdebug-track-mode-map)
	(realgud:remove-ansi-schmutz)
	(message "using mobdebug mode map")
	)
    (message "mobdebug track-mode-hook disable called"))
)

;; FIXME: this shouldn't be needed
(defvar realgud:mobdebug-track-mode-map (make-keymap))
(define-key realgud:mobdebug-track-mode-map
  (kbd "C-c !f") 'realgud:js-goto-file-line)

(define-minor-mode realgud:mobdebug-track-mode
  "Minor mode for tracking mobdebug source locations inside a mobdebug shell via realgud.

If called interactively with no prefix argument, the mode is
toggled. A prefix argument, captured as ARG, enables the mode if
the argument is positive, and disables it otherwise.

\\{realgud:mobdebug-track-mode-map}"
  :init-value nil
  ;; :lighter " mobdebug"   ;; mode-line indicator from realgud-track is sufficient.
  ;; The minor mode bindings.
  :global nil
  :group 'realgud:mobdebug
  :keymap realgud:mobdebug-track-mode-map

  (if realgud:mobdebug-track-mode
      (progn
	(realgud:track-set-debugger "mobdebug")
        (realgud:mobdebug-track-mode-hook)
        (realgud:track-mode-enable))
    (progn
      (setq realgud-track-mode nil)
      ))
  )

;; ;; Debugger commands that mobdebug doesn't have
;; (define-key mobdebug-track-mode-map
;;   [remap realgud:cmd-newer-frame] 'undefined)
;; (define-key mobdebug-track-mode-map
;;   [remap realgud:cmd-older-frame] 'undefined)
(defvar realgud:mobdebug-short-key-mode-map (make-keymap))

(define-key realgud:mobdebug-short-key-mode-map
  [remap realgud:cmd-step] 'realgud:cmd-step-no-arg)
(define-key realgud:mobdebug-short-key-mode-map
  [remap realgud:cmd-step] 'realgud:cmd-step-no-arg)
(define-key realgud:mobdebug-short-key-mode-map
  [remap realgud:cmd-next] 'realgud:cmd-next-no-arg)

(provide-me "realgud:mobdebug-")
