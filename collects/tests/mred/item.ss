
(require-library "core.ss")

(define my-txt #f)
(define my-lb #f)
(define noisy? #f)

(define mdi-frame #f)
(define (mdi)
  (set! mdi-frame (make-object frame% "Item Test" #f
			       #f #f #f #f
			       '(mdi-parent)))
  (send mdi-frame maximize #t)
  (send mdi-frame show #t))

(define default-parent-frame #f)
(define (parent-frame)
  (set! default-parent-frame (make-object frame% "Item Test Parent" #f
			       100 100))
  (send default-parent-frame show #t))

(when (defined? 'mdi?)
  (when mdi?
    (mdi)))

(define make-frame
  (opt-lambda (% name [parent #f] [x #f] [y #f] [w #f] [h #f] [style '()])
    (make-object % name
		 (or parent mdi-frame default-parent-frame)
		 x y w h
		 (if mdi-frame
		     (cons 'mdi-child style)
		     style))))

(define special-font (send the-font-list find-or-create-font
			   20 'decorative 
			   'normal 'bold
			   #f))

(define (make-h&s cp f)
  (make-object button% "Hide and Show" cp
	       (lambda (b e) (send f show #f) (send f show #t))))

(define (add-hide name w cp)
  (let ([c (make-object check-box% (format "Show ~a" name) cp
			(lambda (c e) (send w show (send c get-value))))])
    (send c set-value #t)))

(define (add-disable name w ep)
  (let ([c (make-object check-box% (format "Enable ~a" name) ep
			(lambda (c e) (send w enable (send c get-value))))])
    (send c set-value #t)))

(define (add-disable-radio name w i ep)
  (let ([c (make-object check-box% (format "Enable ~a" name) ep
			(lambda (c e) (send w enable i (send c get-value))))])
    (send c set-value #t)))

(define (add-change-label name w lp orig other)
  (make-object button% (format "Relabel ~a" name) lp
	       (let ([orig-name (if orig orig (send w get-label))]
		     [changed? #f])
		 (lambda (b e)
		   (if changed?
		       (unless (null? orig-name)
			 (send w set-label orig-name))
		       (send w set-label other))
		   (set! changed? (not changed?))))))

(define (add-focus-note frame panel)
  (define m (make-object message% "focus: ??????????????????????????????" panel))
  (send
   (make-object
    (class-asi timer%
      (inherit start)
      (override
	[notify
	 (lambda ()
	   (when (send frame is-shown?)
	     (send m set-label
		   (let* ([w (with-handlers ([void (lambda (x) #f)])
			       (let ([f (get-top-level-focus-window)])
				 (and f (send f get-focus-window))))]
			  [l (and w (send w get-label))])
		     (format "focus: ~a ~a" (or l "") w)))
	     (start 1000 #t)))])))
   start 1000 #t))

(define (add-pre-note frame panel)
  (define m (make-object message% "pre: ??????????????????????????????" panel))
  (define cm (make-object check-box% "Drop Mouse Events" panel void))
  (define ck (make-object check-box% "Drop Key Events" panel void))
  (lambda (win e)
    (let ([m? (is-a? e mouse-event%)])
      (send m set-label
	    (format "pre: ~a ~a"
		    (if m? "mouse" "key")
		    (let ([l (send win get-label)])
		      (if (not l)
			  win
			  l))))
      (and (not (or (eq? win cm) (eq? win ck)))
	   (or (and m? (send cm get-value))
	       (and (not m?) (send ck get-value)))))))

(define (add-enter/leave-note frame panel)
  (define m (make-object message% "enter: ??????????????????????????????" panel))
  (lambda (win e)
    (when (memq (send e get-event-type) '(enter leave))
      (let ([s (format "~a: ~a"
		    (send e get-event-type)
		    (let ([l (send win get-label)])
		      (if (not l)
			  win
			  l)))])
	(when noisy? (printf "~a~n" s))
	(send m set-label s)))))

(define (add-cursors frame panel ctls)
  (let ([old #f]
	[f-old #f]
	[bc (make-object cursor% 'bullseye)]
	[cc (make-object cursor% 'cross)])
    (make-object check-box% "Control Bullseye Cursors" panel
		 (lambda (c e)
		   (if (send c get-value)
		       (set! old 
			     (map (lambda (b) 
				    (begin0
				     (send b get-cursor)
				     (send b set-cursor bc)))
				  ctls))
		       (map (lambda (b c) (send b set-cursor c))
			    ctls old))))
    (make-object check-box% "Frame Cross Cursor" panel
		 (lambda (c e)
		   (if (send c get-value)
		       (begin
			 (set! f-old (send frame get-cursor))
			 (send frame set-cursor cc))
		       (send frame set-cursor f-old))))
    (make-object check-box% "Busy Cursor" panel
		 (lambda (c e)
		   (if (send c get-value)
		       (begin-busy-cursor)
		       (end-busy-cursor))))))
		       
(define OTHER-LABEL "XXXXXXXXXXXXXXXXXXXXXX")

(define-values (icons-path local-path)
  (let ([d (current-load-relative-directory)])
    (values
     (lambda (n)
       (build-path (collection-path "icons") n))
     (lambda (n)
       (build-path d n)))))

(define on-demand-menu-item%
  (class menu-item% (name . args)
	 (override
	   [on-demand
	    (lambda ()
	      (printf "Menu item ~a demanded~n" name))])
	 (sequence
	   (apply super-init name args))))

(define popup-test-canvas%
  (class canvas% (objects names . args)
    (inherit popup-menu get-dc refresh)
    (public
      [tab-in? #f]
      [last-m null]
      [last-choice #f])
    (override
      [on-paint
       (lambda ()
	 (let ([dc (get-dc)])
	   (send dc clear)
	   (send dc draw-text "Left: popup hide state" 0 0)
	   (send dc draw-text "Right: popup previous" 0 20)
	   (send dc draw-text (format "Last pick: ~s" last-choice) 0 40)
	   (when tab-in?
	     (send dc draw-text "Tab in" 0 60))))]
      [on-event
       (lambda (e)
	 (if (send e button-down?)
	     (let ([x (send e get-x)]
		   [y (send e get-y)]
		   [m (if (or (null? last-m)
			      (send e button-down? 'left))
			  (let ([m (make-object popup-menu% "T&itle"
						(lambda (m e)
						  (unless (is-a? m popup-menu%)
						    (error "bad menu object"))
						  (unless (and (is-a? e control-event%)
							       (memq (send e get-event-type)
								     '(menu-popdown menu-popdown-none)))
						    (error "bad event object"))
						  (printf "popdown ok~n")))]
				[make-callback 
				 (let ([id 0])
				   (lambda ()
				     (set! id (add1 id))
				     (let ([id id])
				       (lambda (m e)
					 (set! last-choice id)
					 (on-paint)))))])
			    (for-each
			     (lambda (obj name)
			       (make-object menu-item%
					    (string-append
					     name ": "
					     (if (send obj is-shown?)
						 "SHOWN"
						 "<h i d d e n>"))
					    m
					    (make-callback)))
			     objects names)
			    (make-object on-demand-menu-item%
					 "[on-demand hook]"
					 m
					 void)
			    m)
			  last-m)])
	       (set! last-m m)
	       (popup-menu m (inexact->exact x) (inexact->exact y)))))]
      [on-tab-in (lambda () (set! tab-in? #t) (refresh))]
      [on-focus (lambda (on?)
		  (when (and tab-in? (not on?))
		    (set! tab-in? #f)
		    (refresh)))])
    (sequence
      (apply super-init args))))

(define prev-frame #f)

(define bitmap%
  (class bitmap% args
    (inherit ok?)
    (sequence
      (apply super-init args)
      (unless (ok?)
	(printf "bitmap failure: ~s~n" args)))))

(define active-frame%
  (class-asi frame%
    (private 
      [pre-on void]
      [el void])
    (rename [super-on-subwindow-event on-subwindow-event]
	    [super-on-subwindow-char on-subwindow-char])
    (override [on-subwindow-event (lambda args 
				    (apply el args)
				    (or (apply pre-on args)
					(apply super-on-subwindow-event args)))]
	      [on-subwindow-char (lambda args 
				   (or (apply pre-on args)
				       (apply super-on-subwindow-char args)))]
	      [on-activate (lambda (on?) (printf "active: ~a~n" on?))]
	      [on-move (lambda (x y) (printf "moved: ~a ~a~n" x y))]
	      [on-size (lambda (x y) (printf "sized: ~a ~a~n" x y))])
    (public [set-info
	     (lambda (ep)
	       (set! pre-on (add-pre-note this ep))
	       (set! el (add-enter/leave-note this ep)))])))

(define (trace-mixin c%)
  (class c% (name . args)
    (override
      [on-superwindow-show
       (lambda (on?)
	 (printf "~a ~a~n" name (if on? "show" "hide")))]
      [on-superwindow-enable
       (lambda (on?)
	 (printf "~a ~a~n" name (if on? "on" "off")))])
    (sequence
      (apply super-init name args))))

(define (make-ctls ip cp lp add-testers ep radio-h? label-h? null-label? stretchy?)
  
  (define return-bmp 
    (make-object bitmap% (icons-path "return.xbm") 'xbm))
  (define bb-bmp
    (make-object bitmap% (icons-path "bb.gif") 'gif))
  (define mred-bmp
    (make-object bitmap% (icons-path "mred.xbm") 'xbm))
  (define nruter-bmp
    (make-object bitmap% (local-path "nruter.xbm") 'xbm))
  
  (define :::dummy:::
    (when (not label-h?)
      (send ip set-label-position 'vertical)))
  
  (define-values (l il)
    (let ([p (make-object horizontal-panel% ip)])
      (send p stretchable-width stretchy?)
      (send p stretchable-height stretchy?)
      
      (let ()
	(define l (make-object (trace-mixin message%) "Me&ssage" p))
	(define il (make-object (trace-mixin message%) return-bmp p))
	
	(add-testers "Message" l)
	(add-change-label "Message" l lp #f OTHER-LABEL)
	
	(add-testers "Image Message" il)
	(add-change-label "Image Message" il lp return-bmp nruter-bmp)
	
	(values l il))))
  
  (define b (make-object (trace-mixin button%)
			 "He&llo" ip 
			 (lambda (b e)
			   (send b enable #f)
			   (sleep/yield 5)
			   (send b enable #t))))
  
  (define ib (make-object (trace-mixin button%) bb-bmp ip void))
  
  ; (define ib2 (make-object button% return-bmp ip void))
  
  (define lb (make-object (trace-mixin list-box%)
			  (if null-label? #f "L&ist")
			  '("Apple" "Banana" "Coconut & Donuts" "Eclair" "French Fries" "Gatorade" "Huevos Rancheros")
			  ip void))
  
  (define cb (make-object (trace-mixin check-box%) "C&heck" ip void))
  
  (define icb (make-object (trace-mixin check-box%) mred-bmp ip void))
  
  (define rb (make-object (trace-mixin radio-box%)
			  (if null-label? #f "R&adio")
			  '("First" "Dos" "T&rio")
			  ip void 
			  (if radio-h?
			      '(horizontal)
			      '(vertical))))
  
  (define irb (make-object (trace-mixin radio-box%)
			   (if null-label? #f "Image Ra&dio")
			   (list return-bmp nruter-bmp)
			    ip void 
			    (if radio-h?
				'(horizontal)
				'(vertical))))
  
  (define ch (make-object (trace-mixin choice%)
			  (if null-label? #f "Ch&oice")
			  '("Alpha" "Beta" "Gamma" "Delta & Rest")
			  ip void))
  
  (define txt (make-object (trace-mixin text-field%)
			   (if null-label? #f "T&ext")
			   ip void
			   "initial & starting"))
  
  (set! my-txt txt)
  (set! my-lb lb)

  (add-testers "Button" b)
  (add-change-label "Button" b lp #f OTHER-LABEL)
  
  (add-testers "Image Button" ib)
  (add-change-label "Image Button" ib lp bb-bmp return-bmp)
  
  (add-testers "List" lb)
  (add-change-label "List" lb lp #f OTHER-LABEL)
  
  (add-testers "Checkbox" cb)
  (add-change-label "Checkbox" cb lp #f OTHER-LABEL)
  
  (add-testers "Image Checkbox" icb)
  (add-change-label "Image Checkbox" icb lp mred-bmp bb-bmp)
  
  (add-testers "Radiobox" rb)
  (add-disable-radio "Radio Item `First'" rb 0 ep)
  (add-disable-radio "Radio Item `Dos'" rb 1 ep)
  (add-disable-radio "Radio Item `Trio'" rb 2 ep)
  (add-change-label "Radiobox" rb lp #f OTHER-LABEL)
  
  (add-testers "Image Radiobox" irb)
  (add-disable-radio "Radio Image Item 1" irb 0 ep)
  (add-disable-radio "Radio Image Item 2" irb 1 ep)
  (add-change-label "Image Radiobox" irb lp #f OTHER-LABEL)
  
  (add-testers "Choice" ch)
  (add-change-label "Choice" ch lp #f OTHER-LABEL)
  
  (add-testers "Text" txt)
  (add-change-label "Text" txt lp #f OTHER-LABEL)
  
  (let ([items (list l il 
		     b ib 
		     lb
		     cb icb 
		     rb irb 
		     ch
		     txt)]
	[names (list "label" "image label"
		     "button" "image button"
		     "list box"
		     "checkbox" "image checkbox"
		     "radio box" "image radiobox"
		     "choice"
		     "text")])
    (make-object choice%
		 "Set Focus"
		 (cons "..." names)
		 lp
		 (lambda (c e)
		   (let ([v (send c get-selection)])
		     (when (positive? v)
		       (send (list-ref items (sub1 v)) focus)
		       (send c set-selection 0)))))
    (cons (make-object popup-test-canvas% 
		       items
		       names
		       cp)
	  items)))

(define (big-frame h-radio? v-label? null-label? stretchy? special-label-font? special-button-font?)
  (define f (make-frame active-frame% "Tester"))
  
  (define hp (make-object horizontal-panel% f))
  
  (define ip (make-object vertical-panel% hp))
  (define cp (make-object vertical-panel% hp))
  (define ep (make-object vertical-panel% hp))
  (define lp (make-object vertical-panel% hp))
  
  (define (basic-add-testers name w)
    (add-hide name w cp)
    (add-disable name w ep))
  
  (define add-testers
    (if stretchy?
	(lambda (name control)
	  (send control stretchable-width #t)
	  (send control stretchable-height #t)
	  (basic-add-testers name control))
	basic-add-testers))
  
  (define fp (make-object vertical-panel% ip))
  
  (define tp (make-object vertical-panel% fp))

  (make-h&s cp f)
  
  (add-testers "Sub-panel" fp)
  
  (send tp set-label "Sub-sub panel")
  (add-testers "Sub-sub-panel" tp)

  (when special-label-font?
    (send tp set-label-font special-font))
  (when special-button-font?
    (send tp set-control-font special-font))
    
  (let ([ctls (make-ctls tp cp lp add-testers ep h-radio? v-label? null-label? stretchy?)])
    (add-focus-note f ep)
    (send f set-info ep)
    
    (add-cursors f lp ctls))

  (send f show #t)
  (set! prev-frame f)
  f)

(define (med-frame plain-slider? label-h? null-label? stretchy? special-label-font? special-button-font?)
  (define f2 (make-frame active-frame% "Tester2"))

  (define hp2 (make-object horizontal-panel% f2))
  
  (define ip2-0 (make-object vertical-panel% hp2))
  (define cp2 (make-object vertical-panel% hp2))
  (define ep2 (make-object vertical-panel% hp2))
  (define lp2 (make-object vertical-panel% hp2))
  
  (define (basic-add-testers2 name w)
    (add-hide name w cp2)
    (add-disable name w ep2))
  
  (define add-testers2
    (if stretchy?
	(lambda (name control)
	  (send control stretchable-width #t)
	  (send control stretchable-height #t)
	  (basic-add-testers2 name control))
	basic-add-testers2))

  (define fp2 (make-object vertical-panel% ip2-0))  
  (define ip2 (make-object vertical-panel% fp2))

  (make-h&s cp2 f2)
  
  (add-testers2 "Sub-panel" fp2)
  (send ip2 set-label "Sub-sub panel")
  (add-testers2 "Sub-sub-panel" ip2)
  
  (when prev-frame
    (add-disable "Previous Tester Frame" prev-frame ep2))
  
  (when (not label-h?)
    (send ip2 set-label-position 'vertical))

  (when special-label-font?
    (send ip2 set-label-font special-font))
  (when special-button-font?
    (send ip2 set-control-font special-font))
  
  (let ()
    (define sh (make-object slider% 
			    (if null-label? #f "H S&lider") 0 10 ip2
			    (lambda (s e)
			      (send gh set-value (* 10 (send sh get-value))))
			    5
			    (if plain-slider? '(horizontal plain) '(horizontal))))
    
    (define sv (make-object slider% 
			    (if null-label? #f "V Sl&ider") 0 10 ip2 
			    (lambda (s e)
			      (send gv set-value (* 10 (send sv get-value))))
			    5
			    (if plain-slider? '(vertical plain) '(vertical))))
    
    (define gh (make-object gauge% 
			    (if null-label? #f "H G&auge") 100 ip2
			    '(horizontal)))
    
    (define gv (make-object gauge% 
			    (if null-label? #f "V Ga&uge") 100 ip2
			    '(vertical)))
    
    (define txt (make-object text-field% 
			     (if null-label? #f "T&ext") ip2 void 
			     "initial & starting"
			     '(multiple)))

    (add-testers2 "Horiz Slider" sh)
    (add-testers2 "Vert Slider" sv)
    (add-testers2 "Horiz Gauge" gh)
    (add-testers2 "Vert Gauge" gv)
    ; (add-testers2 "Text Message" cmt)
    ; (add-testers2 "Image Message" cmi)
    (add-testers2 "Text" txt)
    
    (add-change-label "Horiz Slider" sh lp2 #f OTHER-LABEL)
    (add-change-label "Vert Slider" sv lp2 #f OTHER-LABEL)
    (add-change-label "Horiz Gauge" gh lp2 #f OTHER-LABEL)
    (add-change-label "Vert Gauge" gv lp2 #f OTHER-LABEL)
    (add-change-label "Text" txt lp2 #f OTHER-LABEL)
    

    (let* ([items (list sh sv
			gh gv
			; cmt cmi
			txt)]
	   [canvas  (make-object popup-test-canvas% 
				 items
				 (list "h slider" "v slider"
				       "v gauge" "v gauge"
				       ; "text msg" "image msg"
				       "text")
				 cp2 '(hscroll vscroll))])
      (send canvas accept-tab-focus #t)
      (send canvas init-auto-scrollbars 300 300 0.0 0.0)
      (add-disable "Canvas" canvas ep2)

      (add-focus-note f2 ep2)
      (send f2 set-info ep2)
      
      (add-cursors f2 lp2 (cons canvas items)))

    (send f2 create-status-line)
    (send f2 set-status-text "This is the status line")
    (send f2 show #t)
    (set! prev-frame f2)
    f2))

; Need: check, check-test, and enable via menubar
; All operations on Submenus
(define f%
  (class frame% args
    (private
      ADD-APPLE
      ADD-BANANA
      ADD-COCONUT
      DELETE-APPLE
      DELETE-EXTRA-BANANA
      DELETE-BANANA
      DELETE-COCONUT-0
      DELETE-COCONUT
      DELETE-COCONUT-2
      COCONUT-ID
      DELETE-ONCE
      APPLE-CHECK-ID)
    (private
      menu-bar
      main-menu
      apple-menu
      banana-menu
      coconut-menu
      baseball-ids
      hockey-ids
      enable-item)
    (sequence (apply super-init args))
    (public
      [make-menu-bar
       (lambda ()
	 (let* ([mb (make-object menu-bar% this)]
		[menu (make-object menu% "&Tester" mb)]
		[new (case-lambda 
		      [(l help parent) (make-object menu-item% l parent callback #f help)]
		      [(l help) (make-object menu-item% l menu callback #f help)]
		      [(l) (make-object menu-item% l menu callback)])]
		[sep (lambda () (make-object separator-menu-item% menu))])
	   (set! menu-bar mb)
	   (set! main-menu menu)
	   
	   (set! ADD-APPLE (new "Add Apple" "Adds the Apple menu"))
	   (set! ADD-BANANA (new "Add Banana"))
	   (set! ADD-COCONUT (new "Add Coconut"))
	   
	   (make-object on-demand-menu-item% "Append Donut" menu
			(lambda (m e) 
			  (make-object menu-item% "Donut" apple-menu void)))
	   (sep)
	   (set! DELETE-COCONUT-0 (new "Delete Coconut"))
	   (make-object menu-item% "Delete Apple" menu
			(lambda (m e) 
			  (send apple-menu delete)
			  (set! apple-installed? #f)))
	   
	   (sep)
	   (set! enable-item
		 (make-object checkable-menu-item% "Apple Once Disabled" menu
			      (lambda (m e)
				(send DELETE-ONCE enable
				      (not (send enable-item is-checked?))))))
	   
	   (let ([mk-enable (lambda (on?)
			      (lambda (m e)
				(let ([l (send menu-bar get-items)])
				  (unless (null? (cdr l))
				    (send (cadr l) enable on?)))))])
	     (make-object menu-item% "Disable Second" menu (mk-enable #f))
	     (make-object menu-item% "Enable Second" menu (mk-enable #t)))

	   (let ([make-menu
		  (opt-lambda (title parent help-string)
		    (let ([m (make-object menu% title parent help-string)])
		      (send m delete)
		      m))])
	     (set! apple-menu (make-menu "Apple" mb #f))
	     (set! banana-menu (make-menu "Banana" mb #f))
	     (set! coconut-menu (make-menu "Coconut" apple-menu "Submenu")))
	   
	   (set! COCONUT-ID coconut-menu)

	   (set! DELETE-ONCE (new "Delete Once" #f apple-menu))
	   (set! DELETE-APPLE (new "Delete Apple" "Deletes the Apple menu" apple-menu))
	   (set! APPLE-CHECK-ID (make-object checkable-menu-item% "Checkable" apple-menu void))

	   (set! DELETE-BANANA (new "Delete Banana" #f banana-menu))
	   (set! DELETE-EXTRA-BANANA (new "Delete First Banana Item" #f banana-menu))

	   (set! DELETE-COCONUT (new "Delete Coconut" #f coconut-menu))
	   (set! DELETE-COCONUT-2 (new "Delete Coconut By Position" #f coconut-menu))))]
      
      [callback
       (lambda (op ev)
	 (cond
	  [(eq? op ADD-APPLE)
	   (send apple-menu restore)
	   (set! apple-installed? #t)]
	  [(eq? op ADD-BANANA)
	   (send banana-menu restore)]
	  [(eq? op ADD-COCONUT)
	   (send coconut-menu restore)]
	  [(eq? op DELETE-ONCE)
	   (send DELETE-ONCE delete)]
	  [(eq? op DELETE-APPLE)
	   (send apple-menu delete)
	   (set! apple-installed? #f)]
	  [(eq? op DELETE-BANANA)
	   (send banana-menu delete)]
	  [(eq? op DELETE-EXTRA-BANANA)
	   (send (car (send banana-menu get-items)) delete)]
	  [(or (eq? op DELETE-COCONUT) (eq? op DELETE-COCONUT-0))
	   (send COCONUT-ID delete)]
	  [(eq? op DELETE-COCONUT-2)
	   (send (list-ref (send apple-menu get-items) 3) delete)]))])
    (public
	[mfp (make-object vertical-panel% this)]
	[mc (make-object editor-canvas% mfp)]
	[restp (make-object vertical-panel% mfp)]
	[sbp (make-object horizontal-panel% restp)]
	[mfbp (make-object horizontal-panel% restp)]
	[lblp (make-object horizontal-panel% restp)]
	[badp (make-object horizontal-panel% restp)]
	[e (make-object text%)])
      (sequence
	(send restp stretchable-height #f)
	(send mc min-height 250)
	(send mc set-editor e)
	(send e load-file (local-path "menu-steps.txt")))
      (public
	[make-test-button
	 (lambda (name pnl menu id)
	   (make-object button%
			(format "Test ~a" name) pnl 
			(lambda (b e)
			  (message-box
			   "Checked?"
			   (if (send id is-checked?)
			       "yes"
			       "no")))))]
	[compare
	 (lambda (expect v kind)
	   (unless (or (and (string? expect) (string? v)
			    (string=? expect v))
		       (eq? expect v))
	     (error 'test-compare "~a mismatch: ~s != ~s" kind expect v)))]
	[check-parent
	 (lambda (menu id)
	   (unless use-menubar?
	     (unless (eq? (send id get-parent) menu)
	       (error 'check-parent "parent mismatch: for ~a, ~a != ~a"
		      (send id get-label)
		      (send menu get-label)
		      (send (send (send id get-parent) get-item) get-label)))))]
	[label-test
	 (lambda (menu id expect)
	   (check-parent menu id)
	   (let ([v (send id get-label)])
	     (compare expect v "label")))]
	[top-label-test
	 (lambda (pos expect)
	   (let ([i (send menu-bar get-items)])
	     (and (> (length i) pos)
		  (let ([v (send (list-ref i pos) get-label)])
		    (compare expect v "top label")))))]
	[help-string-test
	 (lambda (menu id expect)
	   (check-parent menu id)
	   (let ([v (send id get-help-string)])
	     (compare expect v "help string")))]
	[find-test
	 (lambda (menu title expect string)
	   (letrec ([find
		     (lambda (menu str)
		       (let ([items (send menu get-items)])
			 (ormap (lambda (i)
				  (and (is-a? i labelled-menu-item<%>)
				       (equal? (send i get-plain-label) str)
				       i))
				items)))]
		    [find-item
		     (lambda (menu str)
		       (or (find menu str)
			   (let ([items (send menu get-items)])
			     (ormap (lambda (i)
				      (and (is-a? i menu%)
					   (find-item i str)))
				    items))))]
		    [v (if use-menubar? 
			   (let ([item (find menu-bar title)])
			     (if item
				 (find-item item string)
				 -1))
			   (find-item menu string))])
	     (compare expect v (format "label search: ~a" string))))]
	[tell-ok
	 (lambda ()
	   (printf "ok~n"))]
	[temp-labels? #f]
	[use-menubar? #f]
	[apple-installed? #f]
	[via (lambda (menu) (if use-menubar? menu-bar menu))]
	[tmp-pick (lambda (a b) (if temp-labels? a b))]
	[apple-pick (lambda (x a b) (if (and use-menubar? (not apple-installed?))
					x
					(tmp-pick a b)))])
      (sequence
	(make-menu-bar)

	(send apple-menu restore)

	(make-object button%
		     "Delete Tester" sbp 
		     (lambda args
		       (send main-menu delete)))
	(make-object button%
		     "Delete First Menu" sbp
		     (lambda args
		       (send (car (send menu-bar get-items)) delete)))
	(make-object button%
		     "Add Tester" sbp
		     (lambda args
		       (send main-menu restore)))
	(make-object button%
		     "Add Delete Banana" sbp
		     (lambda args
		       (send DELETE-BANANA restore)))
	(make-object button%
		     "Counts" sbp
		     (lambda args
		       (message-box
			"Counts"
			(format "MB: ~a; T: ~a; A: ~a; B: ~a"
				(length (send menu-bar get-items))
				(length (send main-menu get-items))
				(length (send apple-menu get-items))
				(length (send banana-menu get-items))))))

	(make-test-button "Apple Item" mfbp apple-menu APPLE-CHECK-ID)
	(make-object button%
		     "Check in Apple" mfbp
		     (lambda args
		       (send APPLE-CHECK-ID check #t)))
	(make-object button%
		     "Toggle Menubar Enable" mfbp
		     (lambda args
		       (send menu-bar enable (not (send menu-bar is-enabled?)))))
	(make-object button%
		     "Toggle Apple Enable" mfbp
		     (lambda args
		       (send apple-menu enable (not (send apple-menu is-enabled?)))))
	
	(make-object button%
		     "Test Labels" lblp 
		     (lambda args
		       (label-test (via main-menu) ADD-APPLE (tmp-pick "Apple Adder" "Add Apple"))
		       (help-string-test (via main-menu) ADD-APPLE (tmp-pick "ADDER" "Adds the Apple menu"))
		       (label-test (via apple-menu) DELETE-APPLE (apple-pick #f "Apple Deleter" "Delete Apple"))
		       (help-string-test (via apple-menu) DELETE-APPLE (apple-pick #f "DELETER"
										   "Deletes the Apple menu"))
		       (label-test (via apple-menu) COCONUT-ID (apple-pick #f "Coconut!" "Coconut"))
		       (help-string-test (via apple-menu) COCONUT-ID (apple-pick #f "SUBMENU" "Submenu"))
		       (label-test (via coconut-menu) DELETE-COCONUT (apple-pick #f "Coconut Deleter" "Delete Coconut")) ; submenu test
		       (help-string-test (via coconut-menu) DELETE-COCONUT (apple-pick #f "CDELETER" #f))
		       (top-label-test 0 (if temp-labels? "Hi" "&Tester"))
		       (top-label-test 1 (if apple-installed? "Apple" #f))
		       (tell-ok)))
	(make-object button%
		     "Find Labels" lblp
		     (lambda args
		       (find-test main-menu (tmp-pick "Hi" "&Tester")
				  ADD-APPLE (tmp-pick "Apple Adder" "Add Apple"))
		       (find-test apple-menu "Apple" (apple-pick -1 DELETE-APPLE DELETE-APPLE)
				  (tmp-pick "Apple Deleter" "Delete Apple"))
		       (find-test apple-menu "Apple" (apple-pick -1 COCONUT-ID COCONUT-ID)
				  (tmp-pick "Coconut!" "Coconut"))
		       (find-test apple-menu "Apple" (apple-pick -1 DELETE-COCONUT DELETE-COCONUT)
				  (tmp-pick "Coconut Deleter" "Delete Coconut"))
		       (tell-ok)))
	(make-object button%
		     "Toggle Labels" lblp
		     (lambda args
		       (set! temp-labels? (not temp-labels?))
		       (let ([menu (via main-menu)])
			 (send ADD-APPLE set-label (tmp-pick "Apple Adder" "Add Apple"))
			 (send DELETE-APPLE set-label (tmp-pick "Apple Deleter" "Delete Apple"))
			 (send COCONUT-ID set-label (tmp-pick "Coconut!" "Coconut"))
			 (send DELETE-COCONUT set-label (tmp-pick "Coconut Deleter" "Delete Coconut"))
			 (send ADD-APPLE set-help-string (tmp-pick "ADDER" "Adds the Apple menu"))
			 (send DELETE-APPLE set-help-string (tmp-pick "DELETER" "Deletes the Apple menu"))
			 (send COCONUT-ID set-help-string (tmp-pick "SUBMENU" "Submenu"))
			 (send DELETE-COCONUT set-help-string (tmp-pick "CDELETER" #f))
			 (send main-menu set-label (if temp-labels? "Hi" "&Tester")))))
	(letrec ([by-bar (make-object check-box%
				      "Via Menubar" lblp
				      (lambda args
					(set! use-menubar? (send by-bar get-value))))])
	  by-bar)
	
	#f)))

(define (menu-frame)
  (define mf (make-frame f% "Menu Test"))
  (set! prev-frame mf)
  (send mf show #t)
  mf)

(define (panel-frame)
  (define make-p% 
    (lambda (panel%)
      (class panel% (parent)
	     (override
		 [container-size
		  (lambda (l)
		    (values (apply + (map car l))
			    (apply + (map cadr l))))]
		 [place-children
		  (lambda (l w h)
		    (let-values ([(mw mh) (container-size l)])
		      (let* ([num-x-stretch (apply + (map (lambda (x) (if (caddr x) 1 0)) l))]
			     [num-y-stretch (apply + (map (lambda (x) (if (cadddr x) 1 0)) l))]
			     [dx (floor (/ (- w mw) num-x-stretch))]
			     [dy (floor (/ (- h mh) num-y-stretch))])
			(let loop ([l l][r null][x 0][y 0])
			  (if (null? l)
			      (reverse r)
			      (let ([w (+ (caar l) (if (caddr (car l)) dx 0))]
				    [h (+ (cadar l) (if (cadddr (car l)) dy 0))])
				(loop (cdr l)
				      (cons (list x y w h) r)
				      (+ x w) (+ y h))))))))])
	       (sequence (super-init parent)))))
  (define f (make-frame frame% "Panel Tests"))
  (define h (make-object horizontal-panel% f))
  (define kind (begin
		 (send h set-label-position 'vertical)
		 (send h set-alignment 'center 'top)
		 (make-object radio-box%
			      "Kind"
			      '("Panel" "Pane")
			      h
			      void)))
  (define direction (make-object radio-box%
				 "Direction"
				 '("Horionztal" "Vertical" "Diagonal" "None")
				 h
				 void))
  (define h-align (make-object radio-box%
			       "H Alignment"
			       '("Left" "Center" "Right")
			       h
			       void))
  (define v-align (make-object radio-box%
			       "V Alignment"
			       '("Top" "Center" "Bottom")
			       h
			       void))
  (make-object button% "Make Container" f
	       (lambda (b e) (do-panel-frame
			      (let ([kind (send kind get-selection)]
				    [direction (send direction get-selection)])
				(case kind
				  [(0) (case direction
					 [(0) horizontal-panel%]
					 [(1) vertical-panel%]
					 [(2) (make-p% panel%)]
					 [else panel%])]
				  [(1) (case direction
					 [(0) horizontal-pane%]
					 [(1) vertical-pane%]
					 [(2) (make-p% pane%)]
					 [else pane%])]))
			      (case (send h-align get-selection)
				[(0) 'left]
				[(1) 'center]
				[(2) 'right])
			      (case (send v-align get-selection)
				[(0) 'top]
				[(1) 'center]
				[(2) 'bottom]))))
  (send f show #t))

(define (do-panel-frame p% va ha)
  (define f (make-frame frame% "Container Test"))
  (define p (make-object p% f))
  (define b (make-object button% "Add List or Bad" p
			 (lambda (b e)
			   (send p add-child 
				 (if (send c get-value)
				     m1
				     l)))))
  (define c (make-object check-box% "Remove List" p
			 (lambda (c e)
			   (if (send c get-value)
			       (send p delete-child l)
			       (send p add-child l)))))
  (define l (make-object list-box% "List Box" '("A" "B" "C") p
			 (lambda (l e)
			   (if (eq? (send e get-event-type) 'list-box)
			       (send p get-children)
			       (send p change-children reverse)))))
  (define p2 (make-object vertical-panel% p '(border)))
  (define m1 (make-object message% "1" p2))
  (define m2 (make-object message% "2" p2))
  (send p set-alignment va ha)
  (send f show #t))

(define (check-callback-event orig got e types silent?)
  (unless (eq? orig got)
    (error "object not the same"))
  (unless (is-a? e control-event%)
    (error "bad event object"))
  (let ([type (send e get-event-type)])
    (unless (memq type types)
      (error (format "bad event type: ~a" type))))
  (unless silent?
    (printf "Callback Ok~n")))

(define (instructions v-panel file)
  (define c (make-object editor-canvas% v-panel))
  (define m (make-object text%))
  (send c set-editor m)
  (send m load-file (local-path file))
  (send m lock #t)
  (send c min-width 520)
  (send c min-height 200))

(define (open-file file)
  (define f (make-object frame% file #f 300 300))
  (instructions f file)
  (send f show #t))

(define (button-frame frame% style)
  (define f (make-frame frame% "Button Test"))
  (define p (make-object vertical-panel% f))
  (define old-list null)
  (define commands (list 'button))
  (define hit? #f)
  (define b (make-object button%
			 "Hit Me" p
			 (lambda (bx e)
			   (set! hit? #t)
			   (set! old-list (cons e old-list))
			   (check-callback-event b bx e commands #f))
			 style))
  (define c (make-object button%
			 "Check" p
			 (lambda (c e)
			   (for-each
			    (lambda (e)
			      (check-callback-event b b e commands #t))
			    old-list)
			   (printf "All Ok~n"))))
  (define e (make-object button%
			 "Disable Test" p
			 (lambda (c e)
			   (sleep 1)
			   (set! hit? #f)
			   (let ([sema (make-semaphore)])
			     (send b enable #f)
			     (thread (lambda () (sleep 0.5) (semaphore-post sema)))
			     (yield sema)
			     (when hit?
			       (printf "un-oh~n"))
			     (send b enable #t)))))
  (instructions p "button-steps.txt")
  (send f show #t))

(define (checkbox-frame)
  (define f (make-frame frame% "Checkbox Test"))
  (define p f)
  (define old-list null)
  (define commands (list 'check-box))
  (define cb (make-object check-box%
			  "On" p
			  (lambda (cx e)
			    (set! old-list (cons e old-list))
			    (check-callback-event cb cx e commands #f))))
  (define t (make-object button%
			 "Toggle" p
			 (lambda (t e)
			   (let ([on? (send cb get-value)])
			     (send cb set-value (not on?))))))
  (define t2 (make-object button%
			  "Simulation Toggle" p
			  (lambda (t e)
			    (let ([on? (send cb get-value)]
				  [e (make-object control-event% 'check-box)])
			      (send cb set-value (not on?))
			      (send cb command e)))))
  (define c (make-object button%
			 "Check" p
			 (lambda (c e)
			   (for-each
			    (lambda (e)
			      (check-callback-event cb cb e commands #t))
			    old-list)
			   (printf "All Ok~n"))))
  (instructions p "checkbox-steps.txt")
  (send f show #t))

(define (radiobox-frame)
  (define f (make-frame frame% "Radiobox Test"))
  (define p f)
  (define old-list null)
  (define commands (list 'radio-box))
  (define hp (make-object horizontal-panel% p))
  (define _ (send hp stretchable-height #f))
  (define callback (lambda (rb e)
		     (set! old-list (cons (cons rb e) old-list))
		     (check-callback-event rb rb e commands #f)))
  (define rb1-l (list "Singleton"))
  (define rb1 (make-object radio-box% "&Left" rb1-l hp callback))
  (define rb2-l (list "First" "Last"))
  (define rb2 (make-object radio-box% "&Center" rb2-l hp callback))
  (define rb3-l (list "Top" "Middle" "Bottom"))
  (define rb3 (make-object radio-box% "&Right" rb3-l hp callback))

  (define rbs (list rb1 rb2 rb3))
  (define rbls (list rb1-l rb2-l rb3-l))
  (define normal-sel (lambda (rb p) (send rb set-selection p)))
  (define simulate-sel (lambda (rb p)
			 (let ([e (make-object control-event% 'radio-box)])
			   (send rb set-selection p)
			   (send rb command e))))
  (define (mk-err exn?)
    (lambda (f)
      (lambda (rb p)
	(with-handlers ([exn? void])
	  (f rb p)
	  (error "no exn raisd")))))
  (define type-err (mk-err exn:application:type?))
  (define mismatch-err (mk-err exn:application:mismatch?))

  (define do-sel (lambda (sel n) (for-each (lambda (rb) (sel rb (n rb))) rbs)))
  (define sel-minus (lambda (sel) (do-sel (type-err sel) (lambda (rb) -1))))
  (define sel-first (lambda (sel) (do-sel sel (lambda (rb) 0))))
  (define sel-middle (lambda (sel) (do-sel sel (lambda (rb) (floor (/ (send rb get-number) 2))))))
  (define sel-last (lambda (sel) (do-sel sel (lambda (rb) (sub1 (send rb get-number))))))
  (define sel-N (lambda (sel) (do-sel (mismatch-err sel) (lambda (rb) (send rb get-number)))))
  (define (make-selectors title sel)
    (define hp2 (make-object horizontal-panel% p))
    (send hp2 stretchable-height #f)
    (make-object button% (format "Select -1~a" title) hp2 (lambda (b e) (sel-minus sel)))
    (make-object button% (format "Select First~a" title) hp2 (lambda (b e) (sel-first sel)))
    (make-object button% (format "Select Middle ~a" title) hp2 (lambda (b e) (sel-middle sel)))
    (make-object button% (format "Select Last~a" title) hp2 (lambda (b e) (sel-last sel)))
    (make-object button% (format "Select N~a" title) hp2 (lambda (b e) (sel-N sel))))
  (make-selectors "" normal-sel)
  (make-selectors " by Simulate" simulate-sel)
  (make-object button% "Check" p
	       (lambda (c e)
		 (for-each
		  (lambda (rb l)
		    (let loop ([n 0][l l])
		      (unless (null? l)
			(let ([a (car l)]
			      [b (send rb get-item-label n)])
			  (unless (string=? a b)
			    (error "item name mismatch: ~s != ~s" a b)))
			(loop (add1 n) (cdr l)))))
		  rbs rbls)
		 (for-each
		  (lambda (rbe)
		    (check-callback-event (car rbe) (car rbe) (cdr rbe) commands #t))
		  old-list)
		 (printf "All Ok~n")))
  (instructions p "radiobox-steps.txt")
  (send f show #t))

(define (choice-or-list-frame list? list-style empty?)
  (define f (make-frame frame% (if list? "List Test" "Choice Test")))
  (define p f)
  (define-values (actual-content actual-user-data)
    (if empty?
	(values null null)
	(values '("Alpha" "Beta" "Gamma")
		(list #f #f #f))))
  (define commands 
    (if list?
	(list 'list-box 'list-box-dclick)
	(list 'choice)))
  (define old-list null)
  (define multi? (or (memq 'multiple list-style)
		     (memq 'extended list-style)))
  (define callback
    (lambda (cx e)
      (when (zero? (send c get-number))
	    (error "Callback for empty choice/list"))
      (set! old-list (cons e old-list))
      (cond
       [(eq? (send e get-event-type) 'list-box-dclick)
	; double-click
	(printf "Double-click~n")
	(unless (send cx get-selection)
	  (error "no selection for dclick"))]
       [else
	; misc multi-selection
	(printf "Changed: ~a~n" (if list?
				    (send cx get-selections)
				    (send cx get-selection)))])
      (check-callback-event c cx e commands #f)))
  (define c (if list?
		(make-object list-box% "Tester" actual-content p callback list-style)
		(make-object choice% "Tester" actual-content p callback)))
  (define counter 0)
  (define append-with-user-data? #f)
  (define ab (make-object button%
			  "Append" p
			  (lambda (b e)
			    (set! counter (add1 counter))
			    (let ([naya (format "~aExtra ~a" 
						(if (= counter 10)
						    (string-append
						     "This is a Really Long Named Item That Would Have Used the Short Name, Yes "
						     "This is a Really Long Named Item That Would Have Used the Short Name ")
						    "")
						counter)]
				  [naya-data (box 0)])
			      (set! actual-content (append actual-content (list naya)))
			      (set! actual-user-data (append actual-user-data (list naya-data)))
			      (if (and list? append-with-user-data?)
				  (send c append naya naya-data)
				  (begin
				    (send c append naya)
				    (when list?
					  (send c set-data 
						(sub1 (send c get-number))
						naya-data))))
			      (set! append-with-user-data?
				    (not append-with-user-data?))))))
  (define cs (when list? 
	       (make-object button%
			    "Visible Indices" p
			    (lambda (b e)
			      (printf "top: ~a~nvisible count: ~a~n"
				      (send c get-first-visible-item)
				      (send c number-of-visible-items))))))
  (define cdp (make-object horizontal-panel% p))
  (define rb (make-object button% "Clear" cdp
			  (lambda (b e)
			    (set! actual-content null)
			    (set! actual-user-data null)
			    (send c clear))))
  (define (delete p)
    (send c delete p)
    (when (<= 0 p (sub1 (length actual-content)))
      (if (zero? p)
	  (begin
	    (set! actual-content (cdr actual-content))
	    (set! actual-user-data (cdr actual-user-data)))
	  (begin
	    (set-cdr! (list-tail actual-content (sub1 p)) 
		      (list-tail actual-content (add1 p)))
	    (set-cdr! (list-tail actual-user-data (sub1 p)) 
		      (list-tail actual-user-data (add1 p)))))))
  (define db (if list?
		 (make-object button%
			      "Delete" cdp
			      (lambda (b e)
				(let ([p (send c get-selection)])
				  (delete p))))
		 null))
  (define dab (if list?
		  (make-object button%
			       "Delete Above" cdp
			       (lambda (b e)
				 (let ([p (send c get-selection)])
				   (delete (sub1 p)))))
		  null))
  (define dbb (if list?
		  (make-object button%
			       "Delete Below" cdp
			       (lambda (b e)
				 (let ([p (send c get-selection)])
				   (delete (add1 p)))))
		  null))
  (define setb (if list?
		   (make-object button%
				"Reset" cdp
				(lambda (b e)
				  (send c set '("Alpha" "Beta" "Gamma"))
				  (set! actual-content '("Alpha" "Beta" "Gamma"))
				  (set! actual-user-data (list #f #f #f))))
		   null))
  (define sel (if list?
		  (make-object button%
			       "Add Select First" cdp
			       (lambda (b e)
				 (send c select 0 #t)))
		  null))
  (define unsel (if list?
		    (make-object button%
				 "Unselect" cdp
				 (lambda (b e)
				   (send c select (send c get-selection) #f)))
		    null))
  (define (make-selectors method mname numerical?)
    (define p2 (make-object horizontal-panel% p))
    (send p2 stretchable-height #f)
    (when numerical?
	  (make-object button%
		       (string-append "Select Bad -1" mname) p2
		       (lambda (b e)
			 (with-handlers ([exn:application:type? void])
			   (method -1)
			   (error "expected a type exception")))))
    (make-object button%
		 (string-append "Select First" mname) p2
		 (lambda (b e)
		   (method 0)))
    (make-object button%
		 (string-append "Select Middle" mname) p2
		 (lambda (b e)
		   (method (floor (/ (send c get-number) 2)))))
    (make-object button%
		 (string-append  "Select Last" mname) p2
		 (lambda (b e)
		   (method (sub1 (send c get-number)))))
    (make-object button%
		 (string-append "Select Bad X" mname) p2
		 (lambda (b e)
		   (with-handlers ([exn:application:mismatch? void]) 
		     (method (if numerical?
				 (send c get-number)
				 #f))
		     (error "expected a mismatch exception"))))
    #f)
  (define dummy-1 (make-selectors (ivar c set-selection) "" #t))
  (define dummy-2 (make-selectors (lambda (p) 
				    (if p
					(when (positive? (length actual-content))
					      (send c set-string-selection 
						    (list-ref actual-content p)))
					(send c set-string-selection "nada")))
				  " by Name"
				  #f))
  (define dummy-3 (make-selectors (lambda (p)
				    (let ([e (make-object control-event% (if list? 'list-box 'choice))])
				      (send c set-selection p)
				      (when list? (send c set-first-visible-item p))
				      (send c command e)))
				  " by Simulate" #t))
  (define tb (make-object button%
			  "Check" p
			  (lambda (b e)
			    (let ([c (send c get-number)])
			      (unless (= c (length actual-content))
				(error "bad number response")))
			    (let loop ([n 0][l actual-content][lud actual-user-data])
			      (unless (null? l)
				      (let ([s (car l)]
					    [sud (car lud)]
					    [sv (send c get-string n)]
					    [sudv (if list?
						      (send c get-data n)
						      #f)])
					(unless (string=? s sv)
					  (error "get-string mismatch"))
					(unless (or (not list?) (eq? sud sudv))
					  (error 'get-data "mismatch at ~a: ~s != ~s"
						 n sud sudv))
					(unless (= n (send c find-string s))
					  (error "bad find-string result")))
				      (loop (add1 n) (cdr l) (cdr lud))))
			    (let ([bad (lambda (exn? i)
					 (with-handlers ([exn? void])
					   (send c get-string i)
					   (error "out-of-bounds: no exn")))])
			      (bad exn:application:type? -1)
			      (bad exn:application:mismatch? (send c get-number)))
			    (unless (not (send c find-string "nada"))
			      (error "find-string of nada wasn't #f"))
			    (for-each
			     (lambda (e)
			       (check-callback-event c c e commands #t))
			     old-list)
			    (printf "content: ~s~n" actual-content)
			    (when multi?
			      (printf "selections: ~s~n" (send c get-selections))))))
  (send c stretchable-width #t)
  (instructions p "choice-list-steps.txt")
  (send f show #t))

(define (slider-frame)
  (define f (make-frame frame% "Slider Test"))
  (define p (make-object vertical-panel% f))
  (define old-list null)
  (define commands (list 'slider))
  (define s (make-object slider% "Slide Me" -1 11 p
			 (lambda (sl e)
			   (check-callback-event s sl e commands #f)
			   (printf "slid: ~a~n" (send s get-value)))
			 3))
  (define c (make-object button% "Check" p
			 (lambda (c e)
			   (for-each
			    (lambda (e)
			      (check-callback-event s s e commands #t))
			    old-list)
			   (printf "All Ok~n"))))
  (define (simulate v)
    (let ([e (make-object control-event% 'slider)])
      (send s set-value v)
      (send s command e)))
  (define p2 (make-object horizontal-panel% p))
  (define p3 (make-object horizontal-panel% p))
  (send p3 stretchable-height #f)
  (make-object button%
	       "Up" p2
	       (lambda (c e)
		 (send s set-value (add1 (send s get-value)))))
  (make-object button%
	       "Down" p2
	       (lambda (c e)
		 (send s set-value (sub1 (send s get-value)))))
  (make-object button%
	       "Simulate Up" p2
	       (lambda (c e)
		 (simulate (add1 (send s get-value)))))
  (make-object button%
	       "Simulate Down" p2
	       (lambda (c e)
		 (simulate (sub1 (send s get-value)))))
  (instructions p "slider-steps.txt")
  (send f show #t))

(define (gauge-frame)
  (define f (make-frame frame% "Gauge Test"))
  (define p (make-object vertical-panel% f))
  (define g (make-object gauge% "Tester" 10 p))
  (define (move d name)
    (make-object button%
		 name p
		 (lambda (c e)
		   (send g set-value (+ d (send g get-value))))))
  (define (size d name)
    (make-object button%
		 name p
		 (lambda (c e)
		   (send g set-range (+ d (send g get-range))))))
  (move 1 "+")
  (move -1 "-")
  (size 1 "Bigger")
  (size -1 "Smaller")
  (instructions p "gauge-steps.txt")
  (send f show #t))

(define (text-frame style)
  (define (handler get-this)
    (lambda (c e)
      (unless (eq? c (get-this))
	(printf "callback: bad item: ~a~n" c))
      (let ([t (send e get-event-type)])
	(cond
	 [(eq? t 'text-field)
	  (printf "Changed: ~a~n" (send c get-value))]
	 [(eq? t 'text-field-enter)
	  (printf "Return: ~a~n" (send c get-value))]))))

  (define f (make-frame frame% "Text Test"))
  (define p (make-object vertical-panel% f))
  (define t1 (make-object text-field% #f p (handler (lambda () t1)) "This should just fit!" style))
  (define t2 (make-object text-field% "Another" p (handler (lambda () t2)) "This too!" style))
  (define junk (send p set-label-position 'vertical))
  (define t3 (make-object text-field% "Catch Returns" p (handler (lambda () t3)) "And, yes, this!"
			  (cons 'hscroll style)))
  (send t1 stretchable-width #f)
  (send t2 stretchable-width #f)
  (send t3 stretchable-width #f)
  (send f show #t))

(define (canvas-frame flags)
  (define f (make-frame frame% "Canvas Test" #f #f 250))
  (define p (make-object vertical-panel% f))
  (define c% (class canvas% (name swapped-name p)
	       (inherit get-dc get-scroll-pos get-scroll-range get-scroll-page
			get-client-size get-virtual-size get-view-start)
	       (rename [super-init-manual-scrollbars init-manual-scrollbars]
		       [super-init-auto-scrollbars init-auto-scrollbars])
	       (public
		 [auto? #f]
		 [incremental? #f]
		 [inc-mode (lambda (x) (set! incremental? x))]
		 [vw 10]
		 [vh 10]
		 [set-vsize (lambda (w h) (set! vw w) (set! vh h))])
	       (override
		[on-paint
		 (lambda ()
		   (let ([s (format "V: p: ~s r: ~s g: ~s H: ~s ~s ~s"
				    (get-scroll-pos 'vertical)
				    (get-scroll-range 'vertical)
				    (get-scroll-page 'vertical)
				    (get-scroll-pos 'horizontal)
				    (get-scroll-range 'horizontal)
				    (get-scroll-page 'horizontal))]
			 [dc (get-dc)])
		     (let-values ([(w h) (get-client-size)]
				  [(w2 h2) (get-virtual-size)]
				  [(x y) (get-view-start)])
		       ; (send dc set-clipping-region 0 0 w2 h2)
		       (unless incremental? (send dc clear))
		       (send dc draw-text (if (send ck-w get-value) swapped-name name) 3 3)
		       ; (draw-line 3 12 40 12)
		       (send dc draw-text s 3 15)
		       (send dc draw-text (format "client: ~s x ~s  virtual: ~s x ~s  view: ~s x ~s" 
						  w h
						  w2 h2
						  x y)
			     3 27)
		       (send dc draw-line 0 vh vw vh)
		       (send dc draw-line vw 0 vw vh))))]
		[on-scroll
		 (lambda (e) 
		   (when auto? (printf "Hey - on-scroll called for auto scrollbars~n"))
		   (unless incremental? (on-paint)))]
		[init-auto-scrollbars (lambda x
					(set! auto? #t)
					(apply super-init-auto-scrollbars x))]
		[init-manual-scrollbars (lambda x
					  (set! auto? #f)
					  (apply super-init-manual-scrollbars x))])
	       (sequence
		 (super-init p flags))))
  (define un-name "Unmanaged scroll")
  (define m-name "Automanaged scroll")
  (define c1 (make-object c% un-name m-name p))
  (define c2 (make-object c% m-name un-name p))
  (define (reset-scrolls for-small?)
    (let* ([h? (send ck-h get-value)]
	   [v? (send ck-v get-value)]
	   [small? (send ck-s get-value)]
	   [swap? (send ck-w get-value)])
      (send c1 set-vsize 10 10)
      (if swap?
	  (send c1 init-auto-scrollbars (and h? 10) (and v? 10) .1 .1)
	  (send c1 init-manual-scrollbars (and h? 10) (and v? 10) 3 3 1 1))
      ; (send c1 set-scrollbars (and h? 1) (and v? 1) 10 10 3 3 1 1 swap?)
      (send c2 set-vsize (if small? 50 500) (if small? 20 200))
      (if swap?
	  (send c2 init-manual-scrollbars (if small? 2 20) (if small? 2 20) 3 3 1 1)
	  (send c2 init-auto-scrollbars (and h? (if small? 50 500)) (and v? (if small? 20 200)) .2 .2))
      ; (send c2 set-scrollbars (and h? 25) (and v? 10) (if small? 2 20) (if small? 2 20) 3 3 1 1 (not swap?))
      (if for-small?
	  ; Specifically refresh the bottom canvas
	  (send c2 refresh)
	  ; Otherwise, we have to specifically refresh the unmanaged canvas
	  (send (if swap? c2 c1) refresh))))
  (define p2 (make-object horizontal-panel% p))
  (define junk (send p2 stretchable-height #f))
  (define ck-v (make-object check-box% "Vertical Scroll" p2 (lambda (b e) (reset-scrolls #f))))
  (define ck-h (make-object check-box% "Horizontal Scroll" p2 (lambda (b e) (reset-scrolls #f))))
  (define ck-s (make-object check-box% "Small" p2 (lambda (b e) (reset-scrolls #t))))
  (define ck-w (make-object check-box% "Swap" p2 (lambda (b e) (reset-scrolls #f))))
  (define ip (make-object horizontal-panel% p))
  (send ip stretchable-height #f)
  (make-object button%
	       "Get Instructions" ip
	       (lambda (b e) (open-file "canvas-steps.txt")))
  (make-object button%
	       "&1/5 Scroll" ip
	       (lambda (b e) (send c2 scroll 0.2 0.2)))
  (make-object button%
	       "&4/5 Scroll" ip
	       (lambda (b e) (send c2 scroll 0.8 0.8)))
  (make-object check-box%
	       "Inc" ip
	       (lambda (c e) 
		 (send c1 inc-mode (send c get-value))
		 (send c2 inc-mode (send c get-value))))
  (send c1 set-vsize 10 10)
  (send c2 set-vsize 500 200)
  (send f show #t))

(define (editor-canvas-oneline-frame)
  (define f (make-frame frame% "x" #f 200 #f))
  
  (define (try flags)
    (define c (make-object editor-canvas% f #f flags))
    
    (define e (make-object text%))
    
    (send e insert "Xy!")
    
    (send c set-line-count 1)
    
    (send c set-editor e)
    (send c stretchable-height #f))

  (send f show #t)
  
  (try '(no-hscroll no-vscroll))
  (try '(no-vscroll))
  (try '(no-hscroll))
  (try '()))

(define (minsize-frame)
  (define f (make-frame frame% "x"))
  
  (define bp (make-object horizontal-panel% f))
  (define tb (make-object button% "Toggle Stretch" bp
			  (lambda (b e)
			    (for-each
			     (lambda (p)
			       (send p stretchable-width (not (send p stretchable-width)))
			       (send p stretchable-height (not (send p stretchable-height))))
			     containers))))
  (define ps (make-object button% "Print Sizes" bp
			  (lambda (b e)
			    (newline)
			    (for-each
			     (lambda (p)
			       (let ([c (car (send p get-children))])
				 (let-values ([(w h) (send c get-size)]
					      [(cw ch) (send c get-client-size)])
				   (printf "~a: (~a x ~a) client[~a x ~a] diff<~a x ~a> min{~a x ~a}~n"
					   c w h cw ch
					   (- w cw) (- h ch)
					   (send c min-width) (send c min-height)))))
			     (reverse containers))
			    (newline))))
  
  (define containers null)

  (define (make-container p)
    (let ([p (make-object vertical-panel% p '())])
      (send p stretchable-width #f)
      (send p stretchable-height #f)
      (set! containers (cons p containers))
      p))
  
  (define hp0 (make-object horizontal-panel% f))

  (define p (make-object panel% (make-container hp0)))
  (define pb (make-object panel% (make-container hp0) '(border)))

  (define hp1 (make-object horizontal-panel% f))

  (define c (make-object canvas% (make-container hp1)))
  (define cb (make-object canvas% (make-container hp1) '(border)))
  (define ch (make-object canvas% (make-container hp1) '(hscroll)))
  (define cv (make-object canvas% (make-container hp1) '(vscroll)))
  (define chv (make-object canvas% (make-container hp1) '(hscroll vscroll)))
  (define cbhv (make-object canvas% (make-container hp1) '(border hscroll vscroll)))

  (define hp2 (make-object horizontal-panel% f))

  (define ec (make-object editor-canvas% (make-container hp2) #f '(no-hscroll no-vscroll)))
  (define ech (make-object editor-canvas% (make-container hp2) #f '(no-vscroll)))
  (define ecv (make-object editor-canvas% (make-container hp2) #f '(no-hscroll)))
  (define echv (make-object editor-canvas% (make-container hp2) #f '()))

  (send f show #t))

;----------------------------------------------------------------------

(define selector (make-frame frame% "Test Selector"))
(define ap (make-object vertical-panel% selector))

; Test timers while we're at it. And create the "Instructions" button.
(let ([clockp (make-object horizontal-panel% ap)]
      [selector selector])
  (make-object button% "Get Instructions" clockp
	       (lambda (b e) 
		 (open-file "frame-steps.txt")))
  (make-object vertical-panel% clockp) ; filler
  (let ([time (make-object message% "XX:XX:XX" clockp)])
    (make-object
     (class timer% ()
	    (inherit start)
	    (override
	     [notify
	      (lambda ()
		(let* ([now (seconds->date (current-seconds))]
		       [pad (lambda (pc d)
			      (let ([s (number->string d)])
				(if (= 1 (string-length s))
				    (string-append pc s)
				    s)))]
		       [s (format "~a:~a:~a"
				  (pad " " (let ([h (modulo (date-hour now) 12)])
					     (if (zero? h)
						 12
						 h)))
				  (pad "0" (date-minute now))
				  (pad "0" (date-second now)))])
		  (send time set-label s)
		  (when (send selector is-shown?)
			(start 1000 #t))))])
	    (sequence
	      (super-init)
	      (start 1000 #t))))))

(define bp (make-object vertical-panel% ap '(border)))
(define bp1 (make-object horizontal-panel% bp))
(define bp2 (make-object horizontal-pane% bp))
(define mp (make-object vertical-panel% ap '(border)))
(define mp1 (make-object horizontal-panel% mp))
(define mp2 (make-object horizontal-pane% mp))

(send bp1 set-label-position 'vertical)
(send mp1 set-label-position 'vertical)

(define pp (make-object horizontal-pane% ap))
(send bp stretchable-height #f)
(make-object button% "Make Menus Frame" pp (lambda (b e) (menu-frame)))
(make-object horizontal-pane% pp)
(make-object button% "Make Panel Frame" pp (lambda (b e) (panel-frame)))
(make-object horizontal-pane% pp)
(make-object button% "Editor Canvas One-liners" pp (lambda (b e) (editor-canvas-oneline-frame)))
(make-object horizontal-pane% pp)
(make-object button% "Minsize Windows" pp (lambda (b e) (minsize-frame)))
(define bp (make-object horizontal-pane% ap))
(send bp stretchable-width #f)
(make-object button% "Make Button Frame" bp (lambda (b e) (button-frame frame% null)))
(make-object button% "Make Default Button Frame" bp (lambda (b e) (button-frame frame% '(border))))
(make-object button% "Make Button Dialog" bp (lambda (b e) (button-frame dialog% null)))
(define crp (make-object horizontal-pane% ap))
(send crp stretchable-height #f)
(make-object button% "Make Checkbox Frame" crp (lambda (b e) (checkbox-frame)))
(make-object vertical-pane% crp) ; filler
(make-object button% "Make Radiobox Frame" crp (lambda (b e) (radiobox-frame)))
(define cp (make-object horizontal-pane% ap))
(send cp stretchable-width #f)
(make-object button% "Make Choice Frame" cp (lambda (b e) (choice-or-list-frame #f null #f)))
(make-object button% "Make Empty Choice Frame" cp (lambda (b e) (choice-or-list-frame #f null #t)))
(define lp (make-object horizontal-pane% ap))
(send lp stretchable-width #f)
(make-object button% "Make List Frame" lp (lambda (b e) (choice-or-list-frame #t '(single) #f)))
(make-object button% "Make Empty List Frame" lp (lambda (b e) (choice-or-list-frame #t '(single) #t)))
(make-object button% "Make MultiList Frame" lp (lambda (b e) (choice-or-list-frame #t '(multiple) #f)))
(make-object button% "Make MultiExtendList Frame" lp (lambda (b e) (choice-or-list-frame #t '(extended) #f)))
(define gsp (make-object horizontal-pane% ap))
(send gsp stretchable-height #f)
(make-object button% "Make Gauge Frame" gsp (lambda (b e) (gauge-frame)))
(make-object vertical-pane% gsp) ; filler
(make-object button% "Make Slider Frame" gsp (lambda (b e) (slider-frame)))
(define tp (make-object horizontal-pane% ap))
(send tp stretchable-width #f)
(make-object button% "Make Text Frame" tp (lambda (b e) (text-frame '(single))))
(make-object button% "Make Multitext Frame" tp (lambda (b e) (text-frame '(multiple))))

(define cnp (make-object horizontal-pane% ap))
(send cnp stretchable-width #t)
(send cnp set-alignment 'right 'center)
(let ([mkf (lambda (flags name)
	     (make-object button%
			  (format "Make ~aCanvas Frame" name) cnp 
			  (lambda (b e) (canvas-frame flags))))])
  (mkf '(hscroll vscroll) "HV")
  (mkf '(hscroll) "H")
  (mkf '(vscroll) "V")
  (mkf null "")
  (make-object grow-box-spacer-pane% cnp))

(define (choose-next radios)
  (let loop ([l radios])
    (let* ([c (car l)]
	   [rest (cdr l)]
	   [n (send c number)]
	   [v (send c get-selection)])
      (if (< v (sub1 n))
	  (send c set-selection (add1 v))
	  (if (null? rest)
	      (map (lambda (c) (send c set-selection 0)) radios)
	      (begin
		(send c set-selection 0)
		(loop rest)))))))

(define make-next-button
  (lambda (p l)
    (make-object button%
		 "Next Configuration" p
		 (lambda (b e) (choose-next l)))))

(define make-selector-and-runner
  (lambda (p1 p2 radios? size maker)
    (define radio-h-radio
      (make-object radio-box% 
		   (if radios? "Radio Box Orientation" "Slider Style")
		   (if radios? '("Vertical" "Horizontal") '("Numbers" "Plain"))
		   p1 void))
    (define label-h-radio
      (make-object radio-box% "Label Orientation" '("Vertical" "Horizontal")
		   p1 void))
    (define label-null-radio
      (make-object radio-box% "Optional Labels" '("Use Label" "No Label")
		   p1 void))
    (define stretchy-radio
      (make-object radio-box% "Stretchiness" '("Normal" "All Stretchy")
		   p1 void))
    (define label-font-radio
      (make-object radio-box% "Label Font" '("Normal" "Big")
		    p1 void))
    (define button-font-radio
      (make-object radio-box% "Control Font" '("Normal" "Big")
		    p1 void))
    (define next-button
      (make-next-button p2 (list radio-h-radio label-h-radio label-null-radio 
				 stretchy-radio label-font-radio button-font-radio)))
    (define go-button
      (make-object button% (format "Make ~a Frame" size) p2
		   (lambda (b e)
		     (maker
		      (positive? (send radio-h-radio get-selection))
		      (positive? (send label-h-radio get-selection))
		      (positive? (send label-null-radio get-selection))
		      (positive? (send stretchy-radio get-selection))
		      (positive? (send label-font-radio get-selection))
		      (positive? (send button-font-radio get-selection))))))
    #t))

(make-selector-and-runner bp1 bp2 #t "Big" big-frame)
(make-selector-and-runner mp1 mp2 #f "Medium" med-frame)

(send selector show #t)