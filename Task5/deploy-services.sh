#!/usr/bin/env bash
# Задание 5 — развёртывание четырёх сервисов nginx с метками-ролями в одном namespace.
# Метка role играет роль роли сервиса; --expose создаёт Service, выбирающий под по этой метке.
#
# Запуск:  bash deploy-services.sh
set -euo pipefail

kubectl run front-end-app          --image=nginx --labels role=front-end          --expose --port 80
kubectl run back-end-api-app       --image=nginx --labels role=back-end-api       --expose --port 80
kubectl run admin-front-end-app    --image=nginx --labels role=admin-front-end    --expose --port 80
kubectl run admin-back-end-api-app --image=nginx --labels role=admin-back-end-api --expose --port 80

echo "Готово. Поды и сервисы:"
kubectl get pods,svc -l role -o wide 2>/dev/null || kubectl get pods,svc
