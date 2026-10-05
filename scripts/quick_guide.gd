class_name QuickGuide
extends RefCounted
## Fiches courtes consultables depuis Confort, sans interrompre une partie.
const PAGES := [
	{"title": "Commandes communes", "text": "Vise un bouton au laser, puis appuie sur la gâchette.\nA / X : replace le panneau devant toi.\nB / Y : pause dans un jeu.\nMenu gauche en jeu : choisir un autre jeu.\nConfort : menus, gestes et volumes audio."},
	{"title": "Bowling", "text": "Approche la main de la boule.\nGâchette ou poignée : prends-la.\nBalance le bras, puis relâche pour lancer.\nUn lancer doux limite les gestes brusques.\nConfort > Gestes ajuste la puissance des lancers."},
	{"title": "Fléchettes", "text": "Approche la main d'une fléchette.\nGâchette ou poignée : prends-la.\nVise, fais ton geste et relâche.\nEn 301 / 501, vérifie la règle de sortie choisie.\nConfort > Gestes ajuste la puissance des lancers."},
	{"title": "Ping-pong", "text": "Place-toi devant la table, raquette prête.\nAu service, la gâchette lance la balle en l'air.\nFrappe-la ensuite avec ta raquette.\nChoisis Entraînement pour pratiquer les renvois.\nCommence par le niveau Facile."},
	{"title": "Pétanque", "text": "Prends le cochonnet avec la gâchette.\nLance-le entre les repères du terrain.\nPrends une boule avec gâchette ou poignée.\nLance-la doucement, puis relâche la prise.\nConfort > Gestes ajuste la puissance des lancers."},
	{"title": "Mölkky", "text": "Prends le bâton avec gâchette ou poignée.\nLance-le par en-dessous, puis relâche.\nUne quille : son numéro ; plusieurs : leur nombre.\nVise exactement 50 points pour gagner.\nConfort > Gestes ajuste la puissance des lancers."},
	{"title": "Palet", "text": "Prends le maître avec la gâchette.\nLance-le sur la planche.\nPrends un palet avec gâchette ou poignée.\nLance-le en cloche, puis relâche.\nConfort > Gestes ajuste la puissance des lancers."},
	{"title": "Grenouille", "text": "Prends le palet avec gâchette ou poignée.\nLance-le en cloche vers le meuble.\nLa bouche de la grenouille vaut 500 points.\nCinq palets par manche, à tour de rôle.\nChoisis Bar (1,5 m) ou Classique (3 m)."},
	{"title": "Basket", "text": "Prends le ballon avec gâchette ou poignée.\nLance-le en cloche vers l'anneau : plus haut = plus facile.\nPrès 1 point, moyen 2, loin 3.\nEn entraînement : 10 tirs ou chrono de 60 s.\nLa zone Mixte change à chaque tir."},
	{"title": "Billard", "text": "Prends la queue avec gâchette ou poignée.\nFrappe la boule blanche avec la pointe.\nAprès une faute, suis le rappel de placement.\nGâchette sur la blanche, puis relâche pour la poser.\nConfort > Gestes ajuste la puissance de la queue."},
	{"title": "Baby-foot", "text": "Prends une poignée avec gâchette ou poignée.\nDéplace la main pour faire glisser la barre.\nBalaie de la main pour faire tourner et frapper.\nRelâche pour changer de barre.\nConfort > Gestes ajuste la rotation des barres."},
	{"title": "Tir à l'arc", "text": "Choisis Tir, puis la discipline Arc.\nL'arc suit la main choisie dans les réglages.\nGâchette ou poignée de l'autre main : prends la corde.\nTends, vise, puis relâche pour tirer.\nLa flèche part dans l'axe entre tes deux mains."},
	{"title": "Carabine", "text": "Choisis Tir, puis Carabine.\nChoisis la main de tir dans les réglages.\nPlace l'autre main devant pour stabiliser la visée.\nLa gâchette de la main de tir lance un plomb.\nCommence sur la cible à 10 mètres."},
	{"title": "Ball-trap", "text": "Choisis Tir, puis Ball-trap.\nLe fusil suit la main de tir choisie.\nPlace l'autre main devant pour soutenir la visée.\nSuis le plateau et anticipe son déplacement.\nAppuie sur la gâchette de la main de tir."},
	{"title": "Lancer de couteau", "text": "Choisis Tir, puis Couteau.\nPrends un couteau avec gâchette ou poignée.\nFais ton geste vers le rondin, puis relâche.\nCommence à 3 mètres en entraînement.\nConfort > Gestes ajuste la puissance des lancers."},
]
