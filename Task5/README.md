# Задание 5. Управление трафиком внутри кластера Kubernetes

Изоляция и разграничение сетевого трафика между сервисами в одном namespace с помощью **NetworkPolicy**. Трафик разрешён только внутри пар «UI ↔ его API», остальное запрещено.

## Сервисы

Четыре пода-сервиса nginx, метка `role` задаёт роль сервиса:

| Сервис (под/Service) | Метка `role` |
|---|---|
| `front-end-app` | `front-end` |
| `back-end-api-app` | `back-end-api` |
| `admin-front-end-app` | `admin-front-end` |
| `admin-back-end-api-app` | `admin-back-end-api` |

Развёртывание — [`deploy-services.sh`](./deploy-services.sh) (`kubectl run … --labels role=… --expose --port 80`).

## Сетевые политики

Файл [`non-admin-api-allow.yaml`](./non-admin-api-allow.yaml). Подход: **default-deny** на весь входящий трафик + точечные разрешения по меткам `role`.

| Политика | Кому (podSelector) | Откуда разрешён вход |
|---|---|---|
| `default-deny-ingress` | все поды | — (всё запрещено) |
| `allow-front-end-to-back-end-api` | `role=back-end-api` | `role=front-end` |
| `allow-back-end-api-to-front-end` | `role=front-end` | `role=back-end-api` |
| `allow-admin-front-end-to-admin-back-end-api` | `role=admin-back-end-api` | `role=admin-front-end` |
| `allow-admin-back-end-api-to-admin-front-end` | `role=admin-front-end` | `role=admin-back-end-api` |

Итог:
- ✅ `front-end ↔ back-end-api` — разрешено в обе стороны;
- ✅ `admin-front-end ↔ admin-back-end-api` — разрешено в обе стороны;
- ❌ всё остальное (`front-end → admin-back-end-api`, посторонний под → любой сервис и т.п.) — заблокировано.

Egress не ограничивается, поэтому DNS при тесте работает.

## Применение

```bash
bash deploy-services.sh
kubectl apply -f non-admin-api-allow.yaml
```

> **Важно про CNI.** Стандартный minikube (bridge CNI) **не применяет** NetworkPolicy. Для реального разграничения нужен CNI с поддержкой политик:
> ```
> minikube delete && minikube start --cni=calico
> ```

## Проверка

Разрешённый трафик (`front-end → back-end-api`):
```bash
kubectl run test-$RANDOM --rm -i -t --image=alpine --labels role=front-end -- \
  wget -qO- --timeout=2 http://back-end-api-app
# → возвращается HTML-страница nginx (доступ есть)
```

Запрещённый трафик (`front-end → admin-back-end-api`):
```bash
kubectl run test-$RANDOM --rm -i -t --image=alpine --labels role=front-end -- \
  wget -qO- --timeout=2 http://admin-back-end-api-app
# → таймаут (доступа нет)
```

Запрещённый трафик (посторонний под без нужной метки):
```bash
kubectl run test-$RANDOM --rm -i -t --image=alpine -- \
  wget -qO- --timeout=2 http://back-end-api-app
# → таймаут (доступа нет)
```

Аналогично проверяется пара `admin-front-end ↔ admin-back-end-api` (метка `role=admin-front-end`).
