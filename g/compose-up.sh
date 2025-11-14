#!/usr/bin/env bash
#
# 02luka Docker Compose Deployment Script
# Intelligent deployment with prerequisite checks and validation
#
# Usage:
#   ./compose-up.sh                    # Deploy with checks
#   ./compose-up.sh --force            # Skip confirmations
#   ./compose-up.sh --check-only       # Only run checks, no deployment
#   ./compose-up.sh --help             # Show help
#

set -euo pipefail

# ==============================================
# Configuration
# ==============================================
COMPOSE_FILE="docker-compose.yml"
REQUIRED_DOCKER_VERSION="20.10"
REQUIRED_VOLUME="luka-ops_redis_data"
REQUIRED_IMAGE="02luka-node-services:latest"
APP_DIR="/Users/icmini/LocalProjects/02luka_local_g/g"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Flags
FORCE_MODE=false
CHECK_ONLY=false

# ==============================================
# Helper Functions
# ==============================================
log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*"; }
log_header() { echo -e "${MAGENTA}▶${NC} ${CYAN}$*${NC}"; }

print_banner() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════╗
║                                                      ║
║     ██████╗ ██████╗ ██╗     ██╗   ██╗██╗  ██╗ █████║
║    ██╔═████╗╚════██╗██║     ██║   ██║██║ ██╔╝██╔══█║
║    ██║██╔██║ █████╔╝██║     ██║   ██║█████╔╝ ██████║
║    ████╔╝██║██╔═══╝ ██║     ██║   ██║██╔═██╗ ██╔══█║
║    ╚██████╔╝███████╗███████╗╚██████╔╝██║  ██╗██║  █║
║     ╚═════╝ ╚══════╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚║
║                                                      ║
║         Docker Compose Deployment Script            ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)
                FORCE_MODE=true
                shift
                ;;
            --check-only)
                CHECK_ONLY=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    --force         Skip confirmations and deploy immediately
    --check-only    Only run prerequisite checks, don't deploy
    --help          Show this help message

Examples:
    $0                    # Interactive deployment
    $0 --force            # Deploy without prompts
    $0 --check-only       # Validate environment only

Prerequisites:
    - Docker 20.10+
    - docker-compose 1.29+
    - Volume: $REQUIRED_VOLUME
    - Image: $REQUIRED_IMAGE
    - App directory: $APP_DIR

EOF
}

# ==============================================
# Prerequisite Checks
# ==============================================
check_docker() {
    log_header "Checking Docker Installation"

    if ! command -v docker &> /dev/null; then
        log_error "Docker not found. Please install Docker Desktop."
        return 1
    fi

    local docker_version
    docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "0.0.0")
    log_success "Docker installed: v$docker_version"

    if ! docker info &> /dev/null; then
        log_error "Docker daemon not running. Please start Docker Desktop."
        return 1
    fi
    log_success "Docker daemon is running"

    return 0
}

check_docker_compose() {
    log_header "Checking Docker Compose"

    if ! command -v docker-compose &> /dev/null; then
        log_error "docker-compose not found. Please install docker-compose."
        return 1
    fi

    local compose_version
    compose_version=$(docker-compose version --short)
    log_success "docker-compose installed: v$compose_version"

    return 0
}

check_compose_file() {
    log_header "Checking Compose File"

    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "Compose file not found: $COMPOSE_FILE"
        log_info "Expected location: $(pwd)/$COMPOSE_FILE"
        return 1
    fi
    log_success "Compose file found: $COMPOSE_FILE"

    # Validate syntax
    if ! docker-compose -f "$COMPOSE_FILE" config --quiet; then
        log_error "Invalid compose file syntax"
        return 1
    fi
    log_success "Compose file syntax is valid"

    return 0
}

check_required_volume() {
    log_header "Checking Required Volume"

    if docker volume inspect "$REQUIRED_VOLUME" &> /dev/null; then
        log_success "Volume exists: $REQUIRED_VOLUME"
        return 0
    else
        log_warning "Volume not found: $REQUIRED_VOLUME"

        if [[ "$FORCE_MODE" == false ]]; then
            read -p "Create volume now? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_error "Volume required for deployment"
                return 1
            fi
        fi

        log_info "Creating volume: $REQUIRED_VOLUME"
        docker volume create "$REQUIRED_VOLUME"
        log_success "Volume created: $REQUIRED_VOLUME"
    fi

    return 0
}

check_required_image() {
    log_header "Checking Required Image"

    if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "$REQUIRED_IMAGE"; then
        log_success "Image exists: $REQUIRED_IMAGE"
        return 0
    else
        log_error "Image not found: $REQUIRED_IMAGE"
        log_info "Build the image first:"
        log_info "  docker build -t $REQUIRED_IMAGE ."
        log_info ""
        log_info "Or pull from registry:"
        log_info "  docker pull $REQUIRED_IMAGE"
        return 1
    fi
}

check_app_directory() {
    log_header "Checking Application Directory"

    if [[ ! -d "$APP_DIR" ]]; then
        log_error "Application directory not found: $APP_DIR"
        log_info "Update APP_DIR in this script or create the directory"
        return 1
    fi
    log_success "Application directory exists: $APP_DIR"

    # Check for required service files
    local required_files=(
        "tools/services/http_redis_bridge.cjs"
        "tools/services/redis_export_mode_listener.cjs"
        "tools/services/ops_health_watcher.cjs"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f "$APP_DIR/$file" ]]; then
            log_warning "Service file not found: $file"
        fi
    done

    return 0
}

check_network() {
    log_header "Checking Docker Network"

    if docker network inspect 02luka-net &> /dev/null; then
        log_warning "Network '02luka-net' already exists"
        log_info "Will be reused by docker-compose"
    else
        log_info "Network '02luka-net' will be created"
    fi

    return 0
}

check_ports() {
    log_header "Checking Port Availability"

    local ports=(6379 8788)
    local conflicts=()

    for port in "${ports[@]}"; do
        if lsof -i ":$port" &> /dev/null; then
            conflicts+=("$port")
            log_warning "Port $port is already in use"
        else
            log_success "Port $port is available"
        fi
    done

    if [[ ${#conflicts[@]} -gt 0 ]]; then
        log_warning "Port conflicts detected: ${conflicts[*]}"
        log_info "Existing containers will be stopped before deployment"
    fi

    return 0
}

# ==============================================
# Deployment Functions
# ==============================================
stop_existing_services() {
    log_header "Stopping Existing Services"

    local containers=(redis http_redis_bridge clc_listener ops_health_watcher)
    local stopped=0

    for container in "${containers[@]}"; do
        if docker ps -q -f name="^${container}$" &> /dev/null; then
            log_info "Stopping: $container"
            docker stop "$container" &> /dev/null || true
            ((stopped++))
        fi
    done

    if [[ $stopped -gt 0 ]]; then
        log_success "Stopped $stopped existing container(s)"
    else
        log_info "No existing containers to stop"
    fi

    return 0
}

deploy_services() {
    log_header "Deploying Services"

    log_info "Starting docker-compose deployment..."
    if docker-compose -f "$COMPOSE_FILE" up -d; then
        log_success "Services deployed successfully"
    else
        log_error "Deployment failed"
        return 1
    fi

    return 0
}

wait_for_health() {
    log_header "Waiting for Services to be Healthy"

    local max_wait=60
    local waited=0

    while [[ $waited -lt $max_wait ]]; do
        local healthy=true

        # Check Redis health
        if ! docker exec redis redis-cli ping &> /dev/null; then
            healthy=false
        fi

        if [[ "$healthy" == true ]]; then
            log_success "All services are healthy"
            return 0
        fi

        sleep 2
        ((waited += 2))
        echo -n "."
    done

    echo ""
    log_warning "Health check timeout after ${max_wait}s"
    log_info "Services may still be starting. Check logs:"
    log_info "  docker-compose logs -f"

    return 0
}

verify_deployment() {
    log_header "Verifying Deployment"

    echo ""
    log_info "Service Status:"
    docker-compose ps

    echo ""
    log_info "Quick Health Checks:"

    # Redis
    if docker exec redis redis-cli PING &> /dev/null; then
        log_success "Redis: PONG"
    else
        log_error "Redis: Not responding"
    fi

    # HTTP Bridge
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8788/health 2>&1 | grep -q "401\|200"; then
        log_success "HTTP Bridge: Accessible on :8788"
    else
        log_warning "HTTP Bridge: Check logs if needed"
    fi

    # Ops Health (public endpoint)
    if curl -s https://ops.theedges.work/ping 2>&1 | grep -q "ok"; then
        log_success "Ops Health: https://ops.theedges.work ✓"
    else
        log_warning "Ops Health: Check if health server is running"
    fi

    return 0
}

show_next_steps() {
    cat << EOF

${GREEN}═══════════════════════════════════════════════════════${NC}
${GREEN}    Deployment Complete! 🎉${NC}
${GREEN}═══════════════════════════════════════════════════════${NC}

${CYAN}Next Steps:${NC}

  1. View logs:
     ${YELLOW}docker-compose logs -f${NC}

  2. Check service status:
     ${YELLOW}docker-compose ps${NC}

  3. Run health checks:
     ${YELLOW}~/02luka/docker_services.sh health${NC}

  4. Access services:
     • Redis:       ${YELLOW}redis-cli -h localhost -p 6379${NC}
     • HTTP Bridge: ${YELLOW}http://localhost:8788${NC}
     • Ops Health:  ${YELLOW}https://ops.theedges.work${NC}

  5. Stop services:
     ${YELLOW}docker-compose down${NC}

${CYAN}Documentation:${NC}
  • Full Guide:  README.docker-compose.md
  • Quick Ref:   ~/02luka/DOCKER_QUICK_REF.md
  • Compose:     docker-compose.yml

${CYAN}Troubleshooting:${NC}
  • Logs:    ${YELLOW}docker-compose logs [service]${NC}
  • Shell:   ${YELLOW}docker-compose exec redis sh${NC}
  • Network: ${YELLOW}docker network inspect 02luka-net${NC}

${GREEN}═══════════════════════════════════════════════════════${NC}

EOF
}

# ==============================================
# Main Execution
# ==============================================
main() {
    print_banner
    echo ""

    # Parse arguments
    parse_args "$@"

    # Run all checks
    local checks_passed=true

    check_docker || checks_passed=false
    check_docker_compose || checks_passed=false
    check_compose_file || checks_passed=false
    check_required_volume || checks_passed=false
    check_required_image || checks_passed=false
    check_app_directory || checks_passed=false
    check_network || checks_passed=false
    check_ports || checks_passed=false

    echo ""

    if [[ "$checks_passed" == false ]]; then
        log_error "Prerequisite checks failed"
        log_info "Fix the issues above and try again"
        exit 1
    fi

    log_success "All prerequisite checks passed ✓"
    echo ""

    # Exit if check-only mode
    if [[ "$CHECK_ONLY" == true ]]; then
        log_info "Check-only mode: Exiting without deployment"
        exit 0
    fi

    # Confirm deployment
    if [[ "$FORCE_MODE" == false ]]; then
        echo ""
        read -p "$(echo -e "${CYAN}Deploy services now? (y/N)${NC} ")" -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deployment cancelled"
            exit 0
        fi
    fi

    # Deploy
    echo ""
    stop_existing_services
    deploy_services || exit 1
    wait_for_health
    verify_deployment

    # Show next steps
    echo ""
    show_next_steps

    exit 0
}

# Run main
main "$@"
