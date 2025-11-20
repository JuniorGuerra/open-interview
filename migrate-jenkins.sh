#!/bin/bash

################################################################################
# Script de Migración de Jenkins
# Uso: ./migrate-jenkins.sh [backup|restore]
################################################################################

set -e

JENKINS_HOME="${JENKINS_HOME:-/var/lib/jenkins}"
BACKUP_DIR="${BACKUP_DIR:-/tmp/jenkins-backup}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="jenkins-backup-${TIMESTAMP}.tar.gz"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root"
        exit 1
    fi
}

backup_jenkins() {
    log_info "Iniciando backup de Jenkins..."

    # Crear directorio de backup
    mkdir -p "$BACKUP_DIR"

    # Detener Jenkins
    log_info "Deteniendo Jenkins..."
    systemctl stop jenkins || service jenkins stop

    # Crear backup completo
    log_info "Creando backup en ${BACKUP_DIR}/${BACKUP_FILE}..."
    tar -czf "${BACKUP_DIR}/${BACKUP_FILE}" \
        --exclude='workspace/*' \
        --exclude='caches/*' \
        --exclude='war/*' \
        --exclude='*.log' \
        -C / var/lib/jenkins

    # Backup de configuración del sistema
    log_info "Guardando configuración del sistema..."
    cp /etc/default/jenkins "${BACKUP_DIR}/jenkins.default" 2>/dev/null || true
    cp /etc/sysconfig/jenkins "${BACKUP_DIR}/jenkins.sysconfig" 2>/dev/null || true

    # Guardar versión de Jenkins
    if [ -f "$JENKINS_HOME/config.xml" ]; then
        grep -oP '(?<=<version>)[^<]+' "$JENKINS_HOME/config.xml" > "${BACKUP_DIR}/jenkins.version" || true
    fi

    # Listar plugins instalados
    log_info "Guardando lista de plugins..."
    java -jar /usr/share/java/jenkins-cli.jar -s http://localhost:8080/ list-plugins > "${BACKUP_DIR}/plugins.txt" 2>/dev/null || \
    ls -1 "$JENKINS_HOME/plugins/" | grep -v '\.jpi\.pinned$' | sed 's/\.jpi$//' > "${BACKUP_DIR}/plugins.txt" || true

    # Reiniciar Jenkins
    log_info "Reiniciando Jenkins..."
    systemctl start jenkins || service jenkins start

    # Resumen
    log_info "========================================="
    log_info "Backup completado exitosamente!"
    log_info "Archivo: ${BACKUP_DIR}/${BACKUP_FILE}"
    log_info "Tamaño: $(du -h ${BACKUP_DIR}/${BACKUP_FILE} | cut -f1)"
    log_info "========================================="

    echo ""
    log_info "Para copiar al nuevo servidor ejecuta:"
    echo "scp ${BACKUP_DIR}/${BACKUP_FILE} user@nuevo-servidor:/tmp/"
}

restore_jenkins() {
    log_info "Iniciando restauración de Jenkins..."

    # Buscar archivo de backup más reciente
    LATEST_BACKUP=$(ls -t ${BACKUP_DIR}/jenkins-backup-*.tar.gz 2>/dev/null | head -1)

    if [ -z "$LATEST_BACKUP" ]; then
        log_error "No se encontró ningún backup en ${BACKUP_DIR}"
        exit 1
    fi

    log_warn "Se restaurará desde: ${LATEST_BACKUP}"
    read -p "¿Continuar? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Restauración cancelada"
        exit 0
    fi

    # Detener Jenkins
    log_info "Deteniendo Jenkins..."
    systemctl stop jenkins || service jenkins stop

    # Crear backup del estado actual (por seguridad)
    if [ -d "$JENKINS_HOME" ]; then
        log_info "Creando backup del estado actual..."
        mv "$JENKINS_HOME" "${JENKINS_HOME}.pre-restore.$(date +%s)"
    fi

    # Restaurar backup
    log_info "Restaurando Jenkins desde backup..."
    mkdir -p "$JENKINS_HOME"
    tar -xzf "$LATEST_BACKUP" -C /

    # Restaurar permisos
    log_info "Restaurando permisos..."
    chown -R jenkins:jenkins "$JENKINS_HOME"

    # Reiniciar Jenkins
    log_info "Reiniciando Jenkins..."
    systemctl start jenkins || service jenkins start

    # Esperar a que Jenkins esté listo
    log_info "Esperando a que Jenkins inicie..."
    for i in {1..30}; do
        if curl -s http://localhost:8080/login >/dev/null 2>&1; then
            log_info "Jenkins está listo!"
            break
        fi
        echo -n "."
        sleep 2
    done
    echo ""

    log_info "========================================="
    log_info "Restauración completada!"
    log_info "Accede a: http://localhost:8080"
    log_info "========================================="
}

install_jenkins() {
    log_info "Instalando Jenkins en servidor nuevo..."

    # Detectar sistema operativo
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        log_info "Sistema: Debian/Ubuntu"

        wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | apt-key add -
        echo "deb https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list
        apt-get update
        apt-get install -y fontconfig openjdk-17-jre jenkins

    elif [ -f /etc/redhat-release ]; then
        # RHEL/CentOS
        log_info "Sistema: RHEL/CentOS"

        wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
        rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
        yum install -y fontconfig java-17-openjdk jenkins

    else
        log_error "Sistema operativo no soportado"
        exit 1
    fi

    # Habilitar y arrancar Jenkins
    systemctl enable jenkins
    systemctl start jenkins

    log_info "Jenkins instalado. Ejecuta './migrate-jenkins.sh restore' para restaurar datos"
}

show_status() {
    log_info "Estado de Jenkins:"
    systemctl status jenkins --no-pager || service jenkins status

    echo ""
    log_info "Ubicación de datos:"
    echo "JENKINS_HOME: $JENKINS_HOME"
    echo "Tamaño: $(du -sh $JENKINS_HOME 2>/dev/null | cut -f1 || echo 'N/A')"

    echo ""
    log_info "Backups disponibles:"
    ls -lh ${BACKUP_DIR}/jenkins-backup-*.tar.gz 2>/dev/null || echo "No hay backups"
}

show_usage() {
    cat <<EOF
Uso: $0 [comando]

Comandos:
  backup      - Crear backup completo de Jenkins
  restore     - Restaurar Jenkins desde backup más reciente
  install     - Instalar Jenkins en servidor nuevo
  status      - Mostrar estado y estadísticas
  help        - Mostrar esta ayuda

Variables de entorno:
  JENKINS_HOME    - Directorio de Jenkins (default: /var/lib/jenkins)
  BACKUP_DIR      - Directorio de backups (default: /tmp/jenkins-backup)

Ejemplos:
  # En servidor viejo
  sudo ./migrate-jenkins.sh backup
  scp /tmp/jenkins-backup/jenkins-backup-*.tar.gz user@nuevo:/tmp/jenkins-backup/

  # En servidor nuevo
  sudo ./migrate-jenkins.sh install
  sudo ./migrate-jenkins.sh restore

EOF
}

# Main
case "${1:-}" in
    backup)
        check_root
        backup_jenkins
        ;;
    restore)
        check_root
        restore_jenkins
        ;;
    install)
        check_root
        install_jenkins
        ;;
    status)
        show_status
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        log_error "Comando inválido: ${1:-}"
        echo ""
        show_usage
        exit 1
        ;;
esac
