# DEBUG.md — справочник диагностики

Случаи, встреченные при сборке этого стека. Каждый описан как симптом, проверка,
причина и вывод.

---

## 1. Имя не резолвится из контейнера, хотя сеть настроена верно

**Симптом.** Изнутри контейнера Prometheus:

```bash
docker compose exec prometheus wget -qO- http://node-exporter:9100/metrics
wget: bad address 'node-exporter:9100'
```

Выглядит как проблема сети или DNS.

**Проверка.** Резолвер отвечает нормально:

```bash
docker compose exec prometheus nslookup node-exporter
Name:   node-exporter
Address: 172.18.0.3          ← адрес НАЙДЕН
*** Can't find node-exporter: No answer
```

Первая строка — успешный ответ по A-записи. Вторая — отсутствие ответа по AAAA:
IPv6 в сети Docker не настроен.

**Причина.** Busybox-версия `wget` запрашивает и A-, и AAAA-записи. Не получив
ответа по второй, считает операцию проваленной, хотя IPv4-адрес у неё уже есть.

**Доказательство, что сеть в порядке.** Тот же запрос из стороннего контейнера
проходит:

```bash
docker run --rm --network monitoring_monitoring alpine \
  wget -qO- http://node-exporter:9100/metrics | head -3
```

Сам Prometheus использует резолвер Go и работает нормально — это подтверждается
состоянием целей:

```bash
curl -s localhost:9090/api/v1/targets | python3 -m json.tool | grep -E '"job"|"health"'
```

**Вывод.** Проверять разрешение имён надо из стороннего контейнера, а не изнутри
сервиса. Busybox — не эталон сетевого клиента.

---

## 2. Busybox-wget не читает переменные HTTP_PROXY

**Симптом.** Проверка доступности прокси изнутри контейнера Grafana даёт таймаут,
хотя переменные заданы и прокси работает:

```bash
docker compose exec grafana wget -qO- --timeout=15 https://api.telegram.org/
wget: download timed out
```

**Причина.** Busybox-`wget` игнорирует `HTTP_PROXY` и `HTTPS_PROXY` и ходит
напрямую. А напрямую Telegram заблокирован.

**Как проверять правильно** — сетевую достижимость прокси, а не HTTP-запрос:

```bash
docker compose exec grafana sh -c 'timeout 5 nc -z host.docker.internal 10808 && echo достижим || echo нет'
```

И окончательная проверка — кнопкой Test у точки контакта в интерфейсе Grafana.
Она использует HTTP-клиент Go, который переменные читает.

**Вывод.** Проверять тем инструментом, который ведёт себя так же, как проверяемый
сервис. Разные клиенты по-разному относятся к прокси и к DNS.