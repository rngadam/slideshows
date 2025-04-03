#!/bin/bash
set -e

PDF_URL="$1"
BUILD_DIR="$2"

# --- Validations ---
if [ -z "$PDF_URL" ] || [ -z "$BUILD_DIR" ]; then
  echo "Usage: $0 <pdf_url> <build_dir>"
  exit 1
fi

echo "Processing URL: $PDF_URL"
echo "Build directory: $BUILD_DIR"

# --- Téléchargement et Hash ---
TMP_DIR=$(mktemp -d)
PDF_FILENAME="$TMP_DIR/downloaded.pdf" # Nom temporaire

echo "Downloading PDF..."
# Utiliser des guillemets autour du nom de fichier
curl -L -o "$PDF_FILENAME" -f "$PDF_URL"
if [ $? -ne 0 ]; then
    echo "::error::Failed to download PDF from $PDF_URL"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Utiliser des guillemets pour le calcul du hash
PDF_SHA256=$(sha256sum "$PDF_FILENAME" | awk '{ print $1 }')
# Essayer d'extraire un nom de l'URL (simpliste, peut être amélioré)
URL_FILENAME=$(basename "$PDF_URL" | sed 's/\?.*//') # Enlève les query params
if [[ "$URL_FILENAME" == *.pdf ]]; then
    PDF_BASENAME="$URL_FILENAME"
else
    PDF_BASENAME="$PDF_SHA256.pdf" # Nom par défaut si extraction échoue
fi
echo "PDF SHA256: $PDF_SHA256"
echo "PDF Basename (derived): $PDF_BASENAME"


OUTPUT_SUBDIR="$BUILD_DIR/$PDF_SHA256"

# --- Vérification d'existence (Idempotence/Cache) ---
if [ -d "$OUTPUT_SUBDIR" ]; then
  echo "::warning::Output directory $OUTPUT_SUBDIR already exists. Skipping processing for $PDF_URL."
  # S'assurer que le fichier de nom existe même si on saute
  if [ ! -f "$OUTPUT_SUBDIR/pdf_basename.txt" ]; then
       echo "$PDF_BASENAME" > "$OUTPUT_SUBDIR/pdf_basename.txt"
  fi
  rm -rf "$TMP_DIR"
  exit 0
fi

echo "Creating output directory: $OUTPUT_SUBDIR"
mkdir -p "$OUTPUT_SUBDIR"

# --- Sauvegarde du nom de base ---
echo "$PDF_BASENAME" > "$OUTPUT_SUBDIR/pdf_basename.txt"

# --- Conversion et Compression (avec guillemets) ---
echo "Converting PDF to PNG images..."
# Utiliser des guillemets
pdftoppm "$PDF_FILENAME" "$OUTPUT_SUBDIR/slide" -png
if [ $? -ne 0 ]; then
    echo "::error::Failed to convert PDF to images for $PDF_SHA256 (from URL)."
    rm -rf "$TMP_DIR" # Nettoyer aussi le dossier temporaire
    rm -rf "$OUTPUT_SUBDIR"
    exit 1
fi

echo "Compressing PNG images..."
find "$OUTPUT_SUBDIR" -name 'slide-*.png' -print0 | while IFS= read -r -d $'\0' img_file; do
  # Mettre img_file entre guillemets
  pngquant "$img_file" --force --output "$img_file" --quality=65-80 --skip-if-larger
  if [ $? -ne 0 ]; then
      echo "::warning::Failed to compress '$img_file'."
  fi
done

# --- Génération du HTML (boucle dans heredoc) ---
echo "Generating index.html for $PDF_SHA256..."
cat <<EOF > "$OUTPUT_SUBDIR/index.html"
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>$PDF_BASENAME ($PDF_SHA256)</title>
  <link rel="stylesheet" href="../dist/reset.css">
  <link rel="stylesheet" href="../dist/reveal.css">
  <link rel="stylesheet" href="../dist/theme/black.css" id="theme">
  <link rel="stylesheet" href="../plugin/highlight/monokai.css">
</head>
<body>
  <div class="reveal">
    <div class="slides">
$( # Début de la substitution de commande pour générer les sections
  # Utilise find et sort -V pour lister les images dans l'ordre numérique
  find "$OUTPUT_SUBDIR" -name 'slide-*.png' | sort -V | while read -r img_path; do
    img_basename=$(basename "$img_path")
    # Génère la balise section pour chaque image trouvée
    echo "      <section><img src='$img_basename' alt='Slide from PDF $PDF_BASENAME'></section>"
  done
)
    </div>
  </div>
  <script src="../dist/reveal.js"></script>
  <script src="../plugin/notes/notes.js"></script>
  <script src="../plugin/highlight/highlight.js"></script>
  <script>
    Reveal.initialize({
      hash: true,
      plugins: [ RevealHighlight, RevealNotes ]
    });
  </script>
</body>
</html>
EOF

echo "Successfully processed PDF $PDF_SHA256 from $PDF_URL"
rm -rf "$TMP_DIR" # Nettoyage final
exit 0

