#!/usr/bin/env bash
# Задание 4, пункт 4 — namespaces по доменам и роли (ClusterRole) под таблицу RBAC.
#
# Принципы (из заданий 1–3): минимальные привилегии, доступ к Secrets — только
# у привилегированной группы, изоляция доступа по организационным доменам.
#
# Запуск:  bash 02-create-roles.sh
set -euo pipefail

# Namespaces по организационным доменам компании (изоляция доступа по орг-структуре)
for ns in pd-sales pd-zhku pd-finance pd-data; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

kubectl apply -f - <<'YAML'
# ============ Привилегированная роль ============
# Полный доступ ко всем ресурсам, включая просмотр Secrets, RBAC и узлы.
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pd-cluster-admin
  labels:
    app.kubernetes.io/part-of: propdevelopment-rbac
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
  - nonResourceURLs: ["*"]
    verbs: ["*"]
---
# ============ Роль наблюдателя (только чтение) ============
# get/list/watch рабочих ресурсов. Secrets НЕ включены.
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pd-viewer
  labels:
    app.kubernetes.io/part-of: propdevelopment-rbac
rules:
  - apiGroups: [""]
    resources: ["pods","pods/log","services","configmaps","namespaces","events","endpoints","persistentvolumeclaims","replicationcontrollers","serviceaccounts","nodes"]
    verbs: ["get","list","watch"]
  - apiGroups: ["apps"]
    resources: ["deployments","replicasets","statefulsets","daemonsets"]
    verbs: ["get","list","watch"]
  - apiGroups: ["batch"]
    resources: ["jobs","cronjobs"]
    verbs: ["get","list","watch"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses","networkpolicies"]
    verbs: ["get","list","watch"]
  # Secrets намеренно НЕ включены — их просмотр доступен только pd-cluster-admin.
---
# ============ Роль настройки (editor) ============
# Управление рабочими нагрузками в рамках namespace. Без Secrets, RBAC и узлов.
# Применяется к конкретным доменам через RoleBinding (см. 03-create-bindings.sh).
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pd-editor
  labels:
    app.kubernetes.io/part-of: propdevelopment-rbac
rules:
  - apiGroups: [""]
    resources: ["pods","pods/log","services","configmaps","persistentvolumeclaims","endpoints"]
    verbs: ["get","list","watch","create","update","patch","delete"]
  - apiGroups: ["apps"]
    resources: ["deployments","replicasets","statefulsets","daemonsets"]
    verbs: ["get","list","watch","create","update","patch","delete"]
  - apiGroups: ["batch"]
    resources: ["jobs","cronjobs"]
    verbs: ["get","list","watch","create","update","patch","delete"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses"]
    verbs: ["get","list","watch","create","update","patch","delete"]
  - apiGroups: ["autoscaling"]
    resources: ["horizontalpodautoscalers"]
    verbs: ["get","list","watch","create","update","patch","delete"]
  # Secrets, roles/rolebindings, nodes и namespaces — НЕ включены.
YAML

echo "Namespaces и роли (pd-cluster-admin, pd-viewer, pd-editor) созданы."
