(in-package #:matlisp)

;;
(deft/generic (t/lapack-geev! #'subtypep) sym (A lda vl ldvl vr ldvr wr wi))
(deft/method (t/lapack-geev! #'blas-tensor-typep) (sym dense-tensor) (A lda vl ldvl vr ldvr wr wi)
  (let ((ftype (field-type sym)))
    (using-gensyms (decl (A lda vl ldvl vr ldvr wr wi) (lwork xxx))
      `(let (,@decl)
	 (declare (type ,sym ,A)
		  (type index-type ,lda)
		  (type ,(store-type sym) ,wr ,wi))
	 (with-lapack-query ,sym (,xxx ,lwork)
	   (ffuncall ,(blas-func "geev" ftype) ,@(apply #'append (permute! (pair `(
	     (:& :character) (if ,vl #\V #\N) (:& :character) (if ,vr #\V #\N)
	     (:& :integer) (dimensions ,A 0)
	     (:* ,(lisp->ffc ftype) :+ (head ,A)) (the ,(store-type sym) (store ,A)) (:& :integer) ,lda
	     (:* ,(lisp->ffc ftype)) (the ,(store-type sym) ,wr) (:* ,(lisp->ffc ftype)) (the ,(store-type sym) ,wi)
	     (:* ,(lisp->ffc ftype) :+ (if ,vl (head ,vl) 0)) (if ,vl (the ,(store-type sym) (store ,vl)) (cffi:null-pointer)) (:& :integer) (if ,vl ,ldvl 1)
	     (:* ,(lisp->ffc ftype) :+ (if ,vr (head ,vr) 0)) (if ,vr (the ,(store-type sym) (store ,vr)) (cffi:null-pointer)) (:& :integer) (if ,vr ,ldvr 1)
	     (:* ,(lisp->ffc ftype)) ,xxx (:& :integer) ,lwork
	     (:& :integer :output) 0))
									   ;;Flip rwork to the end in the case of {z,c}geev.
									   (make-instance 'permutation-cycle
											  :store (when (subtypep ftype 'cl:complex)
												   (list (idxv 12 11 10 9 8 7 6))))))))))))
;;
(deft/generic (t/lapack-heev! #'subtypep) sym (jobz uplo A lda w))
(deft/method (t/lapack-heev! #'blas-tensor-typep) (sym dense-tensor) (jobz uplo A lda w)
  (using-gensyms (decl (jobz A lda w uplo) (lwork xxx xxr))
    (let ((complex? (subtypep (field-type sym) 'complex))
	  (ftype (field-type sym)))
      `(let (,@decl)
       (declare (type ,sym ,A)
		(type character ,jobz ,uplo)
		(type index-type ,lda)
		(type ,(store-type (realified-type sym)) ,w))
       (with-field-elements ,(realified-type sym) (,@(when complex? `((,xxr (t/fid+ (t/field-type (t/realified-type ,sym))) (* 3 (dimensions ,A 0))))))
	 (with-lapack-query ,sym (,xxx ,lwork)
	   (ffuncall ,(blas-func (if complex? "heev" "syev") ftype)
	     (:& :character) ,jobz (:& :character) ,uplo
	     (:& :integer) (dimensions ,A 0)
	     (:* ,(lisp->ffc ftype) :+ (head ,A)) (the ,(store-type sym) (store ,A)) (:& :integer) ,lda
	     (:* ,(lisp->ffc ftype)) ,w
	     (:* ,(lisp->ffc ftype)) ,xxx (:& :integer) ,lwork
	     ,@(when complex? `((:* ,(lisp->ffc ftype)) ,xxr))
	     (:& :integer :output) 0)))))))

;;
(deft/generic (t/geev-output-fix #'subtypep) sym (wr wi))
(deft/method (t/geev-output-fix #'blas-tensor-typep) (sym dense-tensor) (wr wi)
  (if (clinear-storep sym)
      (using-gensyms (decl (wr))
	`(let (,@decl)
	   (declare (type ,(store-type sym) ,wr))
	   ,wr))
      (let ((csym (complexified-type sym)))
	(using-gensyms (decl (wr wi) (ret i))
	  `(let* (,@decl
		  (,ret (t/store-allocator ,csym (length ,wr))))
	     (declare (type ,(store-type sym) ,wr ,wi)
		      (type ,(store-type csym) ,ret))
	     (very-quickly
	       (loop :for ,i :from 0 :below (length ,wr)
		  :do (t/store-set ,csym (complex (aref ,wr ,i) (aref ,wi ,i)) ,ret ,i)))
	     ,ret)))))
;;
(defgeneric geev! (a &optional vl vr)
  (:documentation "
 Syntax
 ======
 (GEEV! a &optional vl vr)

 Purpose:
 ========
 Computes the eigenvalues and left/right eigenvectors of A.

 For an NxN matrix A, its eigenvalues are denoted by:

	      lambda(i),   j = 1 ,..., N

 The right eigenvectors of A are denoted by v(i) where:

		    A * v(i) = lambda(i) * v(i)

 The left eigenvectors of A are denoted by u(i) where:

		     H                      H
		 u(i) * A = lambda(i) * u(i)

 In matrix notation:
			     -1
		    A = V E V

	   and
			  -1
			 H       H
		    A = U    E  U

 where lambda(i) is the ith diagonal of the diagonal matrix E,
 v(i) is the ith column of V and u(i) is the ith column of U.

 The computed eigenvectors are normalized to have Euclidean norm
 equal to 1 and largest component real.
 ")
  (:method :before ((a tensor) &optional vl vr)
     (assert (typep a 'tensor-square-matrix) nil 'tensor-dimension-mismatch)
     (when vl
       (assert (and (lvec-eq (dimensions a) (dimensions vl)) (typep vl (type-of a)))  nil 'tensor-dimension-mismatch))
     (when vr
       (assert (and (lvec-eq (dimensions a) (dimensions vr)) (typep vr (type-of a)))  nil 'tensor-dimension-mismatch))))

(define-tensor-method geev! ((a dense-tensor :x t) &optional vl vr)
  `(let* ((jobvl (if vl #\V #\N))
	  (jobvr (if vr #\V #\N))
	  (n (dimensions A 0))
	  (wr (t/store-allocator ,(cl a) n))
	  (wi (t/store-allocator ,(cl a) n)))
     (ecase jobvl
       ,@(loop :for jvl :in '(#\N #\V) :collect
	    `(,jvl
	      (ecase jobvr
		,@(loop :for jvr :in '(#\N #\V) :collect
		     `(,jvr
		       (with-columnification (() (A ,@(when (char= jvl #\V) `(vl)) ,@(when (char= jvr #\V) `(vr))))
			 (let ((info (t/lapack-geev! ,(cl a)
						     A (or (blas-matrix-compatiblep A #\N) 0)
						     ,@(if (char= jvl #\N) `(nil 1) `(vl (or (blas-matrix-compatiblep vl #\N) 0)))
						     ,@(if (char= jvr #\N) `(nil 1) `(vr (or (blas-matrix-compatiblep vr #\N) 0)))
						     wr wi)))
			   (unless (= info 0)
			     (if (< info 0)
				 (error "GEEV: Illegal value in the ~:r argument." (- info))
				 (error "GEEV: the QR algorithm failed to compute all the eigenvalues, and no eigenvectors have been computed;
elements ~a:~a of WR and WI contain eigenvalues which have converged." info n)))))))))))
     (let ((ret nil))
       (when vr (push vr ret))
       (when vl (push vl ret))
       (values-list (list* (with-no-init-checks
			       (make-instance ',(complexified-type (cl a))
					      :dimensions (coerce (list (dimensions A 0)) 'index-store-vector)
					      :strides (coerce (list 1) 'index-store-vector)
					      :head 0
					      :store (t/geev-output-fix ,(cl a) wr wi)))
			  ret)))))
;;
(defgeneric heev! (a &optional job uplo?)
  (:documentation "
 Syntax
 ======
 (HEEV! a &optional evec? )

 Purpose:
 ========
 Computes the eigenvalues / eigenvectors of a Hermitian (symmetric) A.
 ")
  (:method :before ((a dense-tensor) &optional (job :n) (uplo? *default-uplo*))
     (assert (typep a 'tensor-square-matrix) nil 'tensor-dimension-mismatch)
     (assert (and (member job '(:v :n)) (member uplo? '(:u :l))) nil 'invalid-arguments)))

(define-tensor-method heev! ((a dense-tensor :output) &optional (job :n) (uplo? *default-uplo*))
  `(let ((evals (zeros (dimensions a 0) ',(realified-type (cl a)))))
     (with-columnification (() (A))
       (let ((info (t/lapack-heev! ,(cl a)
				   (aref (symbol-name job) 0)
				   (aref (symbol-name uplo?) 0)
				   A (or (blas-matrix-compatiblep A #\N) 0)
				   (store evals))))
	 (unless (= info 0)
	   (if (< info 0)
	       (error "(SY/HE)EV: Illegal value in the ~:r argument." (- info))
	       (error "(SY/HE)EV: the algorithm failed to converge; ~a off-diagonal elements of an intermediate tridiagonal form did not converge to zero." info)))))
     (values-n (if (eq job :v) 2 1) evals A)))
;;
(definline geev-fix-up-eigvec (eigval eigvec)
  (let* ((n (dimensions eigval 0))
	 (evec (copy eigvec (complexified-type eigvec)))
	 (tmp (zeros n (complexified-type (class-of eigvec))))
	 (cviewa (slice~ evec 1 0)) (cviewb (slice~ evec 1 0))
	 (cst (aref (strides evec) 1)))
    (iter (with i = 0) (with hd = (head cviewa))
	  (cond
	    ((>= i n) (return nil))
	    ((zerop (cl:imagpart (ref eigval i))) (incf i))
	    (t (setf (slot-value cviewa 'head) (+ hd (* i cst))
		     (slot-value cviewb 'head) (+ hd (* (1+ i) cst)))
	       (copy! cviewb tmp) (copy! cviewa cviewb)
	       (axpy! #c(0 1) tmp cviewa) (axpy! #c(0 -1) tmp cviewb)
	       (incf i 2))))
    evec))

(defun eig (x &optional (job :nn) (uplo *default-uplo*))
  (declare (type (and tensor-square-matrix (satisfies blas-tensorp)) x))
  (let ((*default-tensor-type* (class-of x)))
    (if (clinear-storep (class-of x))
	(ecase job
	  ((:nn :nv :vn :vv)
	   (letv* (((levec? revec?) (mapcar #'(lambda (x) (char= x #\V)) (split-job job))))
	     (geev! (copy x) (when levec? (zeros (dimensions x))) (when revec? (zeros (dimensions x))))))
	  ((:n :v)
	   (heev! (copy x) job uplo)))
	(ecase job
	  ((:nn :nv :vn :vv)
	   (letv* (((levec? revec?) (mapcar #'(lambda (x) (char= x #\V)) (split-job job)))
		   (ret (multiple-value-list (geev! (copy x) (when levec? (zeros (dimensions x))) (when revec? (zeros (dimensions x)))))))
	     (let ((eval (first ret)))
	       (unless (dotimes (i (dimensions x 0) t) (unless (zerop (cl:imagpart (ref eval i))) (return nil)))
		 (setq ret (list* eval (mapcar #'(lambda (x) (geev-fix-up-eigvec eval x)) (cdr ret))))))
	     (values-list ret)))
	  ((:n :v)
	   (heev! (copy x) job uplo))))))

;; (let ((a  #i(randn([3, 3]) + 1i * randn ([3, 3]))))
;;   ;;(octave-send-tensor a "a")
;;   ;;(octave-send "[v, l] = eig(a);~%")
;;   (letv* ((s vl vr (eig a :vv)))
;;     (values #i(a - (/vl)' * diag(s, 2) * vl')
;; 	    #i(a - vr * diag(s, 2) * /vr))
    
;;     ;;(geev! a nil (zeros (dims a) (class-of a)))
   
;;     #+nil(norm #i(vr * diag(s, 2) * /vr - a))
;;     #+nil(norm (t- a (t* v (diag s 2) (inv v))))
;;     #+nil(values (norm (t- (diag~ (octave-read-tensor "l")) s))
;; 	    (norm (t- (octave-read-tensor "v") v))
;; 	    )))
