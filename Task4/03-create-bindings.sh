#!/usr/bin/env bash
# Задание 4, пункт 5 — привязка групп пользователей к ролям.
#
# Привязка идёт к ГРУППАМ (поле O сертификата), а не к отдельным пользователям:
# добавление пользователя в группу автоматически выдаёт ему права.
#
# Запуск:  bash 03-create-bindings.sh
set -euo pipefail

kubectl apply -f - <<'YAML'
# Привилегированные администраторы — кластерно (pd-cluster-admin)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: pd-platform-admins
  labels:
    app.kubernetes.io/part-of: propdevelopment-rbac
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: pd-cluster-admin
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: Group
    name: pd:platform-admins
---
# Наблюдатели — кластерно, только чтение (pd-viewer)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: pd-viewers
  labels:
    app.kubernetes.io/part-of: propdevelopment-rbac
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: pd-viewer
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: Group
    name: pd:viewers
YAML

# Разработчики доменов — pd-editor только в СВОЁМ namespace (изоляция по орг-структуре)
for ns in sales zhku finance data; do
  kubectl apply -f - <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pd-${ns}-developers
  namespace: pd-${ns}
  labels:
    app.kubernetes.io/part-of: propdevelopment-rbac
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: pd-editor
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: Group
    name: pd:${ns}-developers
YAML
done

echo "Привязки ролей (ClusterRoleBinding + RoleBinding по доменам) созданы."
