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

## Partie 3
**Q3.1** On copie `pom.xml` avant `src/` pour tirer parti du **cache des couches de Docker**. Comme le téléchargement des dépendances est l'étape la plus longue, on la met en premier. Si on ne modifie qu'une seule ligne de Java dans `src/`, le cache de l'étape de téléchargement est conservé et seul le code est recompilé, ce qui est beaucoup plus rapide.
**Q3.2** Dans un conteneur Kubernetes, la mémoire allouée (limits) peut varier selon l'environnement ou la charge. Utiliser `-XX:MaxRAMPercentage=75` permet à la JVM de s'adapter dynamiquement et automatiquement à la limite de mémoire du conteneur (Cgroups), évitant ainsi le gaspillage ou l'erreur `OOMKilled`. À l'inverse, `-Xmx512m` est statique.
**Q3.3** Dans Kubernetes, si `ticket` démarre avant `movie`, son conteneur va se lancer (statut `Running`), mais sa **Readiness Probe** va échouer car elle tente de pinguer `movie` (via le `MovieHealthIndicator`). Le Pod `ticket` restera donc dans l'état `0/1 Ready` et ne recevra aucun trafic, jusqu'à ce que `movie` démarre, auquel cas la probe passera au vert et `ticket` deviendra `1/1 Ready` automatiquement.

## Partie 4
**Q4.1** La commande `kubectl apply -f k8s/` applique les fichiers par ordre alphabétique. Les préfixes `00-`, `10-`, etc. servent à garantir que les dépendances sont créées dans le bon ordre (ex: le Namespace doit exister avant les ConfigMaps, et les ConfigMaps avant les Deployments).
**Q4.2** C'est la `startupProbe` qui est responsable. Ce n'est pas une anomalie : Spring Boot est assez long à démarrer (10 à 40 secondes). La `startupProbe` retarde l'activation des autres probes pour éviter un redémarrage prématuré du conteneur pendant son lancement.
**Q4.3** Avec `imagePullPolicy: Always`, Kubernetes essaierait systématiquement de télécharger l'image depuis Docker Hub. Comme les images ont été construites localement et n'existent pas sur un registre public, cela échouerait avec une erreur `ErrImagePull` ou `ImagePullBackOff`.

## Partie 5
**Q5.1** Deux Pods distincts ont répondu dans la boucle. C'est l'objet `Service` (de type `ClusterIP`) qui agit comme un Load Balancer interne et répartit la charge entre ces Pods (Endpoints).
**Q5.2** Avec `pathType: Exact` sur `/api/movies`, une requête vers `GET /api/movies/1` renverrait une erreur `404 Not Found` depuis l'Ingress, car le chemin n'est pas exactement égal à `/api/movies`. C'est pourquoi on utilise `Prefix`.
**Q5.3** On obtient un code `404 Not Found` (ou `502`). C'est hautement souhaitable d'un point de vue sécurité : on ne veut pas que l'extérieur (le trafic venant de l'Ingress) puisse accéder aux URLs d'administration (`/actuator/health`).
