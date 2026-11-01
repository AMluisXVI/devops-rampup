# Plan de ejecución — Final Task Cloud & DevOps (AWS + Terraform + Ansible)

Preparación para ejecutar la tarea con Claude Code. Nube: **AWS** (región sugerida `us-east-1`).

## 0. Lo que hay en la app (revisado del repo)

Repo de la app (público): https://github.com/aljoveza/devops-rampup (rama `master`). Guía: `rampup-final-task (F2).pdf`.
El diagrama de la guía pone el front en subnet pública; aquí va en privada detrás del ALB (más seguro, misma funcionalidad) → documentarlo como decisión.
La guía nombra "nat-gateway", pero exige free tier → NAT instance, justificado en el README (el cliente acepta gasto solo con razón de peso).

| Componente | Carpeta | Puerto | Variables de entorno |
|---|---|---|---|
| Front-end (Node/Express + EJS) | `movie-analyst-ui` | 3030 | `PORT`, `BACKEND_URL` (host:puerto, **sin** `http://`) |
| Back-end (Node/Express API) | `movie-analyst-api` | 3000 | `PORT`, `DB_HOST`, `DB_USER`, `DB_PASS`, `DB_NAME` (`movie_db`) |
| Base de datos | RDS MySQL | 3306 | — |

Hallazgos que afectan la ejecución:
- **No hay script `CREATE TABLE`**: solo `schema.png` y `seeds.js` (que solo hace INSERT). Hay que escribir `schema.sql`. Ojo: el diagrama dice `release`, pero `seeds.js` y `/movies` usan **`release_year`** → usar `release_year`.
- `npm start` usa `SET NODE_ENV=dev` (sintaxis Windows) → en Linux arrancar con `node server.js` desde un servicio **systemd** con las variables de entorno.
- La API usa el paquete `mysql` (antiguo), que no soporta el método de autenticación por defecto de MySQL 8 (`caching_sha2_password`). Opciones: crear el usuario de la app con `mysql_native_password` (en MySQL 8.4 requiere habilitarlo en un parameter group) **o** cambiar a `mysql2` en `server.js`/`seeds.js`. Verificarlo temprano (Fase 5).
- RDS MySQL 8.0 salió de soporte estándar (jul-2026) y cobra "extended support" → usar **MySQL 8.4**.
- Bugs menores de la app (`res.staus`, SQL de `/pending` mal concatenado): no bloquean la UI; documentarlos, no es obligatorio corregirlos.

## 1. Decisiones de arquitectura (y su porqué)

| Decisión | Por qué |
|---|---|
| VPC propia `10.0.0.0/16` en **2 AZ** | El ALB y el DB subnet group de RDS exigen subnets en 2 AZ. |
| Subnets: pública (ALB, NAT), management (bastion), privada app (front y back), privada DB | Separación por capa = pilar de Seguridad del Well-Architected. |
| **NAT instance** (t3.micro / t2.micro) en vez de NAT Gateway | NAT Gateway no es free tier (~US$32/mes). Cumple "salida a internet" desde subnets privadas a costo cero. Trade-off: no es gestionado ni HA → aceptable para el contexto de crisis económica; documentarlo. |
| Front-end también en subnet privada detrás del ALB público | Nada expuesto salvo ALB y bastion (SSH solo desde tu IP). |
| Back-end detrás de un **ALB** (obligatorio) | Opción A: ALB interno para el back + ALB público para el front (más limpio, ~2 ALB = excede 750 h/mes gratis). Opción B: un solo ALB con listener 80→front y listener 3000→back (más barato, back expuesto por el ALB; mitigar con SG). **Decidir en Fase 3.** |
| RDS `db.t4g.micro`/`db.t3.micro`, Single-AZ, 20 GB gp3, sin réplicas | Free tier; Multi-AZ duplica costo. Backups automáticos 1 día. |
| Contraseña DB en **SSM Parameter Store (SecureString)** | Gratis (tier estándar); Secrets Manager cuesta ~US$0.40/secreto/mes. |
| Estado remoto en **S3** (bucket creado a mano, versionado + cifrado) con `use_lockfile = true` | Terraform ≥1.10 hace locking nativo en S3 → no hace falta DynamoDB. |
| **Workspaces** `qa` y `prod` | Mismo código, estado separado (`env:/qa/...`, `env:/prod/...`); tamaños vía `terraform.workspace` + `.tfvars`. |
| Módulos públicos `terraform-aws-modules` (vpc, security-group, alb, rds, ec2-instance) + módulos locales propios (`nat-instance`, `bastion`) | Reutilizable y mantenible (requisito del cliente). El módulo vpc se usa con `enable_nat_gateway = false` y la ruta 0.0.0.0/0 apunta a la ENI de la NAT instance. |
| **Ansible** se ejecuta desde el bastion | Requisito. `user_data` solo instala Ansible + git; todo lo demás (Node, apps, systemd, CloudWatch agent, schema/seeds) lo hace Ansible. |
| Monitoreo con **CloudWatch** (métricas EC2/ALB/RDS, CloudWatch Agent para RAM/disco/logs, dashboard, alarmas → SNS email) | In-house, sin terceros. Free tier: 10 alarmas, 3 dashboards, 10 métricas custom, 5 GB logs. |
| Tags comunes (`Project`, `Environment`, `Owner`) + AWS Budget | Pilar de Optimización de Costos. |

## 2. Riesgo principal: costos

- **Las 750 h/mes de EC2 gratis son compartidas entre todas las instancias.** QA + Prod × (front, back, bastion, NAT) = 8 instancias → se agotan en ~4 días.
- Estrategia: desarrollar y probar en **qa**, destruir; levantar **prod** solo para la demo/evaluación; `terraform destroy` al terminar cada sesión.
- Cuentas creadas después de jul-2025 usan el plan con créditos (US$100–200, 6 meses); verificar en Billing qué plan tiene tu cuenta.
- Primer paso obligatorio: **AWS Budget** de US$1–5 con alerta por email.

## 3. Qué es manual (lo haces tú) vs. qué hace Claude Code

**Manual — tú:**
1. Cuenta AWS, MFA en root, usuario IAM (o IAM Identity Center) para trabajar; nunca usar root.
2. `aws configure` en tu máquina. **No pegar llaves de acceso en el chat ni en el código.**
3. Crear AWS Budget + alerta.
4. Crear bucket S3 de estado (versionado, cifrado, bloqueo de acceso público) — permitido por la guía.
5. Crear el EC2 Key Pair y guardar el `.pem` (mejor que generarlo con Terraform, porque la llave privada quedaría en el state).
6. Obtener tu IP pública (`curl ifconfig.me`) para el SG del bastion.
7. Revisar cada `terraform plan` y aprobar `apply`/`destroy`.
8. Confirmar la suscripción de SNS en el correo.
9. Capturas de pantalla de evidencia (consola, app funcionando, dashboard, alarma).
10. Crear repo en GitHub y hacer push.

**Claude Code puede hacer:** escribir todo el Terraform, playbooks/roles de Ansible, `schema.sql`, unidades systemd, config del CloudWatch agent, README con decisiones, diagrama (Mermaid / draw.io XML / `diagrams` de Python), y correr `terraform fmt/validate/plan`, `tflint`, `ansible-lint`, diagnosticar errores.

**Limitaciones de Claude Code a tener en cuenta:**
- Usa **tus** credenciales locales: puede ejecutar `apply`/`destroy` si se lo permites → trabaja en modo que pida confirmación y revisa el plan tú.
- No ve la consola web de AWS; verifica por AWS CLI o le pegas el error.
- Sesiones SSH interactivas al bastion no son su fuerte; mejor comandos no interactivos (`ssh -J`, `ansible-playbook` remoto) o los corres tú.
- Si estás en **Windows**: Terraform y AWS CLI funcionan nativo; Ansible solo corre en el bastion (Linux), así que no necesitas instalarlo localmente.
- Contexto: usa un `CLAUDE.md` con estas reglas y trabaja **una fase por sesión** con commit al final.

## 4. Estructura del repositorio

```
final-task/
├── CLAUDE.md                # reglas para Claude Code
├── README.md                # decisiones, cómo desplegar, evidencias
├── docs/architecture.(png|drawio|md)
├── app/                     # copia de movie-analyst-ui y movie-analyst-api
├── terraform/
│   ├── backend.tf  providers.tf  versions.tf
│   ├── main.tf  variables.tf  locals.tf  outputs.tf
│   ├── env/qa.tfvars  env/prod.tfvars
│   └── modules/ nat-instance/  bastion/  monitoring/
└── ansible/
    ├── ansible.cfg  inventory (generado por Terraform)
    ├── site.yml
    └── roles/ common/ bastion/ nodejs/ backend/ frontend/ db_init/ cloudwatch_agent/
```

## 5. Fases de ejecución

| Fase | Qué se hace | Quién | Validación |
|---|---|---|---|
| 0 | Prerrequisitos: cuenta, IAM, Budget, bucket S3, key pair, instalar Terraform ≥1.10 + AWS CLI + Claude Code | Tú | `aws sts get-caller-identity` OK |
| 1 | Crear repo, copiar app, `CLAUDE.md`, esqueleto Terraform, backend S3, workspaces `qa`/`prod` | Claude Code + tú | `terraform init`, `terraform workspace list` |
| 2 | Red: VPC, subnets 2 AZ, IGW, route tables, NAT instance (módulo propio, `source_dest_check=false`, iptables), SG base | Claude Code | `plan` limpio; apply en qa; desde una instancia privada `curl` a internet |
| 3 | ALB(s) + target groups + health checks (`/` en 3030, `/movies` en 3000) — decidir opción A/B | Claude Code + decisión tuya | Targets `healthy` |
| 4 | Cómputo: bastion (management subnet, SSH desde tu IP), EC2 front y back (privadas, IAM role con `CloudWatchAgentServerPolicy` + lectura SSM), `user_data` mínimo; output → inventario Ansible | Claude Code | `ssh -J` al back vía bastion |
| 5 | RDS MySQL 8.4 + subnet group + SG (3306 solo desde SG del back) + password en SSM; resolver tema de autenticación (`mysql2` o `mysql_native_password`) | Claude Code | Conexión `mysql` desde el back |
| 6 | Ansible: roles common/nodejs/backend/frontend/db_init (schema.sql + seeds.js) /systemd; copiar playbooks al bastion y ejecutar | Claude Code escribe, tú ejecutas (o vía SSH) | `curl http://<ALB>/movies` muestra datos |
| 7 | Monitoreo: CloudWatch agent (Ansible), log groups, dashboard, alarmas (CPU EC2, ALB 5xx / UnHealthyHosts, RDS CPU / FreeStorage) → SNS | Claude Code + confirmas email | Dashboard con datos; disparar una alarma de prueba |
| 8 | Repetir en workspace `prod` con `prod.tfvars` | Tú apruebas | App OK en prod |
| 9 | Documentación: README con decisiones vs. pilares Well-Architected, diagrama de arquitectura, costos, evidencias | Claude Code + capturas tuyas | Revisión contra la guía |
| 10 | `terraform destroy` de lo que no se evalúe | Tú | Billing sin cargos |

## 6. Checklist de requisitos obligatorios

- [ ] Sin serverless; todo sobre instancias
- [ ] DB en RDS MySQL
- [ ] DB y back-end en subnets privadas con salida a internet (NAT instance)
- [ ] Tráfico al back-end vía load balancer
- [ ] Solo free tier (justificar cualquier excepción)
- [ ] Bastion ejecuta todo Ansible (incluida su propia config)
- [ ] Workspaces QA y Prod
- [ ] Estado remoto compartido con locking
- [ ] Módulos reutilizables
- [ ] Monitoreo in-house + diagrama de arquitectura
- [ ] Cada decisión documentada con su porqué
