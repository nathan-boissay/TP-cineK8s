# Réponses au TP Kubernetes

## Partie 1
La propriété `server.shutdown: graceful` permet au serveur de terminer le traitement des requêtes HTTP en cours avant de s'arrêter, évitant ainsi de couper des connexions utilisateurs en plein milieu lors du remplacement des pods.
