;Coderight de Moon Cactus       Montreuil-Juigné, le 12 11 91 v3.5 2401

;-------------------------------------------------------------
;Touches utilisables pour paramétrer la vue:
;	curseur	déplace la fenetre
;	( et )	profondeur de calcul (maxiter)
;	- et +	pour zoom arrière/avant (il agit à partir du coin en
;		bas à droite: il faut placer la partie que l'on veut
;		agrandir dans ce coin avant d'appuyer sur +: éssayez!)
;
;-------------------------------------------------------------
;Registres utilisés sur l'ensemble du programme:
;	constantes:	a0=pointeur sur echy+2,	a6=out
;	variables:	a3=ix,	a5=echx,
; et a4=adresse vidéo en cours (et pour tous les traitements de ram écran)
;
;Registres utilisés dans la boucle principale seulement (itérations)
;	d1=it	d2=x	d3=y	d4=x2	d5=y2	d6=x/sqr(f)	d7=y/sqr(f)
;	a1=cx	a2=cy
;
;Enfin:	d0 temporaire (calculs intermédiaires)
;-------------------------------------------------------------


;Ces deux "flags" règlent l'assemblage conditionnel:
mono=1		;mettre à 1 si on travaille en monochrome, mais 0 si boot=1
boot=0		;flag qui indique s'il faut assembler en executable (.PRG)
		;ou s'il faut fournir un fichier à installer en boot

f=16777216	;2^24: position de la virgule fixe dans les entiers longs
out=4*f		;valeur de sortie (infini relatif) (40*f pour du folklo!)

xmin=-28*f/10	;-2.8	;définition de la fenètre d'origine (x minimal,
xmax=2*f	; 2.0	;x maximal, y minimal, y maximal). Mettez la
ymin=-15*f/10	;-1.5	;valeur réelle multipliée par f.
ymax=15*f/10	; 1.5

prof=31		;profondeur de calcul (maxiter) initiale
lx=320		;taille de la fenetre en pixels (320*200)
ly=200		;moins innocent qu'il n'y parait: il ne suffit pas
		;de changer ces valeurs pour changer la taille (il
		;faut aussi revoir quelques coins du source!)

	ifeq boot	;initialisations à faire si l'on assemble en .PRG

;Rem: l'instruction "ifeq" permet l'assemblage conditionnel:
;si boot=0 (eq=equal 0) alors on assemble la partie entre le ifeq et le
;endc; dans l'autre cas, il n'éxiste pas dans l'executable...

	pea	mandel(pc)
	move	#$26,-(a7)
	trap	#14	;appel en superviseur (en boot, on y est à défaut)
	addq.l	#6,a7
	clr	-(a7)
	trap	#1	;fin
	endc
	ifne boot	;si fichier à installer en boot, bloc de donnee:
;ici, "ifne" signifie "if not equal", c'est-à-dire "si boot<>0"
	bra.s	mandel	;faire le bra.s puis laisser la place pour
	ds.b 30		;les infos disque (nb pistes, secteurs...)
	endc



;---------------------------- Début du code proprement dit (pas trop tot!)

mandel	
	ifeq boot	;initialisations nécéssaires si en executable PRG,
	ifeq mono	;et si on n'est pas en monochrome:
	clr.b	$ffff8260.w	;passage forcé en basse résolution
	clr.b	$ffff820a.w	;secouer l'écran (50-60Hz) pour limiter
	stop	#$2300		;les problemes de décalages de plans au
	move.b	#2,$ffff820a.w	;changement de résolution; mettez une
;une ligne de fullscreen a la place car c'est bien plus efficace...
	endc
	endc		;pseudo-mnémonique "fin de condition"



;------------------------------ Gestion des résolutions (basse/haute)

	lea	echy+2(pc),a0	;pointeur (sur la valeur de echy) auquel
		;se réferreront toutes les automodifications ultérieures

	btst.b	#1,$ffff8260.w	;haute résolution: %10; basse:%00; moy %01
;remarque: pas de tst.b car un des 6 autres bits peut parfois etre à 1!
;on est à défaut en basse résolution en boot (pas sur le dernier tos TT!)
	beq.s	okrez		;pas haute

; traitement du plot haute résolution: modifications dues à la
; structure écran, suivi du détournement (bra.s finplot) après
; le traitement du plan 0 en couleur (1 seul plan en monochrome):

	;la ligne suivante est carrément du code machine: $6000 pour le
	;bra.s, plus la valeur du saut sur 1 octet:
	
	move	#$6000+finplot-bit1-2,bit1-echy-2(a0)	;sympa les offsets!

;traitement des problèmes d'échelles: le asr divise par 2
;sans prendre beaucoup d'octets en mémoire...
	asr	(a0)			;echy/2
	asr	echx-echy(a0)		;echx/2
	asl	max_x-echy(a0)	;lx=320*2=640 pixels
	addq.w	#6,adrdeb-echy(a0)	;début du compteur 2 octet
;avant la fin de la mémoire video: le lea 32000-8(a4),a4 devient 32000-2
	addq.b	#4,sublarg-2-echy(a0)	;2 octets/16 pixels et non 8
;en effet, subq #8,a4 étant codé en mémoire sous la forme $514C, on
;retombe sur un subq #2,a4 ($554C) en aditionnant 4 au premier octet!

;------------------------------ Initialisations diverses

okrez	move	sr,-(a7)	;stocker l'état du registre d'état(!)
	move	#$2700,sr	;couic: plus d'interruptions (ou presque)

	movem.l	palett(pc),d0-d7	;installer notre palette
	movem.l	d0-d7,$ffff8240.w	;de couleurs (degradé)
	pea	texte(pc)
	move	#9,-(a7)
	trap	#1		;affiche le blabla
	addq.l	#6,a7
	lea	out,a6		;constante de sortie

;certains vont dire: "bouffer un registre sur tout le programme, c'est
;affreux", mais je leur repond: il m'en reste! la preuve, j'utilise le
;dernier (et encore, je ne compte pas A7 et A7'!):

echx	move.l	#-(xmax-xmin)/lx,a5	;échelle des abscisses
	

;------------------------------ Début d'une nouvelle image

begin	
	move.l	$44e.w,a4	;a4 pointe ainsi sur la
adrdeb	lea	32000-8(a4),a4	;fin de la mémoire video (-2 pour 16 pix)

;------------------------------------------- CALCUL DU MANDELBROT
co_y	move.l	#ymin,a2	;a2=cy (partie imaginaire de l'affixe)

next_iy				;ordonnée suivante
co_x	move.l	#xmax,a1	;a1=cx (partie réelle de l'affixe)
max_x	move	#lx,a3		;compteur abscisse (pixels)

next_ix				;abscisse suivante
	move.l	a1,d2		;d2=x=cx au début
	move.l	a2,d3		;d3=y=cy au début
iter	moveq	#prof,d1	;compteur d'itération (automodifié)
	bra.s	optim		;optimisation (première itération)



;----------------------- Itération principale suivante (pour chaque point)

next_it
;------------------------calcul de x=cx+x2-y2
	move.l	d4,d2		;x=x2
	sub.l	d5,d2		;-y2
	add.l	a1,d2		;+cx

;------------------------calcul de y=cy+2*(x/sqf)*(y/sqf)
	move	d6,d3		;x/sq2
	muls	d7,d3		;*y/sq2
	add.l	d3,d3		;*2
	add.l	a2,d3		;+cy

optim	move.l	d3,d7		;calcul de d7=y/sqr(f)
	asl.l	#4,d7		;division subtile,
	swap	d7		;mais rapide!
	move	d7,d5		;calcul de d5=y2=(d7)^2
	muls	d5,d5		;précalculez pour aller (bien) plus vite

;------------------------calcul de xdsqf=d6 et x2=d4
	move.l	d2,d6		;calcul de d6=x/sqr(f)
	asl.l	#4,d6
	swap	d6
	move	d6,d4		;calcul de d4=x2
	muls	d4,d4

;------------------------calcul puis test de x2+y2
	move.l	d4,d0		;d0=x2
	add.l	d5,d0		;+y2
	sub.l	a6,d0		;-out: résultat positif si x2+y2>out
;-------------------------------itération suivante
	dbpl	d1,next_it	;sort si d1=-1 ou si flag positif
	bmi.s	finplot		;si pas flag positif, alors pas plot!



;------------------------------ Affichage d'un point

	and	#31,d1		;d1=profondeur a la sortie de la boucle
	cmp	#15,d1		;>15?
	bls.s	okcol		;la couleur est ok
	not	d1		;plus rapide que 32-d1, meme resultat ici
	;(les couleurs font donc 0->15 puis 15->0 avant de boucler)
okcol
mask	move	#1,d4		;masque en cours (automodifié): 1 bit/16
	lsr	d1		;bit 0 mis?
	bcc.s	bit1		;si pas de retenue, on saute
	or	d4,(a4)		;bit spécifique du plan 1 mis a 1
bit1	lsr	d1		;bit 1 mis?
;Rem: le "lsr d1" est automodifié en "bra.s finplot" en haute résolution
	bcc.s	bit2
	or	d4,2(a4)	;on positionne a 1 le bit sur le plan 2
bit2	lsr	d1		;bit 2 mis?
	bcc.s	bit3
	or	d4,4(a4)	;bit mis sur le plan 3
bit3	lsr	d1		;bit 3 mis?
	bcc.s	finplot		;si pas de retenue, fin du plot
	or	d4,6(a4)	;bit mis sur le plan 4
;remarquez: j'ai evite le "btst" et "bset" qui sont affreusement lents!

finplot	
	rol	mask-echy(a0)	;rotation du bit dans le masque (d4)
	bcc.s	no_adr		;retenue: on a fait un tour complet, et on
sublarg	subq	#8,a4		;passe au bloc suivant (8 octets/16 pixels
				;ou 2 octets/16 pixels en haute résolution)
no_adr

;------------------------------ Point suivant (x précédent)

ech1	add.l	a5,a1		;abscisse réelle suivante
	subq	#1,a3		;abscisse pixel décrementée
	move	a3,d0		;force le test de nullité (4 cycles)
	bne.s	next_ix		;si positif, on continue



;-------------------------------------------------------
;On vient donc ici de finir une ligne horizontale; j'en profite pour
;tester le clavier (plutot que de le faire a chaque point!)...


;-------------------------- Test du clavier (paramétrage de l'utilisateur)

testkey	move.b	$fffffc02.w,d7	;port de sortie du clavier
	sub.b	#$39,d7		;espace?
	bne.s	key2		;non: saut au prochain test clavier
	rte			;oui: on termine (vicieusement)

key2	;on prépare les registres pour optimiser la taille du programme
	;puisque les deux routines (pour + et -) sont presques identiques

;rem: a0 pointe toujours sur la valeur de l'échelle y (adresse echy+2)...
	move.l	(a0),d0		;sort la valeur
	lsr.l	#4,d0		;facteur (plus pour un zoom moins fort)

;les deux lignes qui suivent relèvent de la bidouille!!
	and.l	#f/4-1,d0	;évite de prendre des valeurs trop grandes
	addq.b	#8,d0		;et ceci pour garder un minimum!
;Remarque: en effet, si l'on s'amuse à réduire un peu trop loin la
;fenetre visible, il arrive que l'on ne puisse revenir a une vue de
;plus près, ca n'est pas encore parfait, mais il faut etre vicieux
;pour vouloir réduire "à fond". Autre chose: on ne devrait voir
;qu'un seul Mandelbrot et non plusieurs; cela vient des overflows!

	sub.b	#$11,d7		;touche $4a "-":retrozoom
	bne.s	key3		;ah non?
	neg.l	d0		;et si!: hop, valeur négative
modifec	sub.l	d0,(a0)		;on additionne algébriquement à la valeur
				;en cours de l'échelle y
	add.l	d0,a5		;idem, échelle x (registre a5)

retdebu	move	#32000/4-1,d0	;efface l'écran puis retourne au debut
	move.l	$44e.w,a4	;(pour tracer une nouvelle image)
cls	clr.l	(a4)+
	dbf	d0,cls
	bra	begin		;.s evidemment impossible! (quand meme!)



;-----------------petite inclusion en plein milieu des tests de touches

	;ce n'est pas tres beau (lisibilité), mais cela permet de faire
	;à la fin un "bra.S finkey" autrement impossible (a cause de l'
	;éloignement), et ça ne ralentit rien!

finkey		;Suite et fin: bouclage des lignes horizontales

echy	add.l	#(ymax-ymin)/ly,a2	;coordonée y suivante. Remarque:
		;le signe est l'opposé de celui pour x pour retablir la
		;vraie position de l'origine (en bas à gauche)
	cmp.l	$44e.w,a4	;a4 (adr video) au début de la mem.écran?
	bpl	next_iy		;non: on n'est toujours pas en haut
	bra.s	testkey		;on a tout fini! boucle sur le test clavier
;----------------------------------------------------------------------



key3	subq.b	#4,d7		;touche $4e "+":zoom
	beq.s	modifec		;on ne touche pas a d0, on va l'aditionner

key4	moveq	#0,d0		;gestion des déplacement de la fenetre:
	moveq	#0,d1		;virer les poids forts
	move.l	(a0),d2		;attraper la valeur de l'échelle
	asl.l	#2,d2		;*4	multiplier sinon, deplacements
				;	trop lents! (mais plus précis)
	move.l	d2,d3		;d2=d3=échelle*4
	neg.l	d3		;d2 incrément positif, d3 négatif
		;ainsi, les déplacements se font par pas de 4 pixels,
		;indépendament du facteur de zoom (le pied!)...

	addq.b	#6,d7		;curseur haut ($48)
	bne.s	key5
	move.l	d3,d1		;d0 nul et d1 négatif
modifco	add.l	d0,co_x-echy(a0) ;aditionne d0 a l'abscisse de la fenetre
	add.l	d1,co_y-echy(a0) ;aditionne d1 a l'ordonnée
	bra.s	retdebu		;poursuit plus haut (cls et retour)

key5	subq.b	#3,d7		;curseur gauche ($4b)
	bne.s	key6
	move.l	d2,d0		;d0 positif et d1 nul
	bra.s	modifco
key6	subq.b	#2,d7		;curseur droit ($4d)
	bne.s	key7
	move.l	d3,d0		;d0 négatif et d1 nul
	bra.s	modifco
key7	subq.b	#3,d7		;curseur bas ($50)
	bne.s	key8
	move.l	d2,d1		;d0 nul et d1 positif
	bra.s	modifco

key8	sub.b	#$13,d7		;touche $63 "(":diminue la
	bne.s	key9		;profondeur de calcul
	moveq	#-1,d0		;décremente
modifpr	add.b	d0,iter-1-echy(a0) ;automodifié; intervalle 0-255 (.b)
	bra.s	retdebu
key9	subq.b	#1,d7		;touche $64 ")":augmente la profondeur
	bne.s	finkey		;sinon, test terminé, ligne suivante...
	moveq	#1,d0		;incrémente
	bra.s	modifpr


;-----------------------------------------------Datas: texte et palette
	
texte	dc.b 27,'v',27,'f'	;séquences escape: f désactive le curseur
				;et v active le wrap en fin de ligne
	dc.b 'Coded by Moon Cactus from "Albedo 0.12" '
	dc.b 'You can use ()-+ and the cursor keys'
	;rem:le 0 de fin de texte est aussi la valeur de la couleur 0!
palett	dc.w $000,$001,$002,$003,$004,$005,$006,$007	;palette
	dc.w $017,$027,$037,$047,$057,$067,$077,$777	;(non?!)
