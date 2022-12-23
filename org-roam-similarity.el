;;; org-roam-similarity.el --- Org-mode Similarity Discovery Integrated with Org-Roam -*- lexical-binding: t; -*-

;; Initial Author: Bruno Arine <bruno.arine@runbox.com>
;; Author of the fork: Vidianos Giannitsis <vidianosgiannitsis@gmail.com>
;; URL: https://github.com/Vidianos-Giannitsis/org-roam-similarity
;; Version: 0.1
;; Package-Requires: ((org "9.3") (emacs "26.1")))

;; 3-clause BSD License

;; Copyright 2020 Bruno Arine

;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions are met:

;; 1. Redistributions of source code must retain the above copyright notice,
;; this list of conditions and the following disclaimer.

;; 2. Redistributions in binary form must reproduce the above copyright notice,
;; this list of conditions and the following disclaimer in the documentation
;; and/or other materials provided with the distribution.

;; 3. Neither the name of the copyright holder nor the names of its contributors
;; may be used to endorse or promote products derived from this software without
;; specific prior written permission.

;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
;; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
;; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
;; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
;; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
;; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
;; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
;; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
;; POSSIBILITY OF SUCH DAMAGE.

;;; Commentary:
;; A package to help discover similar or related org-mode files.
;; Use M-x org-similarity-insert-list RET to insert a list of links containing related files.

;;; Code:

(defcustom org-roam-similarity-language "english"
  "The language org-roam-similarity uses.

Specifically, in the python script that does the heavy lifting,
the nltk program is used for text pre-processing and this
variable defines the language it should use. Defaults to english
for obvious reasons."
  :type 'string
  :group 'org-roam-similarity)

(defcustom org-roam-similarity-number-of-documents 10
  "Amount of documents org-roam-similarity should return."
  :type 'integer
  :group 'org-roam-similarity)

(defcustom org-roam-similarity-directory org-roam-directory
  "Directory in which org-roam-similarity should look.

Defaults to `org-roam-directory' as this package is meant to be
used with org-roam."
  :type 'directory
  :group 'org-roam-similarity)

(defcustom org-roam-similarity-show-scores nil
  "Show similarity scoring of files in the output."
  :type 'boolean
  :group 'org-roam-similarity)

(defcustom org-roam-similarity-root
  (concat (file-name-directory
	   (f-full (or
		    load-file-name
		    buffer-file-name)))
	  ".")
  "Root directory of org-roam-similarity."
  :type 'directory
  :group 'org-roam-similarity)

(defun org-roam-similarity-insert-list ()
  "Insert a list of 'org-mode' links to files that are similar to the buffer file."
  (interactive)
  (end-of-buffer)
  (newline)
  (let ((command (format "python3 %s -i %s -d %s -l %s -n %s %s"
			 (concat org-roam-similarity-root "/assets/org-similarity.py")
			 buffer-file-name
			 org-roam-similarity-directory
			 org-roam-similarity-language
			 org-roam-similarity-number-of-documents
			 (if org-roam-similarity-show-scores "--score" ""))))
    (insert (shell-command-to-string command)))
  (pop-global-mark)
  )

(defun org-roam-similarity-sidebuffer ()
    "Puts the results of org-similarity in a side-window."
    (interactive)
    (let ((command (format "python3 %s -i %s -d %s -l %s -n %s %s"
	    (concat org-roam-similarity-root "/assets/org-similarity.py")
	     buffer-file-name
	     org-roam-similarity-directory
	     org-roam-similarity-language
	     org-roam-similarity-number-of-documents
	     (if org-roam-similarity-show-scores "--score" ""))))
      (setq similarity-results (shell-command-to-string command)))
      (with-output-to-temp-buffer "*Similarity Results*"
      (princ similarity-results))
      (with-current-buffer "*Similarity Results*"
      (org-mode))
    )
  (add-to-list 'display-buffer-alist
	       '("*Similarity Results*"
		 (display-buffer-in-side-window)
		 (inhibit-same-window . t)
		 (side . right)
		 (window-width . 0.4))
  )

(defvar org-roam-similarity-nodes-list '()
  "List of lists containing similar nodes.

These lists are generated by `org-roam-similarity-collect-nodes'
and their `car' is a user selected node while the rest of its
elements are notes relevant to it as found by the python script
used in `org-roam-similarity--collect-files'.")

(defun org-roam-similarity--collect-files (NODE)
  "Collect the files associated with NODE.

This is the backend of the org-roam-similarity package. It is a
function not meant to be called directly (although you could do
that if you give it an argument of `org-roam-node-read') but by
`org-roam-roam-similarity-collect-nodes'. What it does is run a
python script, using some variables of the package as its
arguments which returns as a string, the file names of the 10
most relevant nodes to NODE. After some formatting of the output,
the function returns a list whose `car' is NODE and its `cdr' is
the list of files returned by the script. Then,
`org-roam-similarity-collect-nodes', the function that is meant
to call this takes that list and returns a list of nodes."
  (let* ((command (format "python3 %s -i %s -d %s -l %s -n %s %s"
			  (concat org-roam-similarity-root "/assets/org-roam-similarity.py")
			  (org-roam-node-file NODE)
			  org-roam-similarity-directory
			  org-roam-similarity-language
			  org-roam-similarity-number-of-documents
			  (if org-roam-similarity-show-scores "--score" "")))
	 (command-res (shell-command-to-string command))
	 (file-list (butlast (cddr (split-string command-res "[\n]"))))
	 (results (cons NODE file-list)))
    results))

(defun org-roam-similarity-collect-nodes (NODE)
  "Collect the org-roam-nodes associated with NODE.

This function is the core of org-roam-similarity. Given NODE,
this function runs `org-roam-similarity--collect-files' with it,
returning a list of files of the most relevant to it nodes. Then,
it runs a `dolist' expression finding the file-path of each
file (by concating `org-roam-directory' to it), then opening it
in a buffer with `find-file-noselect' and then finding that
buffer, getting its properties and extracting from those its ID
and from the ID, it finds the node associated to that
buffer. Then, it adds that to a list. During this process, Emacs
makes sure that `org-startup-with-latex-preview' is turned off,
because if on, it slows the function down.

Finally, when the loop is complete, this function populates
`org-roam-similarity-nodes-list' with the list of nodes this
collected, having pushed NODE to that list."
  (let ((node-list '()))
    (dolist (file (cdr (org-roam-similarity--collect-files NODE)))
      (let ((file-path (concat org-roam-directory file))
	    (org-startup-with-latex-preview nil))
	(find-file-noselect file-path)
	(with-current-buffer (get-file-buffer file-path)
	  (let* ((props (org-entry-properties))
		 (id (cdr (assoc "ID" props)))
		 (rel-node (org-roam-node-from-id id)))
	    (add-to-list 'node-list rel-node)))))
    (add-to-list 'org-roam-similarity-nodes-list (push NODE node-list))))

(provide 'org-roam-similarity)

;;; org-similarity.el ends here