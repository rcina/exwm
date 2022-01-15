(defun efs/run-in-background (command)
    (let ((command-parts (split-string command "[ ]+")))
      (apply #'call-process `(,(car command-parts) nil 0 nil ,@(cdr command-parts)))))

  (defun efs/set-wallpaper ()
    (interactive)
    ;; NOTE: You will need to update this to a valid background path!
    (start-process-shell-command
        "feh" nil  "feh --bg-scale /usr/share/backgrounds/matt-mcnulty-nyc-2nd-ave.jpg"))

  (defun efs/exwm-init-hook ()
    ;; Make workspace 1 be the one where we land at startup
    (exwm-workspace-switch-create 1)

    ;; Open eshell by default
    ;;(eshell)

    ;; Show battery status in the mode line
    ;;(display-battery-mode 1)

    ;; Show the time and date in modeline
    (setq display-time-day-and-date t)
    ;;(display-time-mode 1)
    ;; Also take a look at display-time-format and format-time-string

    ;; Start the Polybar panel
    (efs/start-panel)

    ;; Launch apps that will run in the background
    (efs/run-in-background "nm-applet")
    (efs/run-in-background "pasystray")
    (efs/run-in-background "blueman-applet"))

  (defun efs/exwm-update-class ()
    (exwm-workspace-rename-buffer exwm-class-name))

(defun efs/exwm-update-title ()
    (pcase exwm-class-name
      ("Firefox" (exwm-workspace-rename-buffer (format "Firefox: %s" exwm-title)))))

(defun efs/configure-window-by-class ()
  (interactive)
  (pcase exwm-class-name
  ("Firefox" (exwm-workspace-move-window 2))
  ("Sol" (exwm-workspace-move-window 3))
  ("mpv" (exwm-floating-toggle-floating)
   (exwm-layout-toggle-mode-line))))

  (use-package exwm
    :config
    ;; Set the default number of workspaces
    (setq exwm-workspace-number 5)

    ;; When window "class" updates, use it to set the buffer name
    (add-hook 'exwm-update-class-hook #'efs/exwm-update-class)

    ;; When window title updates, use it to set the buffer name
    (add-hook 'exwm-update-title-hook #'efs/exwm-update-title)

    ;; Configure windows as they're created
    (add-hook 'exwm-manage-finish-hook #'efs/configure-window-by-class)

    ;; When EXWM starts up, do some extra confifuration
    (add-hook 'exwm-init-hook #'efs/exwm-init-hook)

    ;; Rebind CapsLock to Ctrl
    (start-process-shell-command "xmodmap" nil "xmodmap ~/.emacs.d/exwm/Xmodmap")

    ;; Set the screen resolution (update this to be the correct resolution for your screen!)
    (require 'exwm-randr)
    (exwm-randr-enable)
    (start-process-shell-command "xrandr" nil "xrandr --output Virtual-1 --primary --mode 2048x1152 --pos 0x0 --rotate normal")
    ;;(start-process-shell-command "xrandr" nil "xrandr --output LVDS-1 --primary --mode 1024x768 --pos 0x0 --rotate normal --output VGA-1 --off --output HDMI-1 --off --output DP-1 --off") 
    ;; Set the wallpaper after changing the resolution
    (efs/set-wallpaper)

    ;; Load the system tray before exwm-init
    ;;(require 'exwm-systemtray)
    ;;(setq exwm-systemtray-height 32)
    ;;(exwm-systemtray-enable)

    ;; These keys should always pass through to Emacs
    (setq exwm-input-prefix-keys
      '(?\C-x
        ?\C-u
        ?\C-h
        ?\M-x
        ?\M-`
        ?\M-&
        ?\M-:
        ?\C-\M-j  ;; Buffer list
        ?\C-\ ))  ;; Ctrl+Space

    ;; Ctrl+Q will enable the next key to be sent directly
    (define-key exwm-mode-map [?\C-q] 'exwm-input-send-next-key)

    ;; Set up global key bindings.  These always work, no matter the input state!
    ;; Keep in mind that changing this list after EXWM initializes has no effect.
    (setq exwm-input-global-keys
          `(
            ;; Reset to line-mode (C-c C-k switches to char-mode via exwm-input-release-keyboard)
            ([?\s-r] . exwm-reset)

            ;; Move between windows
            ([s-left] . windmove-left)
            ([s-right] . windmove-right)
            ([s-up] . windmove-up)
            ([s-down] . windmove-down)

            ;; Launch applications via shell command
            ([?\s-&] . (lambda (command)
                         (interactive (list (read-shell-command "$ ")))
                         (start-process-shell-command command nil command)))

            ;; Switch workspace
            ([?\s-w] . exwm-workspace-switch)
            ([?\s-`] . (lambda () (interactive) (exwm-workspace-switch-create 0)))

            ;; 's-N': Switch to certain workspace with Super (Win) plus a number key (0 - 9)
            ,@(mapcar (lambda (i)
                        `(,(kbd (format "s-%d" i)) .
                          (lambda ()
                            (interactive)
                            (exwm-workspace-switch-create ,i))))
                      (number-sequence 0 9))))

    (exwm-input-set-key (kbd "s-SPC") 'counsel-linux-app)

    (exwm-enable))

(use-package desktop-environment
  :after exwm
  :config (desktop-environment-mode)
  :custom
  (desktop-environment-brightness-small-increment "2%+")
  (desktop-environment-brightness-small-decrement "2%-")
  (desktop-environment-brightness-normal-increment "5%+")
  (desktop-environment-brightness-normal-decrement "5%-"))

;; Make sure the server is started (better to do this in your main Emacs config!)
      (server-start)

        (defvar efs/polybar-process nil
          "Holds the process of the running Polybar instance, if any")

        (defun efs/kill-panel ()
          (interactive)
          (when efs/polybar-process
            (ignore-errors
              (kill-process efs/polybar-process)))
          (setq efs/polybar-process nil))

        (defun efs/start-panel ()
          (interactive)
          (efs/kill-panel)
          (setq efs/polybar-process (start-process-shell-command "polybar" nil "polybar panel")))

(defun efs/send-polybar-hook (module-name hook-index)
  (start-process-shell-command "polybar-msg" nil (format "polybar-msg hook %s %s" module-name hook-index)))

(defun efs/send-polybar-exwm-workspace ()
  (efs/send-polybar-hook "exwm-workspace" 1))

  (defun efs/polybar-exwm-workspace ()
      (pcase exwm-workspace-current-index
        (0 "")
        (1 "")
        (2 "")
        (3 "")
        (4 "")))

;; Update panel indicator when workspace changes
(add-hook 'exwm-workspace-switch-hook #'efs/send-polybar-exwm-workspace)
