#!/usr/bin/env bash
# Задание 4, пункт 3 — создание пользователей кластера Kubernetes.
#
# В Kubernetes нет объекта «пользователь»: пользователь — это клиентский
# сертификат, где CN = имя пользователя, а O = группа (для RBAC).
# Сертификаты подписываются центром сертификации (CA) кластера minikube.
#
# Запуск (Git Bash):  bash 01-create-users.sh
set -euo pipefail

CA_DIR="${MINIKUBE_CA_DIR:-$HOME/.minikube}"   # каталог CA minikube (ca.crt, ca.key)
CLUSTER="${CLUSTER_NAME:-minikube}"
OUT_DIR="${OUT_DIR:-$(dirname "$0")/.users}"   # куда положить ключи/сертификаты
DAYS="${CERT_DAYS:-365}"

# Пользователь -> группа. Группа попадает в поле O сертификата и используется в RBAC.
declare -A USER_GROUP=(
  [Ivan]="pd:platform-admins"     # привилегированный (DevOps/ИБ)
  [Alexey]="pd:viewers"           # только просмотр (аналитик)
  [Vlad]="pd:sales-developers"    # настройка в домене «Продажи»
)

if [[ ! -f "$CA_DIR/ca.crt" || ! -f "$CA_DIR/ca.key" ]]; then
  echo "Не найден CA кластера в $CA_DIR (нужны ca.crt и ca.key). Это каталог .minikube." >&2
  exit 1
fi
mkdir -p "$OUT_DIR"

for user in "${!USER_GROUP[@]}"; do
  group="${USER_GROUP[$user]}"
  echo "=== Пользователь: $user   Группа: $group ==="
  # 1) приватный ключ пользователя
  openssl genrsa -out "$OUT_DIR/$user.key" 2048
  # 2) запрос на сертификат: CN=имя пользователя, O=группа
  openssl req -new -key "$OUT_DIR/$user.key" -out "$OUT_DIR/$user.csr" \
    -subj "/CN=$user/O=$group"
  # 3) подпись запроса центром сертификации кластера
  openssl x509 -req -in "$OUT_DIR/$user.csr" \
    -CA "$CA_DIR/ca.crt" -CAkey "$CA_DIR/ca.key" -CAcreateserial \
    -out "$OUT_DIR/$user.crt" -days "$DAYS" -sha256
  # 4) учётные данные и контекст в kubeconfig
  kubectl config set-credentials "$user" \
    --client-certificate="$OUT_DIR/$user.crt" \
    --client-key="$OUT_DIR/$user.key" --embed-certs=true
  kubectl config set-context "$user" --cluster="$CLUSTER" --user="$user"
  echo "Готово. Использование: kubectl --context=$user get pods"
  echo
done

echo "Созданы пользователи: ${!USER_GROUP[*]}"
