# DevOps Challenge

## Descripción
En este reto, trabajarás con una aplicación web simple que cuenta visitas usando Flask y Redis. Tu tarea es containerizar la aplicación y preparar su despliegue siguiendo las mejores prácticas de DevOps.

## La Aplicación
- Backend en Flask (Python)
- Base de datos Redis para el contador
- Endpoints:
  - `/` - Página principal con contador
  - `/health` - Health check
  - `/api/visits` - API que retorna el contador

## Tareas a Realizar

### 1. Containerización
- [ x ] Crear `Dockerfile` para la aplicación Flask
  - Usar una imagen base oficial de Python
  - Instalar dependencias desde requirements.txt
  - Exponer el puerto 8080
  - Configurar health check 
  
- [ x ] Crear `docker-compose.yml`
  - Definir servicio web (Flask)
  - Definir servicio Redis
  - Configurar red entre servicios
  - Mapear puerto 8080

### 2. Kubernetes
- [ ] Crear manifiestos en la carpeta `k8s/`
  - Deployment para la aplicación Flask
  - Deployment para Redis
  - Service para exponer la aplicación
  - Service para Redis (interno)
  - Volumen persistente para Redis

Puedes elegir:
- Opción 1: Probar localmente con minikube/kind (recomendado)
- Opción 2: Solo entregar los manifiestos validados

### 3. Pipeline CI/CD
- [ ] Crear workflow de GitHub Actions 
  - Job 2: Build y Push
    * Login a DockerHub
    * Construir imagen
    * Publicar en DockerHub con tag apropiado

## Preparación
1. Fork este repositorio
2. Crear cuenta en DockerHub
3. Configurar secrets en GitHub:
   - `DOCKERHUB_USERNAME`: Tu usuario de DockerHub
   - `DOCKERHUB_TOKEN`: Token de acceso (NO tu contraseña)

## Entregables
1. Código en tu repositorio de GitHub con:
   - Dockerfile
   - docker-compose.yml
   - /k8s/manifests.yaml
   - /.github/workflows/ci-cd.yaml
   
2. URL de tu imagen en DockerHub

3. Screenshot o link mostrando:
   - Pipeline ejecutado exitosamente
   - Aplicación corriendo localmente

## Tiempo Estimado
2 horas

## Ayuda
- La aplicación usa el puerto 8080
- Redis debe ser accesible como 'redis' en la red
- Usa la variable REDIS_HOST para configurar la conexión# open-interview
