#!/bin/bash

# Script pour traiter les items PDF définis dans une matrice JSON.
# Prend le dossier de build en argument 1.
# Lit la matrice JSON (compactée) depuis la variable d'environnement PDF_MATRIX_JSON.

set -e

BUILD_DIR="$1" # Le dossier de build est maintenant le premier (et seul) argument
# Lire le JSON depuis la variable d'environnement
MATRIX_JSON_COMPACT="${PDF_MATRIX_JSON}"

# Validation
if [ -z "$BUILD_DIR" ]; then
    echo "Usage: $0 <build_dir> (expects PDF_MATRIX_JSON environment variable)"
    exit 1
fi
if [ -z "$MATRIX_JSON_COMPACT" ]; then
    echo "::error:: Environment variable PDF_MATRIX_JSON is not set or empty."
    exit 1
fi


# Vérifie si jq est disponible
if ! command -v jq &> /dev/null; then echo "::error::jq is not installed!"; exit 1; fi

echo "Build Directory: $BUILD_DIR"
echo "Received Matrix JSON (from env): $MATRIX_JSON_COMPACT"


# Vérifie si la matrice est vide (ex: "[]")
if [[ "$MATRIX_JSON_COMPACT" == "[]" ]]; then
    echo "Matrix is empty. No PDFs to process."
    exit 0
fi

# Utilise jq pour itérer sur chaque objet du tableau JSON
echo "$MATRIX_JSON_COMPACT" | jq -c '.[]' | while IFS= read -r pdf_info_json; do
  # Extrait les informations de l'objet JSON courant
  source_type=$(echo "$pdf_info_json" | jq -r '.source_type')
  source_value=$(echo "$pdf_info_json" | jq -r '.source_value')
  pdf_hash=$(echo "$pdf_info_json" | jq -r '.pdf_hash')
  pdf_basename=$(echo "$pdf_info_json" | jq -r '.pdf_basename')

  echo "--- Processing Item ---"
  echo "  Type: $source_type"
  echo "  Source: $source_value"
  echo "  Basename: $pdf_basename"
  echo "  Expected Hash: $pdf_hash"
  echo "-----------------------"

  # Déterminer les options pour le script process_pdf.sh
  source_option=""
  if [[ "$source_type" == "file" ]]; then
    source_option="-f"
    if [ ! -f "$source_value" ]; then
       echo "::error::Local PDF file specified in matrix not found: '$source_value'"
       continue
    fi
  elif [[ "$source_type" == "url" ]]; then
    source_option="-u"
  else
     echo "::error::Unknown source type in matrix item: $source_type"
     continue
  fi

  # Appeler le script process_pdf.sh (situé dans le même dossier /app/scripts/)
  # Le chemin est relatif à l'image Docker
  /app/scripts/process_pdf.sh "$source_option" "$source_value" -b "$BUILD_DIR"

  if [ $? -ne 0 ]; then
      echo "::warning::Processing failed for '$pdf_basename' (Source: $source_value)"
  fi

  echo "--- Finished processing item '$pdf_basename' ---"

done

echo "Finished processing all items in the matrix."
