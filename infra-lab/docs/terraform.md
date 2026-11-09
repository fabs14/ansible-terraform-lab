# Attendance · Terraform para el laboratorio de Ansible

Esta configuración usa el perfil `attendance-lab` en `us-east-2` y guarda
su propio estado local en `infra-lab/terraform.tfstate`. Terraform compara la
cuenta autenticada con el valor de `aws_account_id` antes de trabajar.

Desde la raíz del laboratorio, `infra-lab/` contiene Terraform y
`ansible-lab/` contiene los playbooks. Los archivos `backend.tf`,
`providers.tf` y `versions.tf` separan el estado, el acceso a AWS y las
versiones de los proveedores. `inventory.tf` genera el inventario de Ansible
con la plantilla de `templates/`.

Terraform descarga los proveedores en `.terraform/providers`. Esa carpeta,
el estado local y los planes pueden aparecer en el Explorador de archivos,
pero Git los excluye. El archivo `.terraform.lock.hcl` fija las versiones y
forma parte del código del laboratorio.

## 1. Preparar el acceso desde PowerShell

Confirma que la cuenta devuelta es la del laboratorio.

```powershell
aws sts get-caller-identity --profile attendance-lab --region us-east-2
```

La clave pública del operador está en `infra-lab/keys/operator.pub`.
Terraform lee ese archivo y la clave privada correspondiente se guarda
fuera del repositorio. Si vas a iniciar un laboratorio propio con otra
clave, puedes crearla con una frase de paso.

```powershell
$labKey = Join-Path $env:USERPROFILE '.ssh\attendance-lab'
New-Item -ItemType Directory -Force (Split-Path $labKey) | Out-Null
if ((Test-Path -LiteralPath $labKey) -or (Test-Path -LiteralPath "$labKey.pub")) {
    Write-Output 'Ya existe un archivo de clave del laboratorio. Revísalo antes de continuar.'
} else {
    ssh-keygen -t ed25519 -f $labKey -C 'attendance-lab'
}
```

Para usar una clave nueva en un laboratorio independiente, indica su ruta
pública con `ssh_public_key_path = "~/.ssh/attendance-lab.pub"` en tu
`lab.auto.tfvars`. Conserva la clave pública actual para este despliegue.

Consulta tu IPv4 pública desde la red que usarás para el laboratorio.

```powershell
Invoke-RestMethod 'https://checkip.amazonaws.com'
```

## 2. Preparar y revisar el plan

Desde la raíz del laboratorio, copia el ejemplo una sola vez y abre el archivo
local para completar el ID de la cuenta verificada y la IPv4 seguida de `/32`.
El archivo local, el plan y el estado están excluidos de Git.

```powershell
Set-Location 'C:\FABIANA\diplo-proy-ansible'
if (-not (Test-Path -LiteralPath 'infra-lab/lab.auto.tfvars')) {
    Copy-Item 'infra-lab/examples/ansible-lab.tfvars.example' 'infra-lab/lab.auto.tfvars'
}
notepad.exe infra-lab/lab.auto.tfvars
```

Después de guardar los valores, ejecuta estos comandos en orden.

```powershell
terraform -chdir=infra-lab init
terraform -chdir=infra-lab fmt -check -recursive
terraform -chdir=infra-lab validate
terraform -chdir=infra-lab plan '-input=false' '-out=lab.tfplan'
terraform -chdir=infra-lab show lab.tfplan
```

El plan inicial debe incluir tres EC2 nuevas y sus recursos auxiliares, con
cero cambios y cero eliminaciones. Revisa que la base de datos quede sin IP
pública y que su puerto `5432` solo acepte conexiones del backend. El
frontend admite HTTP desde la IPv4 del operador para una demo con datos
sintéticos. Las instancias EC2, los discos y las IPv4 públicas pueden generar
cargos. Revisa el costo antes de aplicar el plan.

## 3. Después de aplicar el plan revisado

Terraform genera `ansible-lab/inventory.ini` con las direcciones y el salto
SSH a la base a través del backend. Para usarlo desde Ubuntu en WSL, carga la
clave del laboratorio en el agente SSH de WSL para que también esté disponible
durante el salto. Ansible instalará los servicios. La base privada requerirá
un túnel temporal para que APT descargue los paquetes durante esa etapa.

Continúa con la [guía de Ansible](../../ansible-lab/docs/ansible.md) para probar SSH,
instalar los servicios y desplegar Attendance.

Conserva el estado local hasta haber revisado y ejecutado el plan de
eliminación al final de la práctica.
