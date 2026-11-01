# Movie Analyst en AWS — Terraform + Ansible

Migración de la app **Movie Analyst** (front-end Node, back-end API Node, MySQL) a AWS con **Terraform** (infraestructura), **Ansible** (configuración, ejecutado desde el bastion) y **CloudWatch** (monitoreo). Dos ambientes, **QA** y **Producción**, con el mismo código.

- Diagrama y flujo: [docs/architecture.md](docs/architecture.md)
- Cada cambio y su porqué, en orden: [REGISTRO-CAMBIOS.md](REGISTRO-CAMBIOS.md)
- Enunciado del ramp-up original: [docs/README-rampup-original.md](docs/README-rampup-original.md)

## Resumen de la arquitectura

```
Internet ─► ALB público :80 ─► Front :3030 ─► ALB interno :80 ─► Back :3000 ─► RDS MySQL :3306
             (subnet pública)   (privada)       (privada)         (privada)     (subnet DB)
Tu IP ─SSH─► Bastion (subnet management) ─Ansible/SSH─► Front, Back
Front/Back/DB ─► NAT instance (pública) ─► Internet Gateway       (solo salida)
Todo ─► CloudWatch (métricas, logs, dashboard, 10 alarmas) ─► SNS email
```

Una VPC por ambiente (`qa` 10.0.0.0/16, `prod` 10.1.0.0/16) en 2 zonas de disponibilidad, `us-east-1`.

## Requisitos obligatorios

| Requisito | Cómo se cumple |
|---|---|
| Sin serverless, todo en instancias | EC2 para front, back, bastion y NAT; RDS para la DB. |
| DB en el servicio adecuado | RDS MySQL 8.4 (`terraform/database.tf`). |
| DB y back-end en subnets privadas con salida a internet | Back en subnet privada, RDS en subnets de base de datos; ambas rutas `0.0.0.0/0` van a la NAT instance. |
| Tráfico al back-end por load balancer | El front llama al **ALB interno** (`BACKEND_URL`), nunca al back directo. |
| Solo free tier | t3.micro, db.t4g.micro, 20 GB, 2 ALB, 10 alarmas, 1 dashboard por ambiente; NAT instance en vez de NAT Gateway. Ver [Costos](#costos). |
| Bastion corre todo Ansible | `ansible/run.sh` copia los playbooks al bastion y ejecuta `ansible-playbook` **allí**; el bastion también se configura a sí mismo (play 1 de `site.yml`). |
| Workspaces QA y Prod | `terraform workspace select qa\|prod`; estados separados en S3 (`env:/qa/...`, `env:/prod/...`). |
| Estado remoto para el equipo | Backend S3 versionado y cifrado con bloqueo nativo (`use_lockfile`). |
| Código reutilizable (módulos) | Módulos públicos `terraform-aws-modules` (vpc, alb, ec2-instance, rds) + propios (`nat-instance`, `monitoring`); rol Ansible `node_app` reutilizado por front y back. |
| Monitoreo in-house + diagrama | CloudWatch (agente, logs, dashboard, alarmas, SNS); diagrama en `docs/architecture.md`. |

## Decisiones por pilar del AWS Well-Architected Framework

### Excelencia operacional
- **Todo como código**: red, cómputo, DB, monitoreo e inventario de Ansible salen de Terraform; la configuración de servidores sale de Ansible. Un ambiente nuevo = `apply` + `run.sh`.
- **Inventario generado por Terraform** (`terraform/ansible.tf`): IPs y endpoints reales, nunca desactualizados.
- **Ansible idempotente**: la segunda ejecución da `changed=0`; esquema con `CREATE TABLE IF NOT EXISTS` y seeds solo si la tabla está vacía.
- **systemd** para las apps (reinicio automático; `npm start` del repo usa sintaxis de Windows).
- **Registro de cambios** con el porqué de cada decisión.

### Seguridad
- **Capas de red**: solo el ALB público y el bastion tienen entrada desde internet; front, back y DB en subnets privadas.
- **Security groups encadenados** por referencia de SG (mínimo privilegio), SSH al bastion solo desde una IP `/32`.
- **Contraseña de la DB**: generada como valor efímero y enviada como argumento *write-only* a RDS y a SSM Parameter Store (SecureString) → **no queda en el state de Terraform** ni en el repo; Ansible la lee en el bastion con su rol IAM y `no_log`.
- **Llave SSH**: key pair importado (la privada nunca sale de tu equipo ni entra al state); Ansible usa agent forwarding, la llave no se copia al bastion.
- **IAM mínimo**: front/back solo pueden publicar métricas/logs; el bastion además lee `/<proyecto>/<ambiente>/*` de SSM.
- IMDSv2 obligatorio en todas las instancias; discos EBS, RDS y estado S3 cifrados; acceso público al bucket bloqueado; parches de seguridad aplicados por Ansible (rol `common`).

### Fiabilidad
- 2 AZ para ALB y subnet group de RDS; health checks del ALB y reinicio automático por systemd.
- Backups automáticos de RDS (1 día) y versionado del estado de Terraform.
- Alarma de *status check* en la NAT instance (punto único de falla, ver trade-offs).

### Eficiencia de rendimiento
- Instancias burstable (t3/t4g) adecuadas a una app ligera; Node 22 LTS.
- ALB interno desacopla front y back: el back puede escalar a más instancias sin cambiar el front.

### Optimización de costos
- **NAT instance** en vez de NAT Gateway (~US$32/mes + tráfico).
- **SSM Parameter Store** en vez de Secrets Manager (US$0.40/secreto/mes).
- RDS **Single-AZ**, 20 GB gp2 sin autoescalado, sin Performance Insights.
- **Destroy al terminar cada sesión**; qa y prod no se levantan a la vez.
- **AWS Budget** de US$10/mes sin descontar créditos (alerta real de consumo) y tags `Project/Environment/Owner/ManagedBy` en todo.
- Logs con retención de 7 días.

### Sostenibilidad
- Recursos mínimos y apagados cuando no se usan; instancias de generación actual.

## Trade-offs conocidos (aceptados por presupuesto)

| Trade-off | Riesgo | Cómo mejorarlo con presupuesto |
|---|---|---|
| NAT instance única | Si cae, las subnets privadas pierden salida a internet (la app sigue sirviendo). Hay alarma. | NAT Gateway por AZ. |
| Una instancia de front y una de back | Sin alta disponibilidad de cómputo. | Auto Scaling Groups en 2 AZ detrás de los mismos ALB. |
| RDS Single-AZ | Caída de la AZ = caída de la DB. | Multi-AZ. |
| La app usa el usuario maestro de la DB | Más permisos de los necesarios. | Usuario propio con permisos solo sobre `movie_db`. |
| HTTP sin TLS | Tráfico sin cifrar. | Certificado ACM (gratis) + dominio + listener 443. |

## Costos

La cuenta está en el **plan Free de AWS con créditos**: no hay cargos a la tarjeta, pero cada hora de recursos consume créditos.

| Recurso (por ambiente) | Aprox. US$/h |
|---|---|
| 4 × EC2 t3.micro (front, back, bastion, NAT) | 0.042 |
| 2 × ALB | 0.045 |
| RDS db.t4g.micro | 0.016 |
| 4 IPv4 públicas (NAT, bastion, ALB público × 2) | 0.020 |
| **Total** | **≈ 0.12** (≈ US$3/día si se deja encendido) |

SNS, SSM, S3 (estado), CloudWatch (10 alarmas, 1 dashboard, 6 métricas custom, logs) y el Budget quedan dentro de los límites gratuitos.

## Estructura del repositorio

```
├── movie-analyst-api/        # back-end (cambiado a mysql2) + schema.sql
├── movie-analyst-ui/         # front-end
├── terraform/
│   ├── global/               # una sola vez: tópico SNS + suscripción email
│   ├── modules/nat-instance/ # NAT instance (módulo propio)
│   ├── modules/monitoring/   # log groups, 10 alarmas, dashboard (módulo propio)
│   ├── main.tf               # VPC + subnet management + NAT
│   ├── security.tf  alb.tf  compute.tf  database.tf  monitoring.tf  ansible.tf
│   └── backend.tf  versions.tf  providers.tf  variables.tf  locals.tf  outputs.tf
├── ansible/
│   ├── site.yml  ansible.cfg  run.sh
│   └── roles/ common  nodejs  node_app  db_init  cloudwatch_agent
├── docs/                     # diagrama, plan, enunciado original
└── REGISTRO-CAMBIOS.md
```

## Cómo desplegar

### Una sola vez
1. Usuario IAM con permisos de administrador y `aws configure` (región `us-east-1`).
2. Bucket S3 de estado (versionado, cifrado, acceso público bloqueado) — su nombre va en `terraform/backend.tf`.
3. Importar tu llave pública como key pair `epam-final-task`:
   `aws ec2 import-key-pair --key-name epam-final-task --public-key-material fileb://~/.ssh/id_ed25519.pub`
4. Alertas: `cp terraform/global/terraform.tfvars.example terraform/global/terraform.tfvars`, poner tu email, `terraform -chdir=terraform/global init && terraform -chdir=terraform/global apply`, y **confirmar el correo de AWS Notifications**.
5. `cp terraform/terraform.tfvars.example terraform/terraform.tfvars` y poner tu IP (`curl -s https://checkip.amazonaws.com`) con `/32`.

### Cada ambiente (`qa` o `prod`)
```bash
cd terraform
terraform init
terraform workspace select qa          # o prod
terraform apply
cd ..
ssh-add ~/.ssh/id_ed25519              # el agente se reenvía al bastion
ansible/run.sh qa                      # Ansible se ejecuta en el bastion
terraform -chdir=terraform output app_url
```

### Apagar (no dejar consumiendo créditos)
```bash
terraform -chdir=terraform workspace select qa && terraform -chdir=terraform destroy
```

## Monitoreo

- **Dashboard** `epam-final-task-<ambiente>` (salida `dashboard_url`): alarmas, CPU, memoria, disco, peticiones/5xx, targets sanos y latencia de los ALB, RDS y últimos logs.
- **Alarmas** (10 por ambiente, aviso de alarma y de recuperación por email): CPU y memoria de front y back, status check de la NAT, hosts no sanos en ALB público e interno, 5xx del ALB público, CPU y almacenamiento libre de RDS.
- **Logs**: `/epam-final-task-<ambiente>/movie-analyst-api` y `.../movie-analyst-ui` (7 días).
- Tras un despliegue nuevo llegan emails de ALARM que vuelven solos a OK cuando Ansible termina: hosts no sanos (la app aún no está instalada) y memoria (el agente aún no publica, y la falta de datos cuenta como alarma a propósito). Si se destruye el ambiente justo después, el OK no alcanza a llegar.
- Probar una notificación: `aws cloudwatch set-alarm-state --alarm-name epam-final-task-prod-back-cpu-high --state-value ALARM --state-reason "prueba"`.

## Cambios a la aplicación

- `movie-analyst-api`: `mysql` → `mysql2` (el paquete viejo no soporta `caching_sha2_password`, el método por defecto de MySQL 8.4). Solo cambia el `require`.
- `movie-analyst-api/schema.sql`: no existía; usa `release_year` (lo que usan `seeds.js` y `/movies`) en lugar de `release` del diagrama.
- Bugs del código original que **no** se corrigieron (no afectan la UI): `res.staus` en los `catch` (una petición con error de DB se queda colgada), y el SQL mal concatenado de `/pending`. Por eso el health check del back usa `/` y no `/movies`.

## Evidencias

Capturas de la app funcionando, el dashboard, las alarmas, los target groups y la notificación por email: [docs/evidencias/](docs/evidencias/).
