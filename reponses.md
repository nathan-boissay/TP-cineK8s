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

## Partie 6
**Prédictions (6.1) :**
- (a) `ticket` passera en `0/2 READY` avec `0 RESTARTS`.
- (b) La commande `get endpoints ticket` ne listera aucune adresse IP (vide).
- (c) Le code HTTP de `/api/tickets` via l'Ingress sera un `503 Service Unavailable`.
- (d) La liveness de `ticket` restera en statut `UP` (réussie).

**Explication Q6.1 :**
1. Le déploiement `movie` est réduit à 0 réplicas, le Service `movie` n'a plus de Pods derrière.
2. La `readinessProbe` des Pods `ticket` échoue au bout de 15 secondes (3 échecs) car elle n'arrive plus à joindre `movie`.
3. Kubernetes retire les Pods `ticket` de la liste des Endpoints du Service `ticket`.
4. L'Ingress route vers le Service `ticket` qui n'a plus aucun endpoint actif, d'où le retour d'une erreur 503.
Les `RESTARTS` restent à 0 car la `livenessProbe` (qui surveille la santé interne du conteneur) est toujours en succès, la JVM va bien.

**Tableau de dépannage :**

| # | Statut observé | Commande de diagnostic | Cause exacte | Correction apportée |
|---|----------------|------------------------|--------------|---------------------|
| 1 | `ErrImagePull` / `ImagePullBackOff` | `kubectl describe pod ...` | L'image est locale mais `imagePullPolicy: Always` tente de la télécharger sur Docker Hub. | Remplacé par `imagePullPolicy: IfNotPresent` |
| 2 | `CreateContainerConfigError` | `kubectl describe pod ...` puis `kubectl get cm` | La ConfigMap demandée s'appelle `ticket-configmap` dans le yaml, mais elle a été créée sous le nom `ticket-config`. | Remplacé par `name: ticket-config` |
| 3 | `0/1 Ready` indéfiniment | `kubectl describe pod ...` (voir section Events pour Readiness probe failed) | La readinessProbe interroge le port `8081`, or l'application écoute sur le port `8080`. | Remplacé par `port: 8080` (ou `http`) |

**Q6.3** La modification de la ConfigMap n'est pas répercutée automatiquement sur les Pods déjà en cours d'exécution (les variables d'environnement sont fixées au démarrage). C'est la commande `kubectl rollout restart deploy/movie` qui a forcé la création de nouveaux Pods prenant en compte la nouvelle configuration.

## Partie 7
**Q7.1** 1. Le Pod ticket fait une requête vers `http://movie:8080`. 2. Le DNS interne du cluster (CoreDNS) résout le nom `movie` en l'adresse IP virtuelle (`ClusterIP`) du Service. 3. Le composant `kube-proxy` (via iptables/IPVS) intercepte le trafic vers cette IP et le redirige vers l'adresse IP réelle de l'un des Pods `movie` prêts (les endpoints).
**Q7.2** Le nombre varie d'un appel à l'autre car chaque requête peut être dirigée vers l'un ou l'autre des Pods `ticket`, et chacun stocke sa propre liste de réservations en mémoire vive (RAM). Si on supprime les Pods, toutes les données sont perdues. La solution architecturale est d'utiliser un stockage externe persistant et partagé (comme une base de données PostgreSQL ou Redis) plutôt que l'état en mémoire.
**Q7.3** Quand on supprime un Pod manuellement, un nouveau Pod est recréé instantanément. Si on avait déployé un `Pod` "nu", la suppression aurait été définitive. Le `Deployment` (via son ReplicaSet) s'assure en permanence qu'il y a toujours exactement le nombre de réplicas demandé (2).

## Bonus
**QB2** Le résultat de la boucle est qu'aucune requête n'a échoué (100% de codes HTTP `200`). Le déploiement s'est fait avec un vrai zéro coupure (*Zero Downtime*). Voici comment les trois éléments y contribuent :
1. **`strategy: RollingUpdate (maxUnavailable: 0)`** : Empêche Kubernetes de détruire un ancien Pod avant que le nouveau ne soit complètement créé et prêt. On a toujours au moins 2 Pods opérationnels (d'où le `maxSurge: 1` pour permettre d'en lancer un 3ème temporairement).
2. **`readinessProbe`** : S'assure que le trafic n'est envoyé vers le nouveau Pod que lorsqu'il a fini de charger Spring Boot et qu'il a répondu "UP". Sans elle, le Pod recevrait des requêtes pendant que Java démarre, causant des erreurs 502.
3. **`shutdown: graceful` (dans application.yaml)** : Demande à l'ancien Pod (qui reçoit le signal de s'éteindre) de refuser les nouvelles connexions mais de **terminer le traitement des requêtes HTTP en cours**. Cela évite de tuer une transaction utilisateur en plein milieu d'une réservation.
