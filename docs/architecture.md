# Diagrama de arquitectura

Un ambiente (workspace `qa` = `10.0.0.0/16`, `prod` = `10.1.0.0/16`). Región `us-east-1`, 2 zonas de disponibilidad.

```mermaid
flowchart LR
  users([Usuarios]) -->|HTTP :80| albpub
  admin([Admin<br/>tu IP /32]) -->|SSH :22| bastion

  subgraph aws[AWS us-east-1]
    subgraph vpc[VPC 10.x.0.0/16]
      igw[Internet Gateway]

      subgraph pub[Subnets públicas · 2 AZ]
        albpub[ALB público<br/>:80]
        nat[NAT instance<br/>t3.micro]
      end

      subgraph mgmt[Subnet management]
        bastion[Bastion<br/>t3.micro<br/>Ansible]
      end

      subgraph priv[Subnets privadas app · 2 AZ]
        front[Front-end<br/>Node :3030<br/>t3.micro]
        albint[ALB interno<br/>:80]
        back[Back-end API<br/>Node :3000<br/>t3.micro]
      end

      subgraph dbnet[Subnets de base de datos · 2 AZ]
        rds[(RDS MySQL 8.4<br/>db.t4g.micro<br/>Single-AZ)]
      end
    end

    ssm[[SSM Parameter Store<br/>contraseña DB]]
    cw[[CloudWatch<br/>métricas · logs · dashboard · 10 alarmas]]
    sns[[SNS<br/>alertas por email]]
    s3[[S3<br/>estado Terraform + lock]]
  end

  albpub -->|:3030| front
  front -->|BACKEND_URL :80| albint
  albint -->|:3000| back
  back -->|:3306| rds

  bastion -. SSH / Ansible .-> front
  bastion -. SSH / Ansible .-> back
  bastion -. lee contraseña .-> ssm

  priv -. salida a internet .-> nat
  dbnet -. salida a internet .-> nat
  nat --> igw
  bastion --> igw
  albpub --- igw

  vpc -. métricas y logs .-> cw
  cw -->|alarma / OK| sns
```

## Flujo de una petición

1. El usuario abre `http://<ALB público>/` → el ALB reenvía a `front:3030`.
2. El front llama a `http://<ALB interno>/movies` (`BACKEND_URL`) → el ALB interno reenvía a `back:3000`.
3. El back consulta RDS por `:3306` y devuelve JSON; el front lo renderiza.

## Security groups (mínimo privilegio)

| SG | Entrada permitida |
|---|---|
| ALB público | `:80` desde internet |
| front | `:3030` desde ALB público · `:22` desde bastion |
| ALB interno | `:80` desde SG del front |
| back | `:3000` desde ALB interno · `:22` desde bastion |
| RDS | `:3306` desde SG del back |
| bastion | `:22` desde tu IP `/32` |
| NAT | todo desde el CIDR de la VPC |
