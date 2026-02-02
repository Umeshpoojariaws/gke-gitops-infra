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
  DOCKER_REPO_URL="us-central1-docker.pkg.dev/devops-mlops-483223/ml-repo"

  FULL_IMAGE_NAME="$DOCKER_REPO_URL/$IMAGE_NAME"
  TAG="$value"

  echo "Setting image for '$IMAGE_NAME' to '$FULL_IMAGE_NAME:$TAG'"

  # Use kustomize edit to set the image. This will add or update the entry.
  (cd "$ENV_DIR" && kustomize edit set image "$IMAGE_NAME=$FULL_IMAGE_NAME:$TAG")

  # ==> ADD THIS BLOCK TO FIX THE TRAINING JOB <==
  # If the image is the training image, also update the post-sync job manifest directly.
  if [ "$IMAGE_NAME" == "training" ]; then
    JOB_FILE="$ENV_DIR/post-sync/job.yaml"
    if [ -f "$JOB_FILE" ]; then
      echo "Updating post-sync job manifest at $JOB_FILE"
      # Use sed to replace the image line. This is more robust than simple find/replace.
      # It looks for the line containing "image: us-central1-docker.pkg.dev/.../training:" and replaces it.
      sed -i.bak "s|image: ${DOCKER_REPO_URL}/training:.*|image: ${FULL_IMAGE_NAME}:${TAG}|g" "$JOB_FILE"
      rm "${JOB_FILE}.bak" # Clean up the backup file created by sed
    else
      echo "Warning: Job file not found at $JOB_FILE"
    fi
  fi
  # ==> END OF NEW BLOCK <==

done < "$PROPERTIES_FILE"

echo "Successfully updated tags in $KUSTOMIZATION_FILE"