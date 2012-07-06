;;; -*- Mode: lisp; Syntax: ansi-common-lisp; Package: :matlisp; Base: 10 -*-
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

(in-package #:matlisp)

(defmacro generate-typed-axpy! (func (tensor-class blas-func))
  ;;Be very careful when using functions generated by this macro.
  ;;Indexes can be tricky and this has no safety net
  ;;Use only after checking the arguments for compatibility.
  (let* ((opt (get-tensor-class-optimization tensor-class)))
    (assert opt nil 'tensor-cannot-find-optimization :tensor-class tensor-class)
    `(defun ,func (alpha from to)
       (declare (type ,tensor-class from to)
		(type ,(getf opt :element-type) alpha))
       (if-let (strd-p (blas-copyable-p from to))
	 (,blas-func (number-of-elements from) alpha (store from) (first strd-p) (store to) (second strd-p) (head from) (head to))
	 (let ((f-sto (store from))
	       (t-sto (store to)))
	   (declare (type ,(linear-array-type (getf opt :store-type)) f-sto t-sto))
	   (very-quickly
	     ;;One would question the wisdom in calling the Fortran method here.
	     ;;Simple benchmarks proved that SBCL is as quick as or better than
	     ;;OpenBLAS's methods
	     (mod-dotimes (idx (dimensions from))
	       with (linear-sums
		     (f-of (strides from) (head from))
		     (t-of (strides to) (head to)))
	       do (let ((f-val ,(funcall (getf opt :reader) 'f-sto 'f-of))
			(t-val ,(funcall (getf opt :reader) 't-sto 't-of)))
		    (declare (type ,(getf opt :element-type) f-val t-val))
		    (let ((t-new (+ (* f-val alpha) t-val)))
		      (declare (type ,(getf opt :element-type) t-new))
		      ,(funcall (getf opt :value-writer) 't-new 't-sto 't-of)))))))
       to)))

(generate-typed-axpy! real-typed-axpy! (real-tensor daxpy))
(generate-typed-axpy! complex-typed-axpy! (complex-tensor zaxpy))
;;---------------------------------------------------------------;;

(defgeneric axpy! (alpha x y)
  (:documentation
   " 
 Syntax
 ======
 (AXPY! alpha x y)

 Y <- alpha * x + y

 Purpose
 =======
  Same as AXPY except that the result
  is stored in Y and Y is returned.
")
  (:method :before ((alpha number) (x standard-tensor) (y standard-tensor))
	   (unless (idx= (dimensions x) (dimensions y))
	     (error 'tensor-dimension-mismatch)))
  (:method ((alpha number) (x complex-tensor) (y real-tensor))
    (error 'coercion-error :from 'complex-tensor :to 'real-tensor)))

(defmethod axpy! ((alpha number) (x real-tensor) (y real-tensor))
  (real-typed-axpy! (coerce-real alpha) x y))

(defmethod axpy! ((alpha number) (x real-tensor) (y complex-tensor))
  (let ((tmp (tensor-realpart~ y)))
    (declare (type real-sub-tensor tmp))
    (etypecase alpha
      (cl:real (real-typed-axpy! (coerce-real alpha) x tmp))
      (cl:complex
       (real-typed-axpy! (coerce-real (realpart alpha)) x tmp)
       ;;Move tensor to the imagpart.
       (incf (head tmp))
       (real-typed-axpy! (coerce-real (realpart alpha)) x tmp))))
  y)

(defmethod axpy! ((alpha number) (x complex-tensor) (y complex-tensor))
  (complex-typed-axpy! (coerce-complex alpha) x y))

;;
(defgeneric axpy (alpha x y)
  (:documentation
   "
 Syntax
 ======
 (AXPY alpha x y)

 Purpose
 =======
 Computes  
      
                 ALPHA * X + Y

 where ALPHA is a scalar and X,Y are
 tensors.

 The result is stored in a new matrix 
 that has the same dimensions as Y.

 X,Y must have the same dimensions.
")
  (:method :before ((alpha number) (x standard-tensor) (y standard-tensor))
	   (unless (idx= (dimensions x) (dimensions y))
	     (error 'tensor-dimension-mismatch))))

(defmethod axpy ((alpha number) (x real-tensor) (y real-tensor))
  (let ((ret (if (complexp alpha)
		 (copy! y (apply #'make-complex-tensor (idx->list (dimensions y))))
		 (copy y))))
    (axpy! alpha x ret)))

(defmethod axpy ((alpha number) (x complex-tensor) (y real-tensor))
  (let ((ret (copy! y (apply #'make-complex-tensor (idx->list (dimensions y))))))
    (axpy! alpha y ret)))

(defmethod axpy ((alpha number) (x real-tensor) (y complex-tensor))
  (let ((ret (copy y)))
    (axpy! alpha x ret)))

(defmethod axpy ((alpha number) (x complex-tensor) (y complex-tensor))
  (let ((ret (copy y)))
    (axpy! alpha x ret)))
