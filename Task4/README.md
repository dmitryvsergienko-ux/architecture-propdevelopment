# Задание 4. Защита доступа к кластеру Kubernetes (RBAC)

Ролевая модель доступа к кластеру Kubernetes компании **PropDevelopment**. Реализована на встроенном механизме **RBAC** и опирается на решения заданий 1–3: минимальные привилегии, доступ к Secrets — только у привилегированной группы, изоляция доступа по организационным доменам.

## Модель доступа

**Namespaces по доменам** (изоляция доступа по орг-структуре компании):
`pd-sales` (Продажи) · `pd-zhku` (ЖКУ) · `pd-finance` (Финансы) · `pd-data` (Дата).

**Группы пользователей** (в Kubernetes — поле `O` клиентского сертификата):
- `pd:platform-admins` — привилегированная (DevOps-инженеры + специалист по ИБ);
- `pd:viewers` — только просмотр (бизнес-аналитики, менеджеры, BI-аналитики, аудиторы);
- `pd:<домен>-developers` — настройка в своём домене (`pd:sales-developers`, `pd:zhku-developers`, `pd:finance-developers`, `pd:data-developers`).

## Таблица ролей

| Роль | Права роли | Группы пользователей |
|---|---|---|
| **`pd-cluster-admin`** (ClusterRole) | Полный административный доступ ко всем ресурсам во всех namespace, включая **просмотр и управление Secrets**, RBAC (roles/bindings), узлами и namespace | `pd:platform-admins` — DevOps-инженеры и специалист по ИБ |
| **`pd-viewer`** (ClusterRole) | Только чтение (`get/list/watch`) рабочих ресурсов во всех namespace: pods, deployments, services, configmaps, namespaces, events и т.п. **Без доступа к Secrets** и без изменений | `pd:viewers` — бизнес-аналитики, менеджеры, BI-аналитики, аудиторы |
| **`pd-editor`** (ClusterRole, выдаётся через RoleBinding в namespace домена) | Настройка рабочих нагрузок **в своём namespace**: `create/update/patch/delete` для deployments, pods, services, configmaps, ingress, jobs, HPA и т.п. **Без Secrets, RBAC, узлов и чужих namespace** | `pd:<домен>-developers` — разработчики и инженеры эксплуатации продуктовой команды домена |

## Файлы

| Файл | Пункт задания | Назначение |
|------|---------------|------------|
| [`01-create-users.sh`](./01-create-users.sh) | 3 | Создание пользователей (Ivan, Alexey, Vlad) через клиентские сертификаты, подписанные CA minikube, + контексты kubeconfig |
| [`02-create-roles.sh`](./02-create-roles.sh) | 4 | Создание namespaces по доменам и трёх ClusterRole из таблицы |
| [`03-create-bindings.sh`](./03-create-bindings.sh) | 5 | Привязка групп к ролям: ClusterRoleBinding (admins, viewers) + RoleBinding `pd-editor` по доменам |

Пример пользователей: **Ivan** → `pd:platform-admins`, **Alexey** → `pd:viewers`, **Vlad** → `pd:sales-developers`.

## Порядок запуска

Предусловие: поднят пустой Minikube (`minikube start`), `kubectl` смотрит на контекст `minikube`.

```bash
bash 02-create-roles.sh      # namespaces + роли
bash 03-create-bindings.sh   # привязки групп к ролям
bash 01-create-users.sh      # пользователи и их kubeconfig-контексты
```

Привязки выполнены к **группам**, поэтому порядок ролей/привязок и пользователей не критичен.

## Проверка прав

```bash
# Ivan (admin) — может смотреть Secrets:
kubectl --context=Ivan get secrets -A                       # ✔ разрешено

# Alexey (viewer) — видит ресурсы, но не Secrets:
kubectl --context=Alexey get pods -A                        # ✔ разрешено
kubectl --context=Alexey get secrets -A                     # ✘ Forbidden
kubectl --context=Alexey create deployment nginx --image=nginx -n pd-sales   # ✘ Forbidden

# Vlad (sales-developer) — настраивает только свой домен:
kubectl --context=Vlad -n pd-sales create deployment nginx --image=nginx     # ✔ разрешено
kubectl --context=Vlad -n pd-zhku  create deployment nginx --image=nginx     # ✘ Forbidden (чужой домен)
kubectl --context=Vlad -n pd-sales get secrets                               # ✘ Forbidden
```

Быстрая проверка без переключения контекстов (импpersonation):

```bash
kubectl auth can-i get secrets --as=Ivan   --as-group=pd:platform-admins              # yes
kubectl auth can-i get secrets --as=Alexey --as-group=pd:viewers                      # no
kubectl auth can-i get pods    --as=Alexey --as-group=pd:viewers                      # yes
kubectl auth can-i create deployments -n pd-sales --as=Vlad --as-group=pd:sales-developers  # yes
kubectl auth can-i create deployments -n pd-zhku  --as=Vlad --as-group=pd:sales-developers  # no
```
