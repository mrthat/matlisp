;;; -*- Mode: lisp; Syntax: ansi-common-lisp; Base: 10 -*-
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Copyright (c) 2000 The Regents of the University of California.
;;; All rights reserved. 
;;; 
;;; Permission is hereby granted, without written agreement and without
;;; license or royalty fees, to use, copy, modify, and distribute this
;;; software and its documentation for any purpose, provided that the
;;; above copyright notice and the following two paragraphs appear in all
;;; copies of this software.
;;; 
;;; IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY
;;; FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
;;; ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF
;;; THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF
;;; SUCH DAMAGE.
;;;
;;; THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
;;; INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
;;; MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE
;;; PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
;;; CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES,
;;; ENHANCEMENTS, OR MODIFICATIONS.
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;  This file is used to generate 'lazy-loader.lisp'.  Essentially, when
;;;  the 'configure' script is executed the tokens in this file,
;;;  e.g. FLIBS, get substituted with the appropriate machine specific
;;;  parameters and the resulting file is saved in 'lazy-loader.lisp'.
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; $Id: lazy-loader.lisp,v 1.5 2000/10/04 22:51:32 simsek Exp $
;;;
;;; $Log: lazy-loader.lisp,v $
;;; Revision 1.5  2000/10/04 22:51:32  simsek
;;; *** empty log message ***
;;;
;;; Revision 1.6  2000/10/04 15:38:18  simsek
;;; o Added dfftpack to loaded binaries
;;;  o Added unload-blas-&-lapack-libraries for Allegro image
;;;    saving support
;;;
;;; Revision 1.5  2000/10/04 01:22:21  simsek
;;; o Changed package to MATLISP
;;;   This avoids interning symbols in packages other
;;;   than MATLISP
;;;
;;; Revision 1.4  2000/07/11 02:49:55  simsek
;;; *** empty log message ***
;;;
;;; Revision 1.3  2000/07/11 02:08:19  simsek
;;; Added support for Allegro CL
;;;
;;; Revision 1.2  2000/05/05 21:31:00  simsek
;;; o Added the library libdfftpack to the load list
;;;
;;; Revision 1.1  2000/04/13 23:34:29  simsek
;;; o This file is used by lisp to load foreign libraries.
;;; o Initial revision.
;;;
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(in-package "MATLISP")

#|
;; example of an optimized BLAS/LAPACK load on a Solaris platform

(eval-when (load eval compile)
(defun load-blas-&-lapack-libraries ()
  (ext::load-foreign "matlisp:lib;lazy-loader.o"
		:libraries `("-R/home/eclair1/shift-uav/meta-shift/lib"
			     "-L/home/eclair1/shift-uav/meta-shift/lib"
			     "-R/usr/lib"
			     "-L/usr/lib"
			     "-R/usr/sww/lib"
			     "-L/usr/sww/lib"
			     "-R/usr/sww/opt/SUNWspro-5.0/SC5.0/lib"				
			     "-L/usr/sww/opt/SUNWspro-5.0/SC5.0/lib"				
			     "-latlas"
			     "-llapack"
			     "-lblas"
			     "-lM77"
			     "-lF77"
			     "-lsunmath"
			     "-lm"
			     "-lc"))))
|#

(eval-when (load eval compile)
#+:cmu
(defun tokenize-ld-args (s)
  (let ((token "")
	(n (length s))
	(tokens nil))

    (dotimes (i n)
       (declare (type fixnum i))
       (let ((c (char s i)))
	 (case c
	  ((#\return #\linefeed 
	    #\space #\tab #\newline)  (if (not (string= token ""))
					  (progn
					    (push token tokens)
					    (setq token ""))))
	  (t (setq token (concatenate 'string token (string c)))))))

    (if (not (string= token ""))
	(push token tokens))

    (nreverse tokens)))

#+:cmu
(defun load-blas-&-lapack-libraries ()
  (ext::load-foreign "matlisp:lib;lazy-loader.o"
		:libraries (tokenize-ld-args
			     (concatenate 'string
				 "-L"
				 (namestring
				   (translate-logical-pathname "matlisp:lib"))
				 " "
			         "-lmatlispstatic
                                   -L/usr/ccs/lib -L/usr/lib -L/usr/sww/pkg/gcc-2.95.2/lib/gcc-lib/sparc-sun-solaris2.6/2.95.2 -L/usr/ccs/bin -L/usr/ccs/lib -L/usr/sww/pkg/gcc-2.95.2/lib -lg2c -lm -R /usr/sww/pkg/gcc-2.95.2/lib:/usr/sww/lib -lm"))))

#+:allegro
(defun load-blas-&-lapack-libraries ()
  #+(or :unix :linux) (load "matlisp:lib;libmatlispshared.so")
  #+:mswindows (load "matlisp:lib;blas.dll")
  #+:mswindows (load "matlisp:lib;lapack.dll"))

(load-blas-&-lapack-libraries))

(defun load-blas-&-lapack-binaries ()
  (load-blas-&-lapack-libraries)
  (load (translate-logical-pathname "matlisp:bin;blas") :verbose nil)
  (load (translate-logical-pathname "matlisp:bin;lapack") :verbose nil)
  #-:mswindows (load (translate-logical-pathname
		      "matlisp:bin;dfftpack") :verbose nil))

#+:cmu
(defun unload-blas-&-lapack-libraries ()
  nil)

#+(and :allegro (not :mswindows))
(defun unload-blas-&-lapack-libraries ()
  (ff:unload-foreign-library "matlisp:lib;libmatlispshared.so"))

#+(and :allegro :mswindows)
(defun unload-blas-&-lapack-libraries ()
  (ff:unload-foreign-library "matlisp:lib;lapack.dll")
  (ff:unload-foreign-library "matlisp:lib;blas.dll"))