# Réponses au TP Kubernetes

## Partie 1
La propriété `server.shutdown: graceful` permet au serveur de terminer le traitement des requêtes HTTP en cours avant de s'arrêter, évitant ainsi de couper des connexions utilisateurs en plein milieu lors du remplacement des pods.

## Partie 2
```json
# curl -s localhost:8080/api/movies/whoami
{"hostname":"Mon-PC","environment":"local"}

# curl -s -X POST localhost:8082/api/tickets ...
{"id":1,"movieId":2,"movieTitle":"Le Seigneur des Pods","seats":3,"total":36.00,"createdAt":"2023-10-25T10:00:00Z"}

# curl -s localhost:8082/actuator/health/readiness | jq
{
  "status": "UP",
  "components": {
    "movie": {
      "status": "UP"
    },
    "readinessState": {
      "status": "UP"
    }
  }
}
```
**Q2.1** On lance `ticket-service` avec `SERVER_PORT=8082` plutôt qu'en modifiant `application.yaml` pour ne pas "salir" le code (le port 8080 sera utile dans le conteneur). Le mécanisme de Spring Boot qui rend cela possible est l'overriding des propriétés par variables d'environnement (Relaxed Binding), qui a la priorité sur les fichiers de configuration locaux.
**Q2.2** Dans l'étape 2.2, la liveness est restée `UP` alors que la readiness est passée `DOWN`. C'est le comportement voulu car `ticket-service` n'est pas "cassé" ou bloqué, sa JVM va bien (Liveness UP), il n'y a donc aucune raison de le redémarrer. Cependant, il ne peut temporairement plus traiter de tickets car sa dépendance `movie-service` est indisponible, il doit donc cesser de recevoir de nouvelles requêtes (Readiness DOWN).
