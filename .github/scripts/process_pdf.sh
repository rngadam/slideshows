#!/bin/bash

# Script unifié pour traiter un PDF (depuis URL ou fichier local),
# convertir en slideshow Reveal.js et organiser par SHA256sum.

set -e # Arrête le script en cas d'erreur

# --- Initialisation des variables ---
PDF_INPUT=""
BUILD_DIR=""
INPUT_TYPE="" # 'url' or 'file'
PDF_SOURCE_PATH="" # Chemin vers le fichier PDF à traiter (local ou temporaire)
PDF_BASENAME=""
TMP_DIR="" # Dossier temporaire si téléchargement

# --- Fonction de nettoyage ---
cleanup() {
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    # echo "Nettoyage du dossier temporaire: $TMP_DIR"
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT # Assure le nettoyage à la fin ou en cas d'erreur

# --- Analyse des arguments ---
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -u|--url)
      INPUT_TYPE="url"
      PDF_INPUT="$2"
      shift # passe l'argument
      shift # passe la valeur
      ;;
    -f|--file)
      INPUT_TYPE="file"
      PDF_INPUT="$2"
      shift # passe l'argument
      shift # passe la valeur
      ;;
    -b|--build-dir)
      BUILD_DIR="$2"
      shift # passe l'argument
      shift # passe la valeur
      ;;
    *)    # argument inconnu
      echo "Option inconnue: $1"
      exit 1
      ;;
  esac
done

# --- Validation des arguments ---
if [ -z "$INPUT_TYPE" ] || [ -z "$PDF_INPUT" ] || [ -z "$BUILD_DIR" ]; then
  echo "Usage: $0 (-u <url> | -f <file_path>) -b <build_dir>"
  exit 1
fi
# Assure que le dossier de build existe (le workflow le crée, mais double check)
mkdir -p "$BUILD_DIR"

# --- Traitement selon le type d'entrée ---
if [ "$INPUT_TYPE" == "url" ]; then
  echo "Processing URL: $PDF_INPUT"
  TMP_DIR=$(mktemp -d)
  PDF_SOURCE_PATH="$TMP_DIR/downloaded.pdf"
  echo "Downloading PDF to temporary file $PDF_SOURCE_PATH..."
  # Utiliser des guillemets autour du nom de fichier temporaire
  curl -L -o "$PDF_SOURCE_PATH" -f "$PDF_INPUT"
  if [ $? -ne 0 ]; then
      echo "::error::Failed to download PDF from $PDF_INPUT"
      exit 1 # Le trap nettoiera TMP_DIR
  fi
  # Essayer d'extraire un nom de l'URL
  URL_FILENAME=$(basename "$PDF_INPUT" | sed 's/\?.*//')
    if [[ "$URL_FILENAME" == *.pdf ]]; then
        PDF_BASENAME="$URL_FILENAME"
    else
        # Si l'extraction échoue, utiliser un nom basé sur l'URL (simplifié)
        # Ceci est juste pour le titre, le hash reste la clé unique
        PDF_BASENAME=$(echo "$PDF_INPUT" | cut -d'/' -f3)-$(echo "$URL_FILENAME" | head -c 20).pdf
    fi

elif [ "$INPUT_TYPE" == "file" ]; then
  echo "Processing local file: $PDF_INPUT"
  if [ ! -f "$PDF_INPUT" ]; then
    echo "Erreur: Le fichier PDF '$PDF_INPUT' est manquant ou invalide."
    exit 1
  fi
  PDF_SOURCE_PATH="$PDF_INPUT" # Chemin direct
  PDF_BASENAME=$(basename "$PDF_SOURCE_PATH")
fi

# --- Logique Commune (Hash, Dossier Sortie, Conversion, etc.) ---
echo "Source PDF Path: $PDF_SOURCE_PATH"
echo "Build directory: $BUILD_DIR"
echo "PDF Basename: $PDF_BASENAME"

# Hash (avec guillemets)
PDF_SHA256=$(sha256sum "$PDF_SOURCE_PATH" | awk '{ print $1 }')
echo "PDF SHA256: $PDF_SHA256"

OUTPUT_SUBDIR="$BUILD_DIR/$PDF_SHA256"

# Vérification d'existence (Idempotence/Cache)
if [ -d "$OUTPUT_SUBDIR" ]; then
  echo "::warning::Output directory $OUTPUT_SUBDIR already exists. Skipping processing."
  # S'assurer que le fichier de nom existe même si on saute
  if [ ! -f "$OUTPUT_SUBDIR/pdf_basename.txt" ]; then
       echo "$PDF_BASENAME" > "$OUTPUT_SUBDIR/pdf_basename.txt"
  fi
  exit 0 # Sortir avec succès
fi

echo "Creating output directory: $OUTPUT_SUBDIR"
mkdir -p "$OUTPUT_SUBDIR"

# Sauvegarde du nom de base
echo "$PDF_BASENAME" > "$OUTPUT_SUBDIR/pdf_basename.txt"

# Conversion (avec guillemets autour de la source)
echo "Converting PDF to PNG images..."
pdftoppm "$PDF_SOURCE_PATH" "$OUTPUT_SUBDIR/slide" -png
if [ $? -ne 0 ]; then
    echo "::error::Failed to convert PDF '$PDF_BASENAME' (SHA: $PDF_SHA256)."
    rm -rf "$OUTPUT_SUBDIR" # Nettoyer en cas d'échec
    exit 1
fi

# Compression (avec guillemets)
echo "Compressing PNG images..."
find "$OUTPUT_SUBDIR" -name 'slide-*.png' -print0 | while IFS= read -r -d $'\0' img_file; do
  pngquant "$img_file" --force --output "$img_file" --quality=65-80 --skip-if-larger || echo "::warning::Failed to compress '$img_file'."
done

# Génération HTML (inchangé par rapport à la version précédente avec background)
echo "Generating index.html for $PDF_SHA256 using background images..."
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
  <style>
    .reveal .slides section { padding: 0 !important; }
  </style>
</head>
<body>
  <div class="reveal">
    <div class="slides">
$( find "$OUTPUT_SUBDIR" -name 'slide-*.png' | sort -V | while read -r img_path; do
    img_basename=$(basename "$img_path")
    echo "      <section data-background-image='$img_basename' data-background-size='contain'></section>"
  done )
    </div>
  </div>
  <script src="../dist/reveal.js"></script>
  <script src="../plugin/notes/notes.js"></script>
  <script src="../plugin/highlight/highlight.js"></script>
  <script>
    Reveal.initialize({
      hash: true, margin: 0, width: "100%", height: "100%",
      plugins: [ RevealHighlight, RevealNotes ]
    });
  </script>
</body>
</html>
EOF

echo "Successfully processed PDF $PDF_SHA256 (Source: $PDF_INPUT)"
exit 0 # Le trap EXIT s'occupera du nettoyage de TMP_DIR si nécessaire
