#!/bin/bash

# ============================================================
# N8N Management Script with Cloudflare Tunnel Integration
# ============================================================
# Requirements:
#   - Ubuntu/Debian-based Linux (uses apt, dpkg
#   - Root/sudo access
#   - Internet connection
#   - Cloudflare account with Zero Trust access
# ============================================================

# === Shell Compatibility Check ===
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script requires Bash. Please run with: bash $0" >&2
    exit 1
fi

# === Check if running as root ===
if [ "$(id -u" -ne 0 ]; then
   echo "This script must be run as root. Please use 'sudo bash $0'" >&2
   exit 1
fi

# === Determine the real user and home directory ===
# When running with sudo, $HOME points to root's home (/root
# We need to use the original user's home directory
REAL_USER="${SUDO_USER:-$(whoami}"
REAL_HOME=$(eval echo "~$REAL_USER"

# === Configuration ===
# N8N Data Directory (using real user's home, not root's
N8N_BASE_DIR="$REAL_HOME/n8n"
N8N_VOLUME_DIR="$N8N_BASE_DIR/n8n_data"
DOCKER_COMPOSE_FILE="$N8N_BASE_DIR/docker-compose.yml"
# Cloudflared config file path
CLOUDFLARED_CONFIG_FILE="/etc/cloudflared/config.yml"
# Default Timezone if system TZ is not set
DEFAULT_TZ="Asia/Ho_Chi_Minh"

# Backup configuration
BACKUP_DIR="$REAL_HOME/n8n-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S

# Config file for installation settings
CONFIG_FILE="$REAL_HOME/.n8n_install_config"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# === Script Execution ===
# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# Prevent errors in a pipeline from being masked.
set -o pipefail

# === Helper Functions ===
print_section( {
    echo -e "${BLUE}>>> $1${NC}"
}

print_success( {
    echo -e "${GREEN} $1${NC}"
}

print_warning( {
    echo -e "${YELLOW} $1${NC}"
}

print_error( {
    echo -e "${RED} $1${NC}"
}

# === Config Management Functions ===
save_config( {
    local cf_token="$1"
    local cf_hostname="$2"
    local tunnel_id="$3"
    local account_tag="$4"
    local tunnel_secret="$5"
    
    cat > "$CONFIG_FILE" << EOF
# N8N Installation Configuration
# Generated on: $(date
CF_TOKEN="$cf_token"
CF_HOSTNAME="$cf_hostname"
TUNNEL_ID="$tunnel_id"
ACCOUNT_TAG="$account_tag"
TUNNEL_SECRET="$tunnel_secret"
INSTALL_DATE="$(date"
EOF
    
    chmod 600 "$CONFIG_FILE"  # Bo mt file config
    print_success "Config  c lu ti: $CONFIG_FILE"
}

load_config( {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        return 0
    else
        return 1
    fi
}

show_config_info( {
    if load_config; then
        echo -e "${BLUE} Thng tin config hin c:${NC}"
        echo "   Hostname: $CF_HOSTNAME"
        echo "   Tunnel ID: $TUNNEL_ID"
        echo "   Ngy ci t: $INSTALL_DATE"
        echo ""
        return 0
    else
        return 1
    fi
}

get_cloudflare_info( {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}    HNG DN LY THNG TIN CLOUDFLARE${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
    echo "  ly Cloudflare Tunnel Token v thng tin:"
    echo ""
    echo "1 Truy cp Cloudflare Zero Trust Dashboard:"
    echo "    https://one.dash.cloudflare.com/"
    echo ""
    echo "2 ng nhp v chn 'Access' > 'Tunnels'"
    echo ""
    echo "3 To tunnel mi hoc chn tunnel c sn:"
    echo "    Click 'Create a tunnel'"
    echo "    Chn 'Cloudflared' connector"
    echo "    t tn tunnel - v d: n8n-tunnel"
    echo ""
    echo "4 Ly thng tin cn thit:"
    echo "    Token: Trong phn 'Install and run a connector'"
    echo "    Hostname: Domain bn mun s dng - v d: n8n.yourdomain.com"
    echo ""
    echo "5 Cu hnh DNS:"
    echo "    Trong Cloudflare DNS, to CNAME record"
    echo "    Name: subdomain ca bn - v d: n8n"
    echo "    Target: [tunnel-id].cfargotunnel.com"
    echo ""
    echo " Lu :"
    echo "    Domain phi c qun l bi Cloudflare"
    echo "    Token c dng: eyJhIjoiXXXXXX..."
    echo "    Hostname c dng: n8n.yourdomain.com"
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

get_new_config( {
    echo ""
    read -p " Bn mun s dng Cloudflare Tunnel khng? (y/N: " use_cloudflare
    
    if [ "$use_cloudflare" != "y" ] && [ "$use_cloudflare" != "Y" ]; then
        # Local mode - khng cn Cloudflare
        print_success "Ch  Local c chn"
        echo ""
        echo " Thng tin cu hnh Local Mode:"
        echo "   N8N s chy ti: http://localhost:5678"
        echo "   Ch c th truy cp t my local"
        echo "   Khng cn token Cloudflare"
        echo "   Khng cn cu hnh DNS"
        echo ""
        
        CF_TOKEN="local"
        CF_HOSTNAME="localhost"
        TUNNEL_ID="local"
        ACCOUNT_TAG="local"
        TUNNEL_SECRET="local"
        
        save_config "$CF_TOKEN" "$CF_HOSTNAME" "$TUNNEL_ID" "$ACCOUNT_TAG" "$TUNNEL_SECRET"
        print_success "Config Local Mode  c lu"
        return 0
    fi
    
    # Cloudflare mode
    read -p " Bn c cn xem hng dn ly thng tin Cloudflare khng? (y/N: " show_guide
    
    if [ "$show_guide" = "y" ] || [ "$show_guide" = "Y" ]; then
        get_cloudflare_info
        read -p "Nhn Enter  tip tc sau khi  chun b thng tin..."
    fi
    
    echo ""
    echo " Nhp thng tin Cloudflare Tunnel:"
    echo ""
    
    # Ly Cloudflare Token
    while true; do
        read -p " Nhp Cloudflare Tunnel Token (hoc dng lnh cloudflared: " CF_TOKEN
        if [ -z "$CF_TOKEN" ]; then
            print_error "Token khng c  trng!"
            continue
        fi
        
        # X l nu user paste ton b dng lnh: cloudflared.exe service install TOKEN
        # Hoc: cloudflared service install TOKEN
        if [[ "$CF_TOKEN" =~ cloudflared ]]; then
            # Trch xut token t dng lnh
            CF_TOKEN=$(echo "$CF_TOKEN" | grep -oP 'service install \K.*' | tr -d ' '
            if [ -z "$CF_TOKEN" ]; then
                print_error "Khng th trch xut token t dng lnh. Vui lng paste li!"
                continue
            fi
        fi
        
        # Kim tra format token (JWT format hoc payload
        # Chp nhn c token y  (3 phn hoc payload (1 phn
        if [[ "$CF_TOKEN" =~ ^eyJ[A-Za-z0-9_-]+ ]]; then
            print_success "Token hp l"
            break
        else
            print_error "Token phi bt u bng 'eyJ'. Vui lng kim tra li!"
            continue
        fi
    done
    
    # Ly Hostname
    while true; do
        read -p " Nhp Public Hostname - v d: n8n.yourdomain.com: " CF_HOSTNAME
        if [ -z "$CF_HOSTNAME" ]; then
            print_error "Hostname khng c  trng!"
            continue
        fi
        
        # Kim tra format hostname
        if [[ "$CF_HOSTNAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
            print_success "Hostname hp l"
            break
        else
            print_warning "Hostname c v khng ng format. Bn c chc chn mun tip tc? (y/N"
            read -p "" confirm_hostname
            if [ "$confirm_hostname" = "y" ] || [ "$confirm_hostname" = "Y" ]; then
                break
            fi
        fi
    done
    
    # Decode token  ly thng tin tunnel (nu c th
    echo ""
    echo " ang phn tch token..."
    
    # S dng hm helper  decode token
    decode_token_info "$CF_TOKEN"
    
    if [ -n "$TUNNEL_ID" ]; then
        print_success " phn tch c thng tin t token:"
        echo "   Tunnel ID: $TUNNEL_ID"
        echo "   Account Tag: $ACCOUNT_TAG"
    else
        print_warning "Khng th phn tch token, s s dng thng tin mc nh"
        TUNNEL_ID="unknown"
        ACCOUNT_TAG="unknown"
        TUNNEL_SECRET="unknown"
    fi
    
    # Lu config
    save_config "$CF_TOKEN" "$CF_HOSTNAME" "$TUNNEL_ID" "$ACCOUNT_TAG" "$TUNNEL_SECRET"
}

manage_config( {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}    QUN L CONFIG CLOUDFLARE${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
    
    if show_config_info; then
        echo "Chn hnh ng:"
        echo "1.  Xem chi tit config"
        echo "2.  Chnh sa config"
        echo "3.  Xa config"
        echo "4.  To config mi"
        echo "0.  Quay li"
        echo ""
        read -p "Nhp la chn [0-4]: " config_choice
        
        case $config_choice in
            1
                show_detailed_config
                ;;
            2
                edit_config
                ;;
            3
                delete_config
                ;;
            4
                get_new_config
                ;;
            0
                return 0
                ;;
            *
                print_error "La chn khng hp l!"
                ;;
        esac
    else
        echo " Cha c config no c lu."
        echo ""
        read -p "Bn c mun to config mi khng? (y/N: " create_new
        if [ "$create_new" = "y" ] || [ "$create_new" = "Y" ]; then
            get_new_config
        fi
    fi
}

show_detailed_config( {
    if load_config; then
        echo -e "${BLUE} Chi tit config:${NC}"
        echo ""
        echo " Hostname: $CF_HOSTNAME"
        echo " Tunnel ID: $TUNNEL_ID"
        echo " Account Tag: $ACCOUNT_TAG"
        echo " Token: ${CF_TOKEN:0:20}...${CF_TOKEN: -10}"
        echo " Ngy ci t: $INSTALL_DATE"
        echo ""
        echo " File config: $CONFIG_FILE"
        echo ""
    else
        print_error "Khng th c config!"
    fi
}

decode_token_info( {
    local token="$1"
    local tunnel_id=""
    local account_tag=""
    local tunnel_secret=""
    
    # Decode JWT payload
    if command -v base64 >/dev/null 2>&1; then
        # Xc nh payload: nu c du chm th ly phn th 2, nu khng th ly ton b
        if [[ "$token" == *"."* ]]; then
            TOKEN_PAYLOAD=$(echo "$token" | cut -d'.' -f2
        else
            # Token ch c payload (khng c header v signature
            TOKEN_PAYLOAD="$token"
        fi
        
        # Thm padding nu cn
        case $((${#TOKEN_PAYLOAD} % 4 in
            2 TOKEN_PAYLOAD="${TOKEN_PAYLOAD}==" ;;
            3 TOKEN_PAYLOAD="${TOKEN_PAYLOAD}=" ;;
        esac
        
        DECODED=$(echo "$TOKEN_PAYLOAD" | base64 -d 2>/dev/null || echo ""
        if [ -n "$DECODED" ]; then
            tunnel_id=$(echo "$DECODED" | grep -o '"t":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo ""
            account_tag=$(echo "$DECODED" | grep -o '"a":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo ""
            tunnel_secret=$(echo "$DECODED" | grep -o '"s":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo ""
        fi
    fi
    
    # Return values via global variables
    TUNNEL_ID="$tunnel_id"
    ACCOUNT_TAG="$account_tag"
    TUNNEL_SECRET="$tunnel_secret"
}

edit_config( {
    echo " Chnh sa config:"
    echo ""
    
    if load_config; then
        echo "Config hin ti:"
        echo "   Hostname: $CF_HOSTNAME"
        
        # Kim tra xem c phi local mode khng
        if [ "$CF_HOSTNAME" = "localhost" ]; then
            echo "   Mode: Local (khng cn Cloudflare"
            echo ""
            print_warning "  Bn ang  ch  Local Mode"
            echo " chuyn sang Cloudflare Mode, vui lng to config mi"
            echo ""
            return 0
        fi
        
        echo "   Token: ${CF_TOKEN:0:20}...${CF_TOKEN: -10}"
        echo ""
        
        read -p "Nhp hostname mi (Enter  gi nguyn: " new_hostname
        read -p "Nhp token mi (Enter  gi nguyn: " new_token
        
        if [ -n "$new_hostname" ]; then
            CF_HOSTNAME="$new_hostname"
        fi
        
        if [ -n "$new_token" ]; then
            CF_TOKEN="$new_token"
            # !!! FIX: Gi li logic gii m token  cp nht thng tin
            echo " Phn tch token mi..."
            decode_token_info "$CF_TOKEN"
            if [ -n "$TUNNEL_ID" ]; then
                print_success " phn tch li token mi:"
                echo "   Tunnel ID: $TUNNEL_ID"
                echo "   Account Tag: $ACCOUNT_TAG"
            else
                print_warning "Khng th phn tch token mi, s s dng thng tin c"
            fi
        fi
        
        save_config "$CF_TOKEN" "$CF_HOSTNAME" "$TUNNEL_ID" "$ACCOUNT_TAG" "$TUNNEL_SECRET"
        print_success "Config  c cp nht!"
    else
        print_error "Khng th c config hin ti!"
    fi
}

delete_config( {
    echo " Xa config:"
    echo ""
    
    if [ -f "$CONFIG_FILE" ]; then
        show_config_info
        echo ""
        read -p " Bn c chc chn mun xa config ny khng? (y/N: " confirm_delete
        
        if [ "$confirm_delete" = "y" ] || [ "$confirm_delete" = "Y" ]; then
            rm -f "$CONFIG_FILE"
            print_success "Config  c xa!"
        else
            echo "Hy xa config"
        fi
    else
        print_warning "Khng c config no  xa"
    fi
}

# === Utility Functions ===
check_disk_space( {
    local required_space_mb="$1"
    local target_dir="$2"
    
    # Ly dung lng trng (KB v chuyn sang MB
    local available_kb=$(df "$target_dir" | awk 'NR==2 {print $4}'
    local available_mb=$((available_kb / 1024
    
    if [ $available_mb -lt $required_space_mb ]; then
        print_error "Khng  dung lng! Cn: ${required_space_mb}MB, C: ${available_mb}MB"
        return 1
    else
        print_success "Dung lng : ${available_mb}MB kh dng"
        return 0
    fi
}

validate_encryption_key( {
    local key="$1"
    
    # Kim tra key khng rng
    if [ -z "$key" ]; then
        print_error "Encryption key khng c  trng!"
        return 1
    fi
    
    # Kim tra  di ti thiu (base64 ca 32 bytes = ~44 chars
    if [ ${#key} -lt 32 ]; then
        print_error "Encryption key qu ngn! Cn t nht 32 k t"
        return 1
    fi
    
    # Kim tra format base64 (optional - v c th dng plain text
    if echo "$key" | base64 -d >/dev/null 2>&1; then
        print_success "Encryption key hp l (Base64 format"
    else
        print_warning "Encryption key khng phi Base64, nhng vn c th s dng"
    fi
    
    return 0
}

# === Enhanced Utility Functions ===

check_container_health( {
    local container_name="$1"
    local max_wait="${2:-60}"
    local wait_time=0
    
    print_section "Kim tra sc khe container: $container_name"
    
    while [ $wait_time -lt $max_wait ]; do
        local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-healthcheck"
        
        case "$health_status" in
            "healthy"
                print_success "Container $container_name ang khe mnh"
                return 0
                ;;
            "unhealthy"
                print_error "Container $container_name khng khe mnh"
                return 1
                ;;
            "starting"
                echo " Container ang khi ng... ($wait_time/${max_wait}s"
                ;;
            "no-healthcheck"
                # Fallback: kim tra container c ang chy khng
                if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
                    print_success "Container $container_name ang chy (khng c healthcheck"
                    return 0
                else
                    print_error "Container $container_name khng chy"
                    return 1
                fi
                ;;
        esac
        
        sleep 5
        wait_time=$((wait_time + 5
    done
    
    print_warning "Timeout khi kim tra container health"
    return 1
}

backup_encryption_key( {
    local backup_location="$1"
    
    if [ -f "$N8N_ENCRYPTION_KEY_FILE" ]; then
        cp "$N8N_ENCRYPTION_KEY_FILE" "$backup_location/n8n_encryption_key_backup"
        chmod 600 "$backup_location/n8n_encryption_key_backup"
        print_success " backup encryption key"
    else
        print_warning "Khng tm thy encryption key file  backup"
    fi
}

cleanup_old_backups( {
    print_section "Dn dp backup c"
    
    if [ -d "$BACKUP_DIR" ]; then
        BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l
        
        # Gi li 10 backup gn nht
        if [ $BACKUP_COUNT -gt 10 ]; then
            echo " Tm thy $BACKUP_COUNT backup, gi li 10 backup gn nht..."
            
            # Tnh ton dung lng s c gii phng
            local space_to_free=0
            ls -t "$BACKUP_DIR"/*.tar.gz | tail -n +11 | while read old_backup; do
                local file_size=$(du -m "$old_backup" 2>/dev/null | cut -f1
                space_to_free=$((space_to_free + file_size
                echo "   Xa: $(basename "$old_backup" (${file_size}MB"
                rm -f "$old_backup"
                # Xa file info tng ng
                info_file="${old_backup%.tar.gz}.info"
                [ -f "$info_file" ] && rm -f "$info_file"
            done
            
            print_success " dn dp backup c, gii phng ~${space_to_free}MB"
        else
            echo " S lng backup ($BACKUP_COUNT trong gii hn cho php"
        fi
    fi
    echo ""
}

get_latest_version( {
    # Ci thin cch ly phin bn mi nht
    echo " ang kim tra phin bn mi nht..."
    
    # Th nhiu cch  ly version
    LATEST_VERSION=""
    
    # Cch 1: Docker Hub API
    if [ -z "$LATEST_VERSION" ]; then
        LATEST_VERSION=$(curl -s "https://registry.hub.docker.com/v2/repositories/n8nio/n8n/tags/?page_size=100" | \
            grep -o '"name":"[0-9][^"]*"' | grep -v "latest\|beta\|alpha\|rc\|exp" | head -1 | cut -d'"' -f4 2>/dev/null || echo ""
    fi
    
    # Cch 2: GitHub API
    if [ -z "$LATEST_VERSION" ]; then
        LATEST_VERSION=$(curl -s "https://api.github.com/repos/n8n-io/n8n/releases/latest" | \
            grep '"tag_name":' | cut -d'"' -f4 | sed 's/^n8n@//' 2>/dev/null || echo ""
    fi
    
    # Fallback
    if [ -z "$LATEST_VERSION" ]; then
        LATEST_VERSION="latest"
    fi
    
    echo "$LATEST_VERSION"
}

health_check( {
    print_section "Kim tra sc khe N8N"
    
    local max_attempts=6
    local attempt=1
    
    # Load config  bit mode hin ti
    if ! load_config; then
        print_warning "Khng th c config, s kim tra container..."
    fi
    
    while [ $attempt -le $max_attempts ]; do
        echo " Th kt ni ln $attempt/$max_attempts..."
        
        # Kim tra container ang chy
        if ! docker compose -f "$DOCKER_COMPOSE_FILE" ps | grep -q "Up"; then
            print_error "Container khng chy!"
            return 1
        fi
        
        # Kim tra port 5678
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:5678 | grep -q "200\|302\|401"; then
            print_success "N8N service ang hot ng bnh thng"
            
            # Hin th URL da trn mode
            if [ "$CF_HOSTNAME" = "localhost" ]; then
                print_success " Truy cp (Local Mode: http://localhost:5678"
            else
                print_success " Truy cp (Cloudflare Mode: https://$CF_HOSTNAME"
            fi
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            echo " i 10 giy trc khi th li..."
            sleep 10
        fi
        
        attempt=$((attempt + 1
    done
    
    print_warning "N8N service c th cha sn sng hoc c vn "
    echo " Container logs (20 dng cui:"
    docker compose -f "$DOCKER_COMPOSE_FILE" logs --tail=20
    return 1
}

rollback_backup( {
    print_section "Rollback t backup"
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR"/*.tar.gz 2>/dev/null" ]; then
        print_error "Khng tm thy backup no  rollback!"
        return 1
    fi
    
    echo " Danh sch backup kh dng:"
    ls -lah "$BACKUP_DIR"/*.tar.gz | nl
    echo ""
    
    read -p "Nhp s th t backup mun rollback (hoc Enter  hy: " backup_choice
    
    if [ -z "$backup_choice" ]; then
        echo "Hy rollback"
        return 0
    fi
    
    SELECTED_BACKUP=$(ls -t "$BACKUP_DIR"/*.tar.gz | sed -n "${backup_choice}p"
    
    if [ -z "$SELECTED_BACKUP" ] || [ ! -f "$SELECTED_BACKUP" ]; then
        print_error "Backup khng hp l!"
        return 1
    fi
    
    echo " Rollback t: $(basename "$SELECTED_BACKUP""
    echo ""
    print_warning "  CNH BO: Rollback d liu t mt phin bn n8n c c th gy ra vn  tng thch"
    print_warning "vi phin bn container hin ti. C s d liu c th cn c di chuyn (migrate."
    print_warning "Hy chc chn rng bn hiu r ri ro trc khi tip tc."
    echo ""
    read -p "Bn c chc chn mun rollback? (y/N: " confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Hy rollback"
        return 0
    fi
    
    # Dng container hin ti
    print_warning "Dng N8N container..."
    docker compose -f "$DOCKER_COMPOSE_FILE" down
    
    # Backup trng thi hin ti trc khi rollback
    ROLLBACK_BACKUP="n8n_before_rollback_$(date +%Y%m%d_%H%M%S.tar.gz"
    echo " To backup trng thi hin ti: $ROLLBACK_BACKUP"
    tar -czf "$BACKUP_DIR/$ROLLBACK_BACKUP" -C "$(dirname "$N8N_BASE_DIR"" "$(basename "$N8N_BASE_DIR"" 2>/dev/null || true
    
    # Restore t backup
    echo " Restore t backup..."
    cd "$(dirname "$N8N_BASE_DIR""
    tar -xzf "$SELECTED_BACKUP"
    
    # Khi ng li
    echo " Khi ng N8N..."
    docker compose -f "$DOCKER_COMPOSE_FILE" up -d
    
    sleep 15
    
    if health_check; then
        print_success "Rollback thnh cng!"
        print_success "Backup trng thi trc rollback: $ROLLBACK_BACKUP"
    else
        print_error "C vn  sau rollback, hy kim tra logs"
        return 1
    fi
}

# === Backup & Update Functions ===
check_current_version( {
    print_section "Kim tra phin bn hin ti"
    
    if [ -f "$DOCKER_COMPOSE_FILE" ] && docker compose -f "$DOCKER_COMPOSE_FILE" ps | grep -q "Up"; then
        CURRENT_VERSION=$(docker compose -f "$DOCKER_COMPOSE_FILE" exec -T n8n n8n --version 2>/dev/null || echo "Unknown"
        print_success "Phin bn hin ti: $CURRENT_VERSION"
        
        # Kim tra phin bn mi nht
        print_section "Kim tra phin bn mi nht"
        LATEST_VERSION=$(get_latest_version
        print_success "Tm thy phin bn mi nht: $LATEST_VERSION"
        
        if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ] && [ "$LATEST_VERSION" != "latest" ]; then
            print_warning "C phin bn mi kh dng!"
        else
            print_success "Bn ang s dng phin bn mi nht"
        fi
    else
        print_warning "N8N cha c ci t hoc khng chy"
        CURRENT_VERSION="Not installed"
    fi
    echo ""
}

show_server_status( {
    print_section "Trng thi server"
    echo -e "${YELLOW}Thi gian: $(date${NC}"
    
    echo "System Info:"
    echo "  - Uptime: $(uptime -p"
    echo "  - Load: $(uptime | awk -F'load average:' '{print $2}'"
    echo "  - Memory: $(free -h | awk 'NR==2{printf "%.1f%% (%s/%s", $3*100/$2, $3, $2}'"
    echo "  - Disk: $(df -h / | awk 'NR==2{printf "%s (%s used", $5, $3}'"
    echo ""
    
    if [ -f "$DOCKER_COMPOSE_FILE" ]; then
        echo "N8N Container Status:"
        docker compose -f "$DOCKER_COMPOSE_FILE" ps
        echo ""
        
        echo "Cloudflared Service Status:"
        systemctl status cloudflared --no-pager -l | head -5
    fi
    echo ""
}

count_backups( {
    print_section "Thng bo  backup bao nhiu bn v m t chi tit"
    
    if [ -d "$BACKUP_DIR" ]; then
        BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l
        TOTAL_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1
        
        echo " S lng backup hin c: $BACKUP_COUNT bn"
        echo " Tng dung lng backup: $TOTAL_SIZE"
        echo ""
        
        if [ $BACKUP_COUNT -gt 0 ]; then
            echo " Danh sch backup gn y:"
            ls -lah "$BACKUP_DIR"/*.tar.gz 2>/dev/null | tail -5 | while read line; do
                echo "  $line"
            done
            echo ""
            
            echo " Chi tit ni dung backup:"
            echo "   N8N workflows v database (SQLite"
            echo "   N8N settings v configurations"
            echo "   Custom nodes v packages"
            echo "   Cloudflared tunnel configurations"
            echo "   Docker compose files"
            echo "   Local files v uploads"
            echo "   Environment variables"
            echo "   Management scripts"
        else
            echo " Cha c backup no c to"
        fi
    else
        echo " Th mc backup cha tn ti"
    fi
    echo ""
}

create_backup( {
    print_section "Backup ti $(date"
    
    # To th mc backup nu cha c
    mkdir -p "$BACKUP_DIR"
    
    BACKUP_FILE="n8n_backup_${TIMESTAMP}.tar.gz"
    echo " Backup file: $BACKUP_FILE"
    echo " Thi gian backup: $(date"
    
    # Dng container  backup an ton
    if [ -f "$DOCKER_COMPOSE_FILE" ]; then
        print_warning "Dng N8N container  backup an ton..."
        docker compose -f "$DOCKER_COMPOSE_FILE" down
    fi
    
    # To backup chi tit
    echo ""
    echo " ang backup cc thnh phn:"
    echo "   N8N data directory: $N8N_BASE_DIR"
    echo "   Cloudflared config: /etc/cloudflared/"
    echo "   Scripts v configs"
    echo "   Local files v uploads"
    
    # Backup ton b
    tar -czf "$BACKUP_DIR/$BACKUP_FILE" \
        -C "$(dirname "$N8N_BASE_DIR"" "$(basename "$N8N_BASE_DIR"" \
        -C /etc cloudflared/ \
        -C "$(dirname "$0"" "$(basename "$0"" \
        2>/dev/null || true
    
    BACKUP_SIZE=$(du -sh "$BACKUP_DIR/$BACKUP_FILE" | cut -f1
    print_success "Backup hon thnh: $BACKUP_DIR/$BACKUP_FILE ($BACKUP_SIZE"
    
    # Cp nht thng k backup
    BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l
    echo " Tng s backup: $BACKUP_COUNT bn"
    
    # Dn dp backup c nu cn
    cleanup_old_backups
    
    # To file m t backup
    cat > "$BACKUP_DIR/backup_${TIMESTAMP}.info" << EOF
N8N Backup Information
======================
Timestamp: $(date
Backup File: $BACKUP_FILE
Size: $BACKUP_SIZE
N8N Version: ${CURRENT_VERSION:-Unknown}
Server IP: $(hostname -I | awk '{print $1}'
Hostname: $(hostname

Backup Contents:
================
 N8N workflows v database (SQLite
 N8N user settings v preferences  
 Custom nodes v installed packages
 Cloudflared tunnel configurations
 Docker compose files
 Local files v file uploads
 Environment variables
 SSL certificates (if any
 Management scripts

Restore Instructions:
====================
1. Stop current N8N: docker compose -f $DOCKER_COMPOSE_FILE down
2. Extract backup: cd $(dirname "$N8N_BASE_DIR" && tar -xzf $BACKUP_DIR/$BACKUP_FILE
3. Start N8N: docker compose -f $DOCKER_COMPOSE_FILE up -d

System Info at Backup:
======================
Uptime: $(uptime -p
Load: $(uptime | awk -F'load average:' '{print $2}'
Memory: $(free -h | awk 'NR==2{printf "%.1f%% (%s/%s", $3*100/$2, $3, $2}'
Disk: $(df -h / | awk 'NR==2{printf "%s (%s used", $5, $3}'
EOF
    
    print_success "Thng tin backup  lu: backup_${TIMESTAMP}.info"
    echo ""
}

update_n8n( {
    print_section "Cp nht N8N ln phin bn mi nht"
    
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        print_error "N8N cha c ci t!"
        return 1
    fi
    
    echo " ang pull image mi nht t Docker Hub..."
    docker compose -f "$DOCKER_COMPOSE_FILE" pull
    
    echo " Khi ng li vi phin bn mi..."
    docker compose -f "$DOCKER_COMPOSE_FILE" up -d
    
    echo " i container khi ng (15 giy..."
    sleep 15
    
    # Kim tra trng thi
    if docker compose -f "$DOCKER_COMPOSE_FILE" ps | grep -q "Up"; then
        NEW_VERSION=$(docker compose -f "$DOCKER_COMPOSE_FILE" exec -T n8n n8n --version 2>/dev/null || echo "Unknown"
        print_success "Update thnh cng!"
        print_success "Phin bn mi: $NEW_VERSION"
        
        echo ""
        echo " Container status:"
        docker compose -f "$DOCKER_COMPOSE_FILE" ps
        
        # Kim tra service health
        health_check
    else
        print_error "C li khi khi ng container!"
        echo " Container logs:"
        docker compose -f "$DOCKER_COMPOSE_FILE" logs --tail=20
        return 1
    fi
    echo ""
}

backup_and_update( {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}    N8N BACKUP & UPDATE PROCESS${NC}"
    echo -e "${BLUE}================================================${NC}"
    
    check_current_version
    show_server_status
    count_backups
    create_backup
    update_n8n
    
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}    BACKUP & UPDATE HON THNH${NC}"
    echo -e "${GREEN}================================================${NC}"
    print_success "Backup: $BACKUP_DIR/n8n_backup_${TIMESTAMP}.tar.gz"
    print_success "N8N  c cp nht v ang chy"
    print_success "Truy cp: https://${CF_HOSTNAME:-localhost:5678}"
}

# === Uninstall Functions ===
create_manifest( {
    local manifest_file="$N8N_BASE_DIR/.n8n_manifest"
    
    cat > "$manifest_file" << EOF
# N8N Installation Manifest
# Generated on: $(date
# This file tracks what was installed for uninstall purposes

INSTALL_DATE="$(date"
N8N_BASE_DIR="$N8N_BASE_DIR"
N8N_VOLUME_DIR="$N8N_VOLUME_DIR"
BACKUP_DIR="$BACKUP_DIR"
CONFIG_FILE="$CONFIG_FILE"
DOCKER_COMPOSE_FILE="$DOCKER_COMPOSE_FILE"
CLOUDFLARED_CONFIG_FILE="$CLOUDFLARED_CONFIG_FILE"

# Installed components
DOCKER_INSTALLED="yes"
CLOUDFLARED_INSTALLED="yes"
N8N_CONTAINER_CREATED="yes"
CLOUDFLARED_SERVICE_CREATED="yes"

# Backup location
MANIFEST_FILE="$manifest_file"
EOF
    
    chmod 600 "$manifest_file"
    print_success "Manifest created: $manifest_file"
}

scan_installation( {
    print_section "Qut VPS  tm cc thnh phn N8N"
    echo ""
    
    local found_items=0
    
    # Kim tra Docker
    echo " Kim tra Docker..."
    if command -v docker &> /dev/null; then
        echo "   Docker: $(docker --version"
        ((found_items++
    else
        echo "   Docker: Khng tm thy"
    fi
    
    # Kim tra Docker Compose
    echo " Kim tra Docker Compose..."
    if docker compose version &> /dev/null 2>&1; then
        echo "   Docker Compose: $(docker compose version 2>/dev/null | head -1"
        ((found_items++
    else
        echo "   Docker Compose: Khng tm thy"
    fi
    
    # Kim tra N8N container
    echo " Kim tra N8N container..."
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^n8n$"; then
        local status=$(docker ps --format '{{.Status}}' --filter "name=^n8n$" 2>/dev/null || echo "stopped"
        echo "   N8N container: $status"
        ((found_items++
    else
        echo "   N8N container: Khng tm thy"
    fi
    
    # Kim tra N8N image
    echo " Kim tra N8N image..."
    if docker images --format '{{.Repository}}' 2>/dev/null | grep -q "n8nio/n8n"; then
        local image_id=$(docker images --format '{{.ID}}' --filter "reference=n8nio/n8n" 2>/dev/null | head -1
        echo "   N8N image: $image_id"
        ((found_items++
    else
        echo "   N8N image: Khng tm thy"
    fi
    
    # Kim tra N8N network
    echo " Kim tra N8N network..."
    if docker network ls --format '{{.Name}}' 2>/dev/null | grep -q "n8n-network"; then
        echo "   N8N network: n8n-network"
        ((found_items++
    else
        echo "   N8N network: Khng tm thy"
    fi
    
    # Kim tra Cloudflared
    echo " Kim tra Cloudflared..."
    if command -v cloudflared &> /dev/null; then
        echo "   Cloudflared: $(cloudflared --version 2>/dev/null | head -1"
        ((found_items++
    else
        echo "   Cloudflared: Khng tm thy"
    fi
    
    # Kim tra Cloudflared service
    echo " Kim tra Cloudflared service..."
    if systemctl is-enabled cloudflared &> /dev/null 2>&1; then
        local cf_status=$(systemctl is-active cloudflared 2>/dev/null || echo "unknown"
        echo "   Cloudflared service: $cf_status"
        ((found_items++
    else
        echo "   Cloudflared service: Khng tm thy"
    fi
    
    # Kim tra N8N data directory
    echo " Kim tra N8N data directory..."
    if [ -d "$N8N_BASE_DIR" ]; then
        local size=$(du -sh "$N8N_BASE_DIR" 2>/dev/null | cut -f1
        echo "   N8N directory: $N8N_BASE_DIR ($size"
        ((found_items++
    else
        echo "   N8N directory: Khng tm thy"
    fi
    
    # Kim tra Backup directory
    echo " Kim tra Backup directory..."
    if [ -d "$BACKUP_DIR" ]; then
        local backup_count=$(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l
        local backup_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1
        echo "   Backup directory: $BACKUP_DIR ($backup_count backups, $backup_size"
        ((found_items++
    else
        echo "   Backup directory: Khng tm thy"
    fi
    
    # Kim tra Cloudflared config
    echo " Kim tra Cloudflared config..."
    if [ -f "$CLOUDFLARED_CONFIG_FILE" ]; then
        echo "   Cloudflared config: $CLOUDFLARED_CONFIG_FILE"
        ((found_items++
    else
        echo "   Cloudflared config: Khng tm thy"
    fi
    
    # Kim tra Config file
    echo " Kim tra Config file..."
    if [ -f "$CONFIG_FILE" ]; then
        echo "   Config file: $CONFIG_FILE"
        ((found_items++
    else
        echo "   Config file: Khng tm thy"
    fi
    
    echo ""
    echo " Tng cng tm thy: $found_items thnh phn"
    echo ""
    
    return 0
}

uninstall_n8n( {
    print_section "G ci t N8N"
    echo ""
    
    # Scan trc
    scan_installation
    echo ""
    
    # Xc nhn
    print_warning "  CNH BO: Qu trnh g ci s:"
    echo "   Dng N8N container"
    echo "   Xa N8N container"
    echo "   Xa N8N image"
    echo "   Xa N8N network"
    echo "   Dng Cloudflared service"
    echo "   Xa Cloudflared config"
    echo "   Xa N8N data directory (workflows, database, etc."
    echo "   Xa config files"
    echo ""
    print_warning "  Backup s c GI LI trong: $BACKUP_DIR"
    echo ""
    
    read -p "Bn c chc chn mun g ci N8N? (y/N: " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Hy g ci"
        return 0
    fi
    
    echo ""
    print_section "Bt u g ci..."
    echo ""
    
    # 1. Dng N8N container
    echo "1 Dng N8N container..."
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^n8n$"; then
        docker compose -f "$DOCKER_COMPOSE_FILE" down 2>/dev/null || true
        print_success "N8N container  dng"
    else
        echo "   (N8N container khng chy"
    fi
    
    # 2. Xa N8N container
    echo "2 Xa N8N container..."
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^n8n$"; then
        docker rm -f n8n 2>/dev/null || true
        print_success "N8N container  xa"
    else
        echo "   (N8N container khng tn ti"
    fi
    
    # 3. Xa N8N image
    echo "3 Xa N8N image..."
    if docker images --format '{{.Repository}}' 2>/dev/null | grep -q "n8nio/n8n"; then
        docker rmi -f n8nio/n8n 2>/dev/null || true
        print_success "N8N image  xa"
    else
        echo "   (N8N image khng tn ti"
    fi
    
    # 4. Xa N8N network
    echo "4 Xa N8N network..."
    if docker network ls --format '{{.Name}}' 2>/dev/null | grep -q "n8n-network"; then
        docker network rm n8n-network 2>/dev/null || true
        print_success "N8N network  xa"
    else
        echo "   (N8N network khng tn ti"
    fi
    
    # 5. Dng Cloudflared service
    echo "5 Dng Cloudflared service..."
    if systemctl is-active cloudflared &> /dev/null 2>&1; then
        systemctl stop cloudflared 2>/dev/null || true
        systemctl disable cloudflared 2>/dev/null || true
        print_success "Cloudflared service  dng"
    else
        echo "   (Cloudflared service khng chy"
    fi
    
    # 6. Xa Cloudflared config
    echo "6 Xa Cloudflared config..."
    if [ -f "$CLOUDFLARED_CONFIG_FILE" ]; then
        rm -f "$CLOUDFLARED_CONFIG_FILE" 2>/dev/null || true
        print_success "Cloudflared config  xa"
    else
        echo "   (Cloudflared config khng tn ti"
    fi
    
    # 7. Xa N8N data directory
    echo "7 Xa N8N data directory..."
    if [ -d "$N8N_BASE_DIR" ]; then
        rm -rf "$N8N_BASE_DIR" 2>/dev/null || true
        print_success "N8N data directory  xa"
    else
        echo "   (N8N data directory khng tn ti"
    fi
    
    # 8. Xa config file
    echo "8 Xa config file..."
    if [ -f "$CONFIG_FILE" ]; then
        rm -f "$CONFIG_FILE" 2>/dev/null || true
        print_success "Config file  xa"
    else
        echo "   (Config file khng tn ti"
    fi
    
    echo ""
    print_section "G ci hon thnh!"
    echo ""
    echo " Cc thnh phn  c g ci:"
    echo "   N8N container"
    echo "   N8N image"
    echo "   N8N network"
    echo "   N8N data directory"
    echo "   Cloudflared service"
    echo "   Cloudflared config"
    echo "   Config files"
    echo ""
    echo " Backup c gi li ti: $BACKUP_DIR"
    echo ""
    echo "  xa hon ton backup:"
    echo "   rm -rf $BACKUP_DIR"
    echo ""
}

# === Original Installation Functions ===
install_n8n( {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}    CLOUDFLARE TUNNEL & N8N SETUP${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo "Script ny s ci t Docker, Cloudflared v cu hnh N8N"
    echo " truy cp qua Cloudflare Tunnel."
    echo ""

    # --- Check for existing config ---
    if show_config_info; then
        echo -e "${YELLOW} Bn  c config trc !${NC}"
        read -p "Bn c mun s dng li config ny khng? (y/N: " use_existing
        
        if [ "$use_existing" = "y" ] || [ "$use_existing" = "Y" ]; then
            load_config
            print_success "S dng config c sn"
        else
            echo " Nhp config mi..."
            get_new_config
        fi
    else
        echo " Cha c config, cn nhp thng tin mi..."
        get_new_config
    fi
    
    echo "" # Newline for better formatting

    # --- System Update and Prerequisites ---
    echo ">>> Updating system packages..."
    apt update
    echo ">>> Installing prerequisites (curl, wget, gpg, etc...."
    apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release wget

    # --- Install Docker ---
    if command -v docker &> /dev/null; then
        print_success "Docker  c ci t: $(docker --version"
        
        # Kim tra Docker service
        if ! systemctl is-active docker &> /dev/null; then
            echo ">>> Docker service khng chy, khi ng..."
            systemctl start docker
            systemctl enable docker
            print_success "Docker service  c khi ng"
        else
            print_success "Docker service ang chy"
        fi
    else
        echo ">>> Docker not found. Installing Docker..."
        # Add Docker's official GPG key:
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
        
        # Add the repository to Apt sources:
        echo \
          "deb [arch=$(dpkg --print-architecture signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME" stable" | \
          tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt update

        # Install Docker packages
        apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        print_success "Docker installed successfully: $(docker --version"

        # Ensure Docker service is running and enabled
        systemctl start docker
        systemctl enable docker
        print_success "Docker service started and enabled"

        # Add the current sudo user (if exists to the docker group
        # This avoids needing sudo for every docker command AFTER logging out/in again
        REAL_USER="${SUDO_USER:-$(whoami}"
        if id "$REAL_USER" &>/dev/null && ! getent group docker | grep -qw "$REAL_USER"; then
          echo ">>> Adding user '$REAL_USER' to the 'docker' group..."
          usermod -aG docker "$REAL_USER"
          echo ">>> NOTE: User '$REAL_USER' needs to log out and log back in for docker group changes to take full effect."
        fi
    fi
    
    # nh ngha REAL_USER cho tt c trng hp (sau khi ci t hoc  c sn
    REAL_USER="${SUDO_USER:-$(whoami}"

    # --- Install Cloudflared ---
    if command -v cloudflared &> /dev/null; then
        print_success "Cloudflared  c ci t: $(cloudflared --version 2>/dev/null | head -1"
    else
        echo ">>> Cloudflared not found. Installing Cloudflared..."
    
        # Automatically determine the system architecture
        ARCH=$(dpkg --print-architecture
        echo ">>> Detected system architecture: $ARCH"
    
        local CLOUDFLARED_DEB_URL
        local CLOUDFLARED_DEB_PATH="/tmp/cloudflared-linux-$ARCH.deb" # Use detected arch in filename
    
        case "$ARCH" in
            amd64
                CLOUDFLARED_DEB_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb"
                ;;
            arm64|armhf # armhf for older 32-bit ARM, arm64 for 64-bit ARM
                CLOUDFLARED_DEB_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$ARCH.deb"
                ;;
            *
                print_error "Unsupported architecture: $ARCH. Cannot install Cloudflared automatically."
                exit 1
                ;;
        esac
    
        echo ">>> Downloading Cloudflared package for $ARCH from $CLOUDFLARED_DEB_URL..."
        wget -q "$CLOUDFLARED_DEB_URL" -O "$CLOUDFLARED_DEB_PATH"
    
        if [ $? -ne 0 ]; then
            print_error "Failed to download Cloudflared package."
            exit 1
        fi
    
        echo ">>> Installing Cloudflared package..."
        dpkg -i "$CLOUDFLARED_DEB_PATH"
    
        if [ $? -ne 0 ]; then
            print_error "Failed to install Cloudflared. Please check logs for details."
            exit 1
        fi
    
        rm "$CLOUDFLARED_DEB_PATH" # Clean up downloaded file
        print_success "Cloudflared installed successfully: $(cloudflared --version 2>/dev/null | head -1"
    fi

    # --- Setup n8n Directory and Permissions ---
    echo ">>> Setting up n8n data directory: $N8N_BASE_DIR"
    mkdir -p "$N8N_VOLUME_DIR" # Create the specific volume dir as well
    
    # Set ownership to UID 1000, GID 1000 (standard 'node' user in n8n official container
    # This prevents permission errors when n8n tries to write data
    # NOTE: This assumes the official n8n Docker image. Custom images may use different UIDs.
    echo ">>> Setting permissions for n8n data volume..."
    chown -R 1000:1000 "$N8N_VOLUME_DIR"
    
    # Set secure permissions (700 = owner only read/write/execute
    # This protects sensitive data like credentials, workflows, and database
    echo ">>> Setting secure permissions (700 for n8n data..."
    chmod -R 700 "$N8N_VOLUME_DIR"

    # --- Generate or Load N8N Encryption Key ---
    N8N_ENCRYPTION_KEY_FILE="$N8N_BASE_DIR/.n8n_encryption_key"
    
    if [ -f "$N8N_ENCRYPTION_KEY_FILE" ]; then
        echo ">>> Loading existing N8N encryption key..."
        N8N_ENCRYPTION_KEY=$(cat "$N8N_ENCRYPTION_KEY_FILE"
        print_success "Encryption key loaded from: $N8N_ENCRYPTION_KEY_FILE"
    else
        echo ">>> Generating new N8N encryption key..."
        # Generate a secure random 32-byte key encoded in base64
        N8N_ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -d '\n'
        
        # Save the key securely
        echo "$N8N_ENCRYPTION_KEY" > "$N8N_ENCRYPTION_KEY_FILE"
        chmod 600 "$N8N_ENCRYPTION_KEY_FILE"
        
        print_success "New encryption key generated and saved to: $N8N_ENCRYPTION_KEY_FILE"
        print_warning "  QUAN TRNG: Backup file ny  c th restore credentials sau ny!"
    fi
    
    # --- Check if N8N container already exists ---
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^n8n$"; then
        print_warning "  N8N container  tn ti!"
        read -p "Bn c mun khi ng li container khng? (y/N: " restart_container
        if [ "$restart_container" = "y" ] || [ "$restart_container" = "Y" ]; then
            docker compose -f "$DOCKER_COMPOSE_FILE" up -d 2>/dev/null || true
            print_success "N8N container  c khi ng"
            health_check
            exit 0
        fi
    fi
    
    # --- Create Docker Compose File ---
    echo ">>> Creating Docker Compose file: $DOCKER_COMPOSE_FILE"
    # Determine Timezone
    SYSTEM_TZ=$(cat /etc/timezone 2>/dev/null || echo "$DEFAULT_TZ"
    
    # Determine port binding based on mode
    if [ "$CF_HOSTNAME" = "localhost" ]; then
        PORT_BINDING="127.0.0.1:5678:5678"
        PORT_COMMENT="# Local mode - bind to localhost only"
    else
        PORT_BINDING="127.0.0.1:5678:5678"
        PORT_COMMENT="# Cloudflare mode - bind to localhost, Cloudflared handles external access"
    fi
    
    cat <<EOF > "$DOCKER_COMPOSE_FILE"
services:
  n8n:
    image: n8nio/n8n
    container_name: n8n
    restart: unless-stopped
    ports:
      $PORT_COMMENT
      - "$PORT_BINDING"
    environment:
      # Use system timezone if available, otherwise default
      - TZ=${SYSTEM_TZ}
      # CRITICAL: Encryption key for credentials - DO NOT CHANGE after first run
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
EOF
    
    # Add Cloudflare-specific settings only if not in local mode
    if [ "$CF_HOSTNAME" != "localhost" ]; then
        cat <<EOF >> "$DOCKER_COMPOSE_FILE"
      # Security settings for HTTPS access via Cloudflare
      - N8N_HOST=${CF_HOSTNAME}
      - WEBHOOK_URL=https://${CF_HOSTNAME}/
EOF
    fi
    
    cat <<EOF >> "$DOCKER_COMPOSE_FILE"
      # Performance and security optimizations
      - N8N_METRICS=false
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_VERSION_NOTIFICATIONS_ENABLED=false
      # N8N_SECURE_COOKIE=false # DO NOT USE THIS when accessing via HTTPS (Cloudflared
    volumes:
      # Mount the local data directory into the container
      - ./n8n_data:/home/node/.n8n
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:5678/healthz || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

networks:
  default:
    name: n8n-network # Define a specific network name (optional but good practice

EOF
    
    # Encryption key  c lu  trn, khng cn lu li
    print_success "Docker Compose file created with security enhancements"
    print_success "Encryption key saved to: $N8N_BASE_DIR/.n8n_encryption_key"

    # --- Configure Cloudflared Service (skip if local mode ---
    if [ "$CF_HOSTNAME" != "localhost" ]; then
        echo ">>> Configuring Cloudflared..."
        # Create directory if it doesn't exist
        mkdir -p /etc/cloudflared

        # Create cloudflared config.yml
        echo ">>> Creating Cloudflared config file: $CLOUDFLARED_CONFIG_FILE"
        cat <<EOF > "$CLOUDFLARED_CONFIG_FILE"
# This file is configured for tunnel runs via 'cloudflared service install'
# It defines the ingress rules. Tunnel ID and credentials file are managed
# automatically by the service install command using the provided token.
# Do not add 'tunnel:' or 'credentials-file:' lines here.

ingress:
  - hostname: ${CF_HOSTNAME}
    service: http://localhost:5678 # Points to n8n running locally via Docker port mapping
  - service: http_status:404 # Catch-all rule
EOF
        echo ">>> Cloudflared config file created."

        # --- Check if Cloudflared service already exists ---
        if systemctl is-enabled cloudflared &> /dev/null 2>&1; then
            print_warning "  Cloudflared service  c ci t!"
            local cf_status=$(systemctl is-active cloudflared 2>/dev/null || echo "unknown"
            print_success "Cloudflared service status: $cf_status"
            
            if [ "$cf_status" != "active" ]; then
                echo ">>> Khi ng li Cloudflared service..."
                systemctl restart cloudflared
                print_success "Cloudflared service  c khi ng"
            fi
        else
            # Install cloudflared as a service using the token
            echo ">>> Installing Cloudflared service using the provided token..."
            # The service install command handles storing the token securely
            cloudflared service install "$CF_TOKEN"
            print_success "Cloudflared service installed."

            # --- Start Services ---
            echo ">>> Enabling and starting Cloudflared service..."
            systemctl enable cloudflared
            systemctl start cloudflared
        fi
    else
        print_success "Ch  Local - Cloudflared khng c ci t"
    fi

    # Brief pause to allow service to stabilize
    sleep 5
    echo ">>> Checking Cloudflared service status:"
    systemctl status cloudflared --no-pager || echo "Warning: Cloudflared status check indicates an issue. Use 'sudo journalctl -u cloudflared' for details."

    echo ">>> Starting n8n container via Docker Compose..."
    # Use -f to specify the file, ensuring it runs from anywhere
    # Use --remove-orphans to clean up any old containers if the compose file changed significantly
    # Use -d to run in detached mode
    docker compose -f "$DOCKER_COMPOSE_FILE" up --remove-orphans -d

    # --- Create Manifest ---
    echo ">>> Creating installation manifest..."
    create_manifest
    
    # --- Final Instructions ---
    echo ""
    echo "--------------------------------------------------"
    echo " Setup Complete! "
    echo "--------------------------------------------------"
    
    if [ "$CF_HOSTNAME" = "localhost" ]; then
        echo " N8N  c ci t  ch  Local Mode"
        echo ""
        echo " Truy cp N8N ti:"
        echo "   http://localhost:5678"
        echo ""
        echo " Thng tin Local Mode:"
        echo "    Ch c th truy cp t my local"
        echo "    Khng cn cu hnh Cloudflare"
        echo "    Khng cn DNS"
        echo "    Hon ho cho pht trin v th nghim"
        echo ""
        echo "  chuyn sang Cloudflare Mode sau ny:"
        echo "   1. Chy: sudo bash $0 config"
        echo "   2. Chn 'To config mi'"
        echo "   3. Chn 'C' khi c hi v Cloudflare Tunnel"
        echo ""
    else
        echo " N8N  c ci t vi Cloudflare Tunnel"
        echo ""
        echo " Truy cp N8N ti:"
        echo "   https://${CF_HOSTNAME}"
        echo ""
        echo "  QUAN TRNG: Bn cn cu hnh DNS trong Cloudflare Dashboard!"
        echo ""
        echo " Cc bc tip theo:"
        echo ""
        echo "1 Vo Cloudflare Dashboard: https://dash.cloudflare.com/"
        echo ""
        echo "2 To DNS Record:"
        echo "    Type: CNAME"
        echo "    Name: $(echo ${CF_HOSTNAME} | cut -d'.' -f1"
        echo "    Target: [tunnel-id].cfargotunnel.com"
        echo "    Proxy: Proxied (mu cam"
        echo ""
        echo "3 Cu hnh Public Hostname trong Tunnel:"
        echo "    Access  Tunnels  Chn tunnel"
        echo "    Public Hostname  Add a public hostname"
        echo "    Subdomain: $(echo ${CF_HOSTNAME} | cut -d'.' -f1"
        echo "    Domain: $(echo ${CF_HOSTNAME} | cut -d'.' -f2-"
        echo "    Service: http://localhost:5678"
        echo ""
        echo " Hn g dn chi tit: Xem file CLOUDFLARE_DNS_SETUP.md"
        echo ""
    fi
    echo " Kim tra "trng thi:"
    echo "   sudo bash $0 status"
    echo ""
    echo " Xem logs:"
    echo "   docker logs n8n"
    if [ "$CF_HOSTNAME" != "localhost" ]; then
        echo "   sudo journalctl -u cloudflared -f"
    fi
    echo ""
    echo " Cc lnh hu ch:"
    echo "    Backup N8N: sudo bash $0 backup"
    echo "    Update N8N: sudo bash $0 update"  
    echo "    Backup & Update: sudo bash $0 backup-update"
    echo "    Qun l Config: sudo bash $0 config"
    echo "    G ci t: sudo bash $0 uninstall"
    echo ""
    if [ "$REAL_USER" != "root" ]; then
        echo " Lu : User '$REAL_USER' va c thm vo docker group"
        echo "   Vui lng ng xut v ng nhp li  p dng thay i"
    fi
    echo "--------------------------------------------------"
}

show_menu( {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}    N8N MANAGEMENT SCRIPT${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
    echo "Chon hanh dong:"
    echo "1. Cai dat N8N moi - voi Cloudflare Tunnel"
    echo "2. Backup du lieu N8N"
    echo "3. Update N8N len phien ban moi nhat"
    echo "4. Backup + Update N8N"
    echo "5. Kiem tra trang thai he thong"
    echo "6. Xem thong tin backup"
    echo "7. Rollback tu backup"
    echo "8. Don dep backup cu"
    echo "9. Xem/Quan ly config Cloudflare"
    echo "10. Quet VPS de tim thanh phan N8N"
    echo "11. Go cai dat N8N hoan toan"
    echo "0. Thoat"
    echo ""
    read -p "Nhap lua chon [0-11]: " choice
}

# === Main Script Logic ===
# Nu c tham s dng lnh
if [ $# -gt 0 ]; then
    case $1 in
        "install"
            install_n8n
            ;;
        "backup"
            check_current_version
            show_server_status
            count_backups
            create_backup
            ;;
        "update"
            check_current_version
            update_n8n
            ;;
        "backup-update"
            backup_and_update
            ;;
        "status"
            check_current_version
            show_server_status
            count_backups
            ;;
        "rollback"
            rollback_backup
            ;;
        "cleanup"
            cleanup_old_backups
            ;;
        "config"
            manage_config
            ;;
        "scan"
            scan_installation
            ;;
        "uninstall"
            uninstall_n8n
            ;;
        *
            echo "S dng: $0 [install|backup|update|backup-update|status|rollback|cleanup|config|scan|uninstall]"
            echo ""
            echo "V d:"
            echo "  $0 install        # Ci t N8N mi"
            echo "  $0 backup         # Backup d liu"
            echo "  $0 update         # Update N8N"
            echo "  $0 backup-update  # Backup v update"
            echo "  $0 status         # Kim tra trng thi"
            echo "  $0 rollback       # Rollback t backup"
            echo "  $0 cleanup        # Dn dp backup c"
            echo "  $0 config         # Qun l config"
            echo "  $0 scan           # Qut VPS  tm thnh phn N8N"
            echo "  $0 uninstall      # G ci t N8N hon ton"
            exit 1
            ;;
    esac
else
    # Menu tng tc
    while true; do
        show_menu
        case $choice in
            1
                install_n8n
                ;;
            2
                check_current_version
                show_server_status
                count_backups
                create_backup
                ;;
            3
                check_current_version
                update_n8n
                ;;
            4
                backup_and_update
                ;;
            5
                check_current_version
                show_server_status
                count_backups
                ;;
            6
                count_backups
                ;;
            7
                rollback_backup
                ;;
            8
                cleanup_old_backups
                ;;
            9
                manage_config
                ;;
            10
                scan_installation
                ;;
            11
                uninstall_n8n
                ;;
            0
                echo "Tm bit!"
                exit 0
                ;;
            *
                print_error "La chn khng hp l!"
                ;;
        esac
        echo ""
        read -p "Nhn Enter  tip tc..."
        clear
    done
fi

exit 0

