#!/bin/bash
set -e

# This script updates the image tags in a Kustomize environment based on a properties file.
# Usage: ./update_tags.sh <environment>
# Example: ./update_tags.sh dev

if [ -z "$1" ]; then
  echo "Usage: $0 <environment>"
  echo "Example: $0 dev"
  exit 1
fi

ENV_DIR="environments/$1"
PROPERTIES_FILE="$ENV_DIR/image_tags.properties"
KUSTOMIZATION_FILE="$ENV_DIR/kustomization.yaml"

if [ ! -d "$ENV_DIR" ]; then
  echo "Error: Environment directory '$ENV_DIR' not found."
  exit 1
fi

if [ ! -f "$PROPERTIES_FILE" ]; then
  echo "Error: Properties file '$PROPERTIES_FILE' not found."
  exit 1
fi

echo "Updating tags for environment: $1"

# Read properties and update kustomization
while IFS='=' read -r key value; do
  # Skip comments and empty lines
  [[ "$key" =~ ^# || -z "$key" ]] && continue

  # Map the property name to the Kustomize image name
  case "$key" in
    "BACKEND_TAG")
      IMAGE_NAME="backend"
      ;;
    "FRONTEND_TAG")
      IMAGE_NAME="frontend"
      ;;
    "TRAINING_TAG")
      IMAGE_NAME="training"
      ;;
    *)
      echo "Warning: Unknown key '$key' in properties file. Skipping."
      continue
      ;;
  esac

  # The DOCKER_REPO_URL should be replaced with your actual Docker repository URL
  # This could also be sourced from an environment variable.
  DOCKER_REPO_URL="DOCKER_REPO_URL"

  FULL_IMAGE_NAME="$DOCKER_REPO_URL/$IMAGE_NAME"
  TAG="$value"

  echo "Setting image for '$IMAGE_NAME' to '$FULL_IMAGE_NAME:$TAG'"

  # Use kustomize edit to set the image. This will add or update the entry.
  (cd "$ENV_DIR" && kustomize edit set image "$IMAGE_NAME=$FULL_IMAGE_NAME:$TAG")

done < "$PROPERTIES_FILE"

echo "Successfully updated tags in $KUSTOMIZATION_FILE"