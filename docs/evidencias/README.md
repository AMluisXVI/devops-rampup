# Evidencias — producción (2026-11-01)

Capturas tomadas con el ambiente `prod` desplegado (`terraform apply` + `ansible/run.sh prod`).

**Cómo se obtuvieron:**
- **App** (01–04): Chrome headless contra la URL pública del ALB de prod.
- **Gráficas** (05–10): la API de CloudWatch (`get-metric-widget-image`) con las mismas métricas del dashboard `epam-final-task-prod`, última hora y cuarto.
- **Tablas** (11–13): salen de la AWS CLI (`describe-alarms`, `describe-target-health`, `describe-instances`, `describe-db-instances`, `describe-subnets`).

No son capturas de la consola web.

| # | Archivo | Qué demuestra |
|---|---|---|
| 1 | [01-app-home.png](01-app-home.png) | Front-end servido por el ALB público. |
| 2 | [02-app-movies.png](02-app-movies.png) | Front → ALB interno → back → RDS: las 10 películas de los seeds. |
| 3 | [03-app-authors.png](03-app-authors.png) | Endpoint `/reviewers` del back vía front. Las fotos no cargan porque el sitio de avatares que usan los seeds originales ya no existe. |
| 4 | [04-app-publications.png](04-app-publications.png) | Endpoint `/publications` del back vía front. |
| 5 | [05-cw-ec2-cpu.png](05-cw-ec2-cpu.png) | CPU de front, back, bastion y NAT. |
| 6 | [06-cw-memory.png](06-cw-memory.png) | Memoria publicada por el agente CloudWatch (instalado por Ansible). |
| 7 | [07-cw-disk.png](07-cw-disk.png) | Uso de disco `/` publicado por el agente. |
| 8 | [08-cw-alb-requests.png](08-cw-alb-requests.png) | Peticiones y errores 5xx en ambos ALB. |
| 9 | [09-cw-alb-health.png](09-cw-alb-health.png) | Targets sanos (pasan de 0 a 1 cuando Ansible termina) y latencia. |
| 10 | [10-cw-rds.png](10-cw-rds.png) | CPU, conexiones y almacenamiento libre de RDS. |
| 11 | [11-cw-alarms.png](11-cw-alarms.png) | Las 10 alarmas en OK, todas con acción SNS. |
| 12 | [12-alb-targets.png](12-alb-targets.png) | ALB público (internet-facing) e interno; ambos targets *healthy*. |
| 13 | [13-resources.png](13-resources.png) | EC2 (front/back sin IP pública), RDS (no pública, cifrada, Single-AZ) y las 7 subnets en 2 AZ. |
| 14 | [14-sns-subscription-confirmed.png](14-sns-subscription-confirmed.png) | Suscripción email al tópico SNS de alertas confirmada. |
| 15 | [15-alarm-email-alarm.png](15-alarm-email-alarm.png) | Email recibido: alarma `prod-back-cpu-high` en ALARM (forzada con `set-alarm-state` a las 20:41:11 UTC). |
| 16 | [16-alarm-email-ok.png](16-alarm-email-ok.png) | Email de recuperación 19 s después: CloudWatch reevaluó la CPU real (~0.87 %) y volvió a OK. |

Las capturas 14–16 son del usuario; en los emails se taparon la dirección de correo y se recortó el enlace de baja (permite desuscribir a cualquiera que lo tenga).
