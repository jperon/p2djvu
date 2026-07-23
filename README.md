# p2djvu

**p2djvu** convertit vos fichiers PDF en fichiers DjVu — un format qui donne des documents beaucoup plus légers que le PDF d'origine, tout en restant net et lisible, pages scannées comme documents texte.

## Installation

Si vous avez [Nix](https://nixos.org) installé, aucune autre installation n'est nécessaire :

```
nix run github:jperon/p2djvu -- mon-document.pdf mon-document.djvu
```

Ou, si vous avez récupéré le projet en local :

```
nix build .
./result/bin/p2djvu mon-document.pdf mon-document.djvu
```

## Utilisation de base

```
p2djvu mon-document.pdf mon-document.djvu
```

C'est tout : p2djvu lit le PDF, convertit chaque page et écrit le fichier DjVu. Un message s'affiche pour chaque page traitée, afin de suivre la progression sur les documents longs.

## Choisir le mode de sortie

Selon la nature du document, un des trois modes suivants donnera un meilleur résultat (taille et/ou qualité) :

```
p2djvu --mode color mon-document.pdf mon-document.djvu
```

- **`color`** (mode par défaut si vous ne précisez rien) : conserve les niveaux de gris et les couleurs. C'est le choix le plus sûr et le plus robuste, quel que soit le document — BD, magazines, scans couleur, documents avec illustrations, photos ou trames.
- **`bw`** : noir et blanc pur. Idéal pour un document strictement composé de texte imprimé net (pas d'illustration ni de trame grise), donne les fichiers les plus légers.
- **`mixed`** : sépare le texte net (mis au premier plan) du reste de la page (mis en arrière-plan, en plus basse résolution), pour alléger encore le fichier — souvent nettement plus que `color` sur un document adapté. À réserver aux documents de texte pur avec éventuellement quelques photos : sur des illustrations détaillées, hachurées ou nuancées, ce mode peut mal évaluer ce qui est « texte » et produire des pages noircies ou abîmées. Avant d'abandonner ce mode pour `color`, essayez de le rééquilibrer avec `--threshold-bias` (voir ci-dessous) : sur bien des documents « limites » (BD au trait fin, scans un peu sombres…), un simple réglage suffit à obtenir un `mixed` propre et plus léger que `color`.

### Rééquilibrer le mode `mixed` (pages noircies ou trouées)

Le mode `mixed` décide pixel par pixel ce qui est « encre » (mis au premier plan, net) ou « fond » (mis en arrière-plan, plus flou) à partir d'un seuil de luminosité calculé automatiquement sur chaque page. Sur certains documents (dessins très hachurés, scans sombres ou au contraste inhabituel), ce seuil automatique se trompe et produit des pages entièrement noires, ou au contraire des pages où le texte a disparu.

Deux options permettent de corriger ce réglage :

```
p2djvu --mode mixed --threshold-bias -80 mon-document.pdf mon-document.djvu
```

- **`--threshold-bias N`** : décale le seuil calculé automatiquement. Si vos pages ressortent trop noires (trop de « fond » classé à tort comme « encre »), diminuez-le (valeurs négatives, par exemple `-50`, `-80`, voire `-100`) jusqu'à obtenir un résultat propre. À l'inverse, si le texte ressort trop pâle ou disparaît, augmentez-le (valeurs positives). Il n'y a pas de valeur universelle : partez de `-50`, et ajustez par pas de 20-30 en regardant le résultat.
- **`--threshold N`** : impose un seuil absolu (de 0 = tout au fond, à 255 = tout à l'encre), sans passer par le calcul automatique. Utile si `--threshold-bias` ne suffit pas, ou pour reproduire exactement le même réglage sur toutes les pages d'un document dont la luminosité varie peu d'une page à l'autre.

Dans les deux cas, le plus simple est de tester d'abord sur une seule page en extrayant un court PDF (par exemple avec un outil comme `gs` ou `qpdf`), afin de trouver rapidement le bon réglage avant de lancer la conversion complète.

## Ajuster la résolution

```
p2djvu --dpi 200 mon-document.pdf mon-document.djvu
```

Plus la valeur est élevée, plus le résultat est net mais volumineux. 300 (valeur par défaut) convient à un document destiné à être imprimé ou zoomé ; 150-200 suffit largement pour une lecture à l'écran et donne des fichiers nettement plus légers.

## Autres options utiles

- `--no-text` : ne pas essayer de récupérer le texte du PDF pour le rendre recherchable/sélectionnable dans le DjVu (utile si cette étape ralentit inutilement la conversion sur un document dont vous savez qu'il n'a pas de texte).
- `--ocr` : si le PDF ne contient pas de texte intégré (cas d'un document simplement scanné, sans reconnaissance de caractères), tente de le reconnaître automatiquement pour que le DjVu produit reste malgré tout consultable/recherchable. Cette étape supplémentaire ralentit la conversion.
- `--bg-width N` : en mode `mixed`, largeur (en pixels) à laquelle est réduit l'arrière-plan des pages. Une valeur plus basse allège le fichier au prix d'un arrière-plan plus flou.

## Combien de temps ça prend, quelle taille obtenir ?

À titre indicatif, un document de plus de 100 pages se convertit généralement en une à quelques minutes. La taille finale dépend beaucoup du contenu (texte, photos, trames…) et du mode choisi : n'hésitez pas à essayer `--mode bw` sur un document texte pour comparer, ou à baisser le `--dpi` si le fichier obtenu est encore trop lourd à votre goût.

## En cas de problème

Le message d'erreur affiché indique en général la cause (fichier introuvable, PDF corrompu, etc.). Si un document scanné produit des pages noircies ou abîmées en mode `mixed`, essayez d'abord `--threshold-bias` (voir plus haut) pour rééquilibrer le seuillage ; si cela ne suffit pas, repassez à `--mode color`, qui reste le choix le plus robuste quel que soit le contenu.

## Licence

p2djvu est distribué sous licence MIT (voir [LICENSE](LICENSE)).
