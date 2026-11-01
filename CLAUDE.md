# Reglas del proyecto (EPAM Final Task — AWS + Terraform + Ansible)

- Guía: `docs/plan-ejecucion.md`. Cada cambio se apunta en `REGISTRO-CAMBIOS.md` con su porqué.
- Costo cero: solo recursos free tier / plan Free (créditos). Avisar antes de crear algo que cobre. `terraform destroy` al terminar cada sesión.
- Workspaces: `qa` (apply/destroy sin preguntar) y `prod` (pedir confirmación siempre). Nunca usar `default`.
- Terraform desde `terraform/`: `terraform workspace select qa && terraform plan`.
- Ansible corre en el bastion, nunca desde la máquina local.
- No subir secretos: `terraform.tfvars`, `*.pem`, state y `.terraform/` están en `.gitignore`.
