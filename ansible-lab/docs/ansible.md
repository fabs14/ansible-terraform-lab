# Laboratorio de Attendance con Ansible

Terraform crea tres servidores Ubuntu en AWS y genera el inventario. Ansible
usa ese inventario para instalar los servicios y desplegar Attendance por SSH.
En este laboratorio, la aplicación usa un PostgreSQL propio con datos de demo.

El navegador entra por la IP pública del frontend. Nginx sirve la página y
envía las llamadas de la API al backend por la red privada. El backend se
conecta a PostgreSQL. Para administrar la base por SSH, Ansible usa el backend
como salto porque la base solo tiene una IP privada.

## 1. Preparar las carpetas y las máquinas

Usa **PowerShell en Windows** para aprovisionar las EC2 siguiendo la
[guía de Terraform](../../infra-lab/docs/terraform.md). Al terminar, espera a que las
tres instancias pasen sus comprobaciones en la consola de EC2 y comprueba
que exista `ansible-lab/inventory.ini`.

Para compilar la aplicación, `deploy.yml` espera los dos repositorios de
código como carpetas hermanas del laboratorio. Por ejemplo:

```text
C:/FABIANA/
  diplo-proy-ansible/
    infra-lab/
    ansible-lab/
  diplo-app-attendance/
    attendance-core/
    attendance-web/
```

Cada carpeta de código debe ser un clon Git. El playbook empaqueta el último
commit local (`HEAD`) de cada clon. Para desplegar una modificación local,
primero debes incluirla en un commit.

Usa tu propia clave SSH si vas a aprovisionar un entorno independiente. La
ruta del archivo público `.pub` se configura en Terraform y la clave privada
correspondiente se carga en WSL.

## 2. Preparar Ubuntu en WSL

Si todavía falta Ubuntu, abre **PowerShell como administrador** y ejecuta
`wsl --install -d Ubuntu`. Abre Ubuntu desde Inicio y crea tu usuario de
Linux cuando se te solicite. [Instalación de WSL](https://learn.microsoft.com/windows/wsl/install/)

Desde aquí, ejecuta los comandos de Ansible en la **terminal de Ubuntu**.
Instala las herramientas una vez:

```bash
sudo apt update
sudo apt install ansible-core git
ansible --version
```

Abre la carpeta `ansible-lab` y carga su configuración. Adapta la ruta a
la ubicación de tu clon. Ejecuta el `export` al abrir una terminal nueva.

```bash
cd /mnt/c/FABIANA/diplo-proy-ansible/ansible-lab
export ANSIBLE_CONFIG="$PWD/ansible.cfg"
ansible-inventory --graph
```

El gráfico debe mostrar los grupos `frontend`, `backend` y `database`,
cada uno con un servidor. `ansible.cfg` indica dónde está el inventario y
mantiene activada la comprobación de la identidad SSH de cada servidor.
Al trabajar en `/mnt/c`, el `export` le dice a Ansible qué archivo cargar.
[Configuración de Ansible](https://docs.ansible.com/projects/ansible/latest/reference_appendices/config.html)

## 3. Cargar la clave SSH y probar la conexión

Si la clave privada se creó en Windows, cópiala una sola vez al directorio
personal de Ubuntu. Reemplaza `TU_USUARIO_WINDOWS` por el nombre de tu
carpeta dentro de `C:\Users`. Si la clave se llama de otra manera, ajusta
la ruta de origen.

```bash
install -d -m 700 ~/.ssh
test -e ~/.ssh/attendance-lab || install -m 600 /mnt/c/Users/TU_USUARIO_WINDOWS/.ssh/attendance-lab ~/.ssh/attendance-lab
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/attendance-lab
```

`ssh-add` pide la frase de paso de la clave. Conserva esta terminal abierta
para que SSH y Ansible puedan usar el agente, incluido el salto a la base.

Lee las direcciones que Terraform escribió en el inventario:

```bash
backend=$(awk -F '[ =]+' '/^attendance-backend / {print $3}' inventory.ini)
frontend=$(awk -F '[ =]+' '/^attendance-frontend / {print $3}' inventory.ini)
database=$(awk -F '[ =]+' '/^attendance-database / {print $3}' inventory.ini)
```

En la consola de EC2, selecciona cada instancia y consulta **Acciones →
Supervisar y solucionar problemas → Obtener registro del sistema**. Busca
`BEGIN SSH HOST KEY FINGERPRINTS` y guarda la huella ED25519 de cada
instancia. Luego ejecuta estos comandos uno por uno. Si SSH te pregunta si
confías en el servidor, acepta solo cuando coincida la huella del servidor
correspondiente. Cada comando debe devolver el nombre del equipo.
[Verificar las huellas SSH de EC2](https://docs.aws.amazon.com/es_es/AWSEC2/latest/UserGuide/connection-prereqs-general.html)

```bash
ssh -o HostKeyAlgorithms=ssh-ed25519 "ubuntu@$backend" hostname
ssh -o HostKeyAlgorithms=ssh-ed25519 "ubuntu@$frontend" hostname
ssh -o HostKeyAlgorithms=ssh-ed25519 -J "ubuntu@$backend" "ubuntu@$database" hostname
ansible all -m ansible.builtin.ping
```

Espera **`SUCCESS` y `pong` en los tres servidores**. Este módulo verifica
la conexión SSH y que Ansible pueda ejecutar Python en el servidor.
[Prueba de conexión de Ansible](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/ping_module.html)

## 4. Ejecutar `install.yml`

[`install.yml`](../install.yml) instala PostgreSQL en la base de datos,
Node.js y pnpm en los servidores de aplicación, y Nginx en el frontend.

Como la base está en una subred privada, sus paquetes se descargan a través
de un túnel SSH temporal hacia Ubuntu en WSL. El bloque usa el inventario
y las variables `backend` y `database` del paso anterior. Cópialo entero
en la misma terminal. El túnel se cierra cuando termina el playbook.

```bash
(
  set -e
  tunnel_dir=$(mktemp -d "$HOME/.ssh/attendance-apt.XXXXXX")
  socket="$tunnel_dir/control"
  trap 'ssh -S "$socket" -O exit "ubuntu@$database" >/dev/null 2>&1 || true; rmdir "$tunnel_dir"' EXIT

  ssh -fNT -M -S "$socket" -o ExitOnForwardFailure=yes \
    -J "ubuntu@$backend" -R 127.0.0.1:1080 "ubuntu@$database"

  ansible-playbook install.yml
)
```

**Cómo comprobarlo**

- En `PLAY RECAP`, los tres servidores deben tener `unreachable=0` y
  `failed=0`.
- Las tareas de PostgreSQL, de las versiones de Node.js y pnpm, y de la
  respuesta HTTP de Nginx deben finalizar correctamente.
- Abre `http://IP_PUBLICA_DEL_FRONTEND/` desde la red autorizada. En una
  instalación nueva verás la página de bienvenida de Nginx.

## 5. Ejecutar `deploy.yml`

[`deploy.yml`](../deploy.yml) crea la base de Attendance, configura el acceso
privado desde el backend, ejecuta las migraciones y carga la institución
`demo`. Después activa el backend como un servicio de Linux y configura
Nginx para servir la aplicación y reenviar las llamadas a la API.

Puedes comprobar la sintaxis y ejecutar el despliegue directamente. Este
playbook ya no necesita el túnel de descarga de paquetes.

```bash
ansible-playbook --syntax-check deploy.yml
ansible-playbook deploy.yml
```

**Cómo comprobarlo**

- Los tres servidores y `localhost` deben mostrar `unreachable=0` y
  `failed=0`. El playbook comprueba la portada, `/login` y un inicio de
  sesión de estudiante a través de Nginx.
- Abre la URL que imprime el playbook en el navegador. Selecciona
  **Estudiante**, usa la institución **`demo`** y el registro **`1001`**.
  Al entrar al panel habrás probado la web, la API y la base de datos.
- Si quieres comprobar solo la ruta de la API desde Ubuntu, ejecuta
  `curl -fsS "http://$frontend/core/api/v1"`. Debe devolver
  `Hello World!`.

La demo usa HTTP y datos sintéticos. El playbook guarda las contraseñas
generadas en `~/.config/attendance-lab/`, dentro de Ubuntu. Si vas a
demostrar la vista de administrador, el usuario de la institución `demo`
es `admin@core.com` y su contraseña queda en
`~/.config/attendance-lab/demo-admin-password`.

## 6. Entender el resultado y repetir la práctica

En `PLAY RECAP`, `ok` cuenta las tareas correctas, `changed` indica
cuántas hicieron cambios y `skipped` indica tareas que no aplicaban.
Si aparece `failed` o `unreachable`, revisa la primera tarea que dio error.
Si falla SSH, comprueba el inventario, el agente de claves y que tu IPv4
pública siga siendo la autorizada en Terraform.

Para empezar de cero en AWS, usa **PowerShell** desde `infra-lab`.
Ejecuta `terraform plan -destroy` para revisar y `terraform destroy`
para eliminar el laboratorio. Al confirmar se eliminan las EC2, sus discos,
los datos de PostgreSQL y el inventario generado. Conserva el estado local
hasta que finalice la eliminación. [Comando de eliminación de Terraform](https://developer.hashicorp.com/terraform/cli/commands/destroy)

Vuelve a ejecutar Terraform para generar un inventario nuevo y repite los
pasos 3 a 5. Puedes reutilizar las herramientas y tu clave SSH local. Si
SSH avisa que cambió la huella porque una EC2 nueva reutilizó una IP,
corrobora primero la huella nueva en AWS. Luego borra solo la entrada de
esa IP con `ssh-keygen -R IP_REUTILIZADA` y vuelve a conectarte.

Si publicas el repositorio, incluye el código, los playbooks, las plantillas
y el ejemplo de variables. Conserva en tu equipo las claves privadas,
el estado, los planes, el inventario generado y los secretos de la demo.
