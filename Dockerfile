# Utiliser l'image Alpine la plus récente
FROM alpine:latest

# Installer les dépendances nécessaires via apk
RUN apk update && \
    apk add --no-cache \
        poppler-utils \
        pngquant \
        curl \
        coreutils \
        findutils \
        ca-certificates \
        git \
        bash \
        tar \
        jq \
    && \
    rm -rf /var/cache/apk/*

# Créer un répertoire pour les scripts et définir comme répertoire de travail
WORKDIR /app

# Copier les scripts dans l'image
COPY .github/scripts/ /app/scripts/

# Rendre les scripts exécutables DANS l'image
RUN chmod +x /app/scripts/*.sh

# Définir le script principal comme point d'entrée
# Les arguments passés à `docker run <image> ...` seront ajoutés après cette commande.
#ENTRYPOINT ["/app/scripts/process_pdf.sh"]

# Il n'est pas nécessaire d'avoir un CMD ici, car l'ENTRYPOINT prendra les arguments
# de `docker run`. Le script process_pdf.sh gère déjà le cas sans arguments.

# Confirmer que /app est le répertoire de travail
WORKDIR /app
