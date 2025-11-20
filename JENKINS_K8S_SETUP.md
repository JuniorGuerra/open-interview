# Configuración de Jenkins para Despliegue en Kubernetes Remoto

## 3 Opciones para Desplegar en K8s desde Jenkins

### OPCIÓN 1: Usando Kubeconfig (RECOMENDADA)

Esta opción usa el archivo kubeconfig para conectarse directamente al cluster remoto.

#### Pasos:

1. **Obtener el kubeconfig del cluster remoto:**
   ```bash
   # En el servidor K8s
   cat ~/.kube/config
   ```

2. **Agregar credencial en Jenkins:**
   - Ve a: `Manage Jenkins` → `Credentials` → `System` → `Global credentials`
   - Click en `Add Credentials`
   - Tipo: `Secret file`
   - File: Sube tu archivo kubeconfig
   - ID: `k8s-kubeconfig`
   - Description: `Kubernetes Config File`

3. **Instalar kubectl en Jenkins:**
   ```bash
   # En el servidor Jenkins
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   chmod +x kubectl
   sudo mv kubectl /usr/local/bin/
   ```

4. **Activar en Jenkinsfile:**
   - Ya está activada por defecto (líneas 113-124)

**Ventajas:**
- Simple y directa
- No requiere acceso SSH
- Kubectl se ejecuta desde Jenkins

**Desventajas:**
- Necesita kubectl instalado en Jenkins
- Requiere acceso de red al API server de K8s

---

### OPCIÓN 2: SSH al Servidor Remoto

Esta opción se conecta por SSH al servidor donde está K8s y ejecuta kubectl ahí.

#### Pasos:

1. **Generar par de llaves SSH:**
   ```bash
   # En Jenkins
   ssh-keygen -t rsa -b 4096 -f jenkins_k8s_key
   ```

2. **Copiar clave pública al servidor K8s:**
   ```bash
   ssh-copy-id -i jenkins_k8s_key.pub user@k8s-server
   ```

3. **Agregar credencial SSH en Jenkins:**
   - Ve a: `Manage Jenkins` → `Credentials` → `Add Credentials`
   - Tipo: `SSH Username with private key`
   - ID: `k8s-server-ssh`
   - Username: `tu-usuario`
   - Private Key: Pega el contenido de `jenkins_k8s_key`

4. **Activar en Jenkinsfile:**
   - Comenta las líneas 113-124 (Opción 1)
   - Descomenta las líneas 126-140 (Opción 2)
   - Cambia `k8s-server` por la IP/hostname de tu servidor

**Ventajas:**
- No requiere acceso directo al API de K8s
- Kubectl ya instalado en el servidor K8s
- Más seguro si K8s no está expuesto

**Desventajas:**
- Requiere acceso SSH
- Un paso adicional (SCP + SSH)

---

### OPCIÓN 3: Plugin Kubernetes de Jenkins

Esta opción usa el plugin oficial de Kubernetes para Jenkins.

#### Pasos:

1. **Instalar plugin:**
   - Ve a: `Manage Jenkins` → `Manage Plugins` → `Available`
   - Busca: `Kubernetes Continuous Deploy`
   - Instala y reinicia Jenkins

2. **Configurar credencial kubeconfig:**
   - Igual que en Opción 1
   - ID: `k8s-kubeconfig`

3. **Activar en Jenkinsfile:**
   - Comenta las líneas 113-124 (Opción 1)
   - Descomenta las líneas 142-147 (Opción 3)

**Ventajas:**
- Interfaz amigable
- Soporte para substitución de variables
- Manejo automático de errores

**Desventajas:**
- Requiere plugin adicional
- Menos control granular

---

## Comparación Rápida

| Característica | Opción 1 | Opción 2 | Opción 3 |
|----------------|----------|----------|----------|
| **Facilidad**  | ⭐⭐⭐⭐ | ⭐⭐⭐   | ⭐⭐⭐⭐⭐ |
| **Seguridad**  | ⭐⭐⭐   | ⭐⭐⭐⭐ | ⭐⭐⭐   |
| **Flexibilidad** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐   |
| **Requisitos** | kubectl | SSH | Plugin |

---

## Recomendación por Escenario

### Si tu cluster K8s es accesible vía red:
→ **OPCIÓN 1** (Kubeconfig)

### Si tu cluster K8s está en red privada/VPN:
→ **OPCIÓN 2** (SSH)

### Si prefieres interfaz gráfica:
→ **OPCIÓN 3** (Plugin)

---

## Configuración Adicional

### Crear Service Account en K8s (Más Seguro)

En lugar de usar tu kubeconfig personal, crea un Service Account dedicado:

```bash
# En el servidor K8s
kubectl create namespace ci-cd
kubectl create serviceaccount jenkins-deployer -n ci-cd

# Crear Role con permisos
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: jenkins-deployer-role
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["services", "pods"]
  verbs: ["get", "list"]
EOF

# Asignar Role
kubectl create clusterrolebinding jenkins-deployer-binding \
  --clusterrole=jenkins-deployer-role \
  --serviceaccount=ci-cd:jenkins-deployer

# Obtener token
kubectl create token jenkins-deployer -n ci-cd --duration=87600h
```

Luego crea un kubeconfig con este token en lugar del admin.

---

## Troubleshooting

### Error: "Unable to connect to the server"
- Verifica que el API server sea accesible desde Jenkins
- Revisa firewall/security groups
- Prueba: `kubectl cluster-info --kubeconfig=/path/to/config`

### Error: "Forbidden: User cannot..."
- El usuario/service account no tiene permisos
- Revisa RBAC con: `kubectl auth can-i create deployments --as=system:serviceaccount:ci-cd:jenkins-deployer`

### Error SSH: "Permission denied"
- Verifica que la clave SSH esté correcta
- Prueba manualmente: `ssh -i key user@server`
- Revisa `~/.ssh/authorized_keys` en el servidor

---

## Variables de Entorno Útiles

Puedes agregar estas variables en el Jenkinsfile:

```groovy
environment {
    K8S_NAMESPACE = 'production'
    K8S_CONTEXT = 'production-cluster'
    DEPLOYMENT_NAME = 'flask-app'
}
```

Y usarlas así:

```bash
kubectl apply -f k8s/ -n ${K8S_NAMESPACE}
kubectl rollout status deployment/${DEPLOYMENT_NAME} -n ${K8S_NAMESPACE}
```
