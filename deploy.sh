#!/bin/bash

# Arrêter le script en cas d'erreur
set -e

echo -e "\e[36m🚧 Construction de l'image movie-service...\e[0m"
docker build -t movie-service:1.0.0 ./movie-service

echo -e "\e[36m🚧 Construction de l'image ticket-service...\e[0m"
docker build -t ticket-service:1.0.0 ./ticket-service

echo -e "\e[36m📦 Chargement des images dans Minikube (cela peut prendre quelques secondes)...\e[0m"
minikube image load movie-service:1.0.0
minikube image load ticket-service:1.0.0

echo -e "\e[36m🚀 Déploiement des manifests Kubernetes...\e[0m"
kubectl apply -f k8s/

echo ""
echo -e "\e[32m✅ Déploiement terminé avec succès !\e[0m"
echo -e "\e[33mPour voir l'état des Pods en temps réel, exécute la commande :\e[0m"
echo "kubectl get pods -n cinema-exam -w"
