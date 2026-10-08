Write-Host "Construction de limage movie-service..." -ForegroundColor Cyan
docker build -t movie-service:1.0.0 ./movie-service

Write-Host "Construction de limage ticket-service..." -ForegroundColor Cyan
docker build -t ticket-service:1.0.0 ./ticket-service

Write-Host "Chargement des images dans Minikube (cela peut prendre quelques secondes)..." -ForegroundColor Cyan
minikube image load movie-service:1.0.0
minikube image load ticket-service:1.0.0

Write-Host "Deploiement des manifests Kubernetes..." -ForegroundColor Cyan
kubectl apply -f k8s/

Write-Host ""
Write-Host "Deploiement termine avec succes !" -ForegroundColor Green
Write-Host "Pour voir letat des Pods en temps reel, execute la commande :" -ForegroundColor Yellow
Write-Host "kubectl get pods -n cinema-exam -w"
