(in-package #:matlisp)

(defgeneric ref (tensor &rest subscripts)
  (:documentation "
  Syntax
  ======
  (ref store subscripts)

  Purpose
  =======
  Return the element corresponding to subscripts.
"))

(defgeneric (setf ref) (value tensor &rest subscripts))

(labels ((array-subs (obj subscripts)
	   (let ((subs (etypecase (car subscripts)
			 (number subscripts)
			 (cons (car subscripts))
			 (vector (lvec->list (car subscripts))))))
	     (iter (for s on subs)
		   (for i first 0 then (1+ i))
		   (when (< (car s) 0)
		     (rplaca s (modproj (car s) (array-dimension obj i) nil))))
	     subs)))
  (defmethod ref ((obj array) &rest subscripts)
    (apply #'aref obj (array-subs obj subscripts)))
  (defmethod (setf ref) (value (obj array) &rest subscripts)
    (apply #'(setf aref) value obj (array-subs obj subscripts))))

(labels ((list-subs (obj subscripts)
	   (let ((subs (etypecase (car subscripts)
			 (number subscripts)
			 (cons (car subscripts))
			 (vector (lvec->list (car subscripts))))))
	     (assert (= (length subs) 1) nil 'invalid-arguments) (setf subs (car subs))
	     (when (< subs 0) (setf subs (modproj subs (length obj))))
	     subs)))
  (defmethod ref ((obj cons) &rest subscripts)
    (elt obj (list-subs obj subscripts)))
  (defmethod (setf ref) (value (obj cons) &rest subscripts)
    (setf (elt obj (list-subs obj subscripts)) value)))
