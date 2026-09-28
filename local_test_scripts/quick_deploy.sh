#!/usr/bin/env bash
set -Eeuo pipefail

# 1. Build/package from a clean isolated checkout
COMMIT_SHA=$(git rev-parse HEAD)
echo "Deploying GC SHA: $COMMIT_SHA"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
git archive --format=tar "$COMMIT_SHA" | (cd "$WORK_DIR" && tar xf -)

cd "$WORK_DIR"
echo "Building from clean checkout..."
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || true
npm ci >/dev/null 2>&1
npm run build >/dev/null 2>&1

echo "Packaging standalone artifact..."
cp -a public .next/standalone/public
cp -a .next/static .next/standalone/.next/static
cp package.json .next/standalone/package.json
cp .next/BUILD_ID .next/standalone/.next/BUILD_ID
echo "$COMMIT_SHA" > .next/standalone/.release-sha

# Validate local structure
for req in server.js .next/server .next/static public .release-sha package.json; do
    if [ ! -e ".next/standalone/$req" ]; then
        echo "ERROR: Missing $req in local artifact build."
        exit 1
    fi
done

TAR_FILE="/tmp/deploy_${COMMIT_SHA}.tar.gz"
tar -czf "$TAR_FILE" -C .next/standalone .
LOCAL_CHECKSUM=$(sha256sum "$TAR_FILE" | awk '{print $1}')

echo "Uploading artifact..."
scp -i ~/.ssh/namish_erp_vps -o ConnectTimeout=10 "$TAR_FILE" tridevah@97.74.92.189:"$TAR_FILE"

echo "Deploying on VPS..."
ssh -i ~/.ssh/namish_erp_vps -o ConnectTimeout=10 tridevah@97.74.92.189 << REMOTE_SCRIPT
set -Eeuo pipefail

COMMIT_SHA="$COMMIT_SHA"
EXPECTED_CHECKSUM="$LOCAL_CHECKSUM"
TAR_FILE="$TAR_FILE"

REMOTE_CHECKSUM=\$(sha256sum "\$TAR_FILE" | awk '{print \$1}')
if [ "\$REMOTE_CHECKSUM" != "\$EXPECTED_CHECKSUM" ]; then
    echo "ERROR: Checksum mismatch! Local: \$EXPECTED_CHECKSUM, Remote: \$REMOTE_CHECKSUM"
    exit 1
fi

REMOTE_ROOT="\${REMOTE_ROOT:-/srv/namish-global-control}"
APP_SYMLINK="\$REMOTE_ROOT/app"
SERVICE_NAME="namish-global-control.service"
NEW_RELEASE_DIR="\$REMOTE_ROOT/releases/\$COMMIT_SHA"

# 3. Capture exact previous release
if [ -L "\$APP_SYMLINK" ]; then
    PREV_RELEASE_DIR=\$(readlink -f "\$APP_SYMLINK")
else
    echo "ERROR: \$APP_SYMLINK is not a valid symlink!"
    exit 1
fi

if [ ! -d "\$PREV_RELEASE_DIR" ]; then
    echo "ERROR: Previous release directory \$PREV_RELEASE_DIR does not exist!"
    exit 1
fi

if [ "\$PREV_RELEASE_DIR" == "\$NEW_RELEASE_DIR" ]; then
    echo "ERROR: Active release is already \$COMMIT_SHA."
    exit 1
fi

if [ -e "\$NEW_RELEASE_DIR" ]; then
    echo "ERROR: Release directory \$NEW_RELEASE_DIR already exists."
    exit 1
fi

echo "Extracting to \$NEW_RELEASE_DIR..."
mkdir -p "\$NEW_RELEASE_DIR"
tar -xzf "\$TAR_FILE" -C "\$NEW_RELEASE_DIR"

# Validate core dependencies without hardcoding Turbopack layout assumption
for req in server.js .next/server .next/static public .release-sha .next/BUILD_ID package.json node_modules; do
    if [ ! -e "\$NEW_RELEASE_DIR/\$req" ]; then
        echo "ERROR: Missing \$req in extracted candidate"
        exit 1
    fi
done

app_switched=0

# Route every post-cutover failure through an explicit rollback function
rollback_on_error() {
    local exit_code=\$1
    trap - ERR
    if [ "\$app_switched" -eq 1 ]; then
        echo "ERROR: Deployment failed. Rolling back to \$PREV_RELEASE_DIR..."
        sudo systemctl stop "\$SERVICE_NAME" || true
        # Atomic temporary-symlink rename for rollback with critical error
        ln -sfn "\$PREV_RELEASE_DIR" "\$APP_SYMLINK.tmp" || { echo "CRITICAL ERROR: Rollback ln failed"; exit 5; }
        mv -Tf "\$APP_SYMLINK.tmp" "\$APP_SYMLINK" || { echo "CRITICAL ERROR: Rollback mv failed"; exit 5; }
    else
        echo "ERROR: Deployment aborted pre-cutover. State UNCHANGED."
    fi
    
    sudo systemctl start "\$SERVICE_NAME" || true
    
    # Verify rollback resolves to the exact previous target and passes health
    sleep 2
    if ! systemctl is-active --quiet "\$SERVICE_NAME"; then
        echo "CRITICAL ERROR: Rollback failed! Service is not active."
        exit 2
    fi
    
    HTTP_RB=\$(curl -sS -o /dev/null -w "%{http_code}" --max-time 5 http://127.0.0.1:3100/api/health || echo "000")
    if [ "\$HTTP_RB" != "200" ]; then
        echo "CRITICAL ERROR: Rollback HTTP health check failed with \$HTTP_RB!"
        exit 3
    fi
    
    ACTUAL_SYMLINK_RB=\$(readlink -f "\$APP_SYMLINK")
    if [ "\$ACTUAL_SYMLINK_RB" != "\$PREV_RELEASE_DIR" ]; then
        echo "CRITICAL ERROR: Rollback symlink is \$ACTUAL_SYMLINK_RB, expected \$PREV_RELEASE_DIR!"
        exit 4
    fi
    
    if [ "\$app_switched" -eq 1 ]; then
        echo "Rollback successful."
    else
        echo "Abort successful. Target remained \$PREV_RELEASE_DIR."
    fi
    exit "\$exit_code"
}

trap 'rollback_on_error 1' ERR

echo "Starting controlled cutover..."
sudo systemctl stop "\$SERVICE_NAME"

# Explicit timeout abort for port clearing
port_cleared=0
for unused_attempt in {1..15}; do
  SS_OUT=\$(ss -H -ltn 'sport = :3100' 2>/dev/null) || { echo "CRITICAL ERROR: ss command failed."; rollback_on_error 1; }
  if [ -z "\$SS_OUT" ]; then
    port_cleared=1
    break
  fi
  sleep 1
done

if [ "\$port_cleared" -ne 1 ]; then
    echo "CRITICAL ERROR: Port 3100 failed to clear. Aborting cutover."
    rollback_on_error 1
fi

# Atomic temporary-symlink rename for cutover
ln -sfn "\$NEW_RELEASE_DIR" "\$APP_SYMLINK.tmp" || { echo "ERROR: Cutover ln failed"; rollback_on_error 1; }
mv -Tf "\$APP_SYMLINK.tmp" "\$APP_SYMLINK" || { echo "ERROR: Cutover mv failed"; rollback_on_error 1; }
app_switched=1

sudo systemctl start "\$SERVICE_NAME"
sleep 2

if ! systemctl is-active --quiet "\$SERVICE_NAME"; then
    echo "ERROR: Service failed to start."
    rollback_on_error 1
fi

is_healthy_status() {
  case "\$1" in
    200|301|302|307|308) return 0 ;;
    *) return 1 ;;
  esac
}

echo "Checking internal and public health..."
for attempt in {1..30}; do
  # Reset health flags each attempt so earlier successes cannot mask later failures
  INTERNAL_OK=0
  PUBLIC_OK=0
  
  # Require exact HTTP 200 for internal health
  HTTP_INTERNAL=\$(curl -sS -o /tmp/hc.json -w "%{http_code}" --max-time 2 http://127.0.0.1:3100/api/health || echo "000")
  if [ "\$HTTP_INTERNAL" == "200" ]; then
      INTERNAL_OK=1
  fi
  
  HTTP_PUBLIC=\$(curl -sS -o /tmp/public.html -w "%{http_code}" --max-time 2 https://control.tridevah.com/login || echo "000")
  if is_healthy_status "\$HTTP_PUBLIC"; then
      # Fetch JS/CSS URLs referenced by the public login HTML and require successful responses
      ASSETS=\$(grep -oE '/_next/static/[^"]+\.(css|js)' /tmp/public.html | sort -u || true)
      ASSETS_OK=1
      
      if [ -z "\$ASSETS" ]; then
          # Missing JS/CSS references must fail validation. No fallback.
          ASSETS_OK=0
      else
          for asset in \$ASSETS; do
              # Verify referenced assets through BOTH localhost and the public HTTPS URL
              A_STAT_LOCAL=\$(curl -sS -o /dev/null -w "%{http_code}" --max-time 2 "http://127.0.0.1:3100\$asset" || echo "000")
              if [ "\$A_STAT_LOCAL" != "200" ]; then
                  ASSETS_OK=0
                  echo "WARNING: Local asset \$asset failed with \$A_STAT_LOCAL"
                  break
              fi
              
              A_STAT_PUB=\$(curl -sS -o /dev/null -w "%{http_code}" --max-time 2 "https://control.tridevah.com\$asset" || echo "000")
              if [ "\$A_STAT_PUB" != "200" ]; then
                  ASSETS_OK=0
                  echo "WARNING: Public asset \$asset failed with \$A_STAT_PUB"
                  break
              fi
          done
      fi
      
      if [ "\$ASSETS_OK" -eq 1 ]; then
          PUBLIC_OK=1
      fi
  fi
  
  if [ "\$INTERNAL_OK" -eq 1 ] && [ "\$PUBLIC_OK" -eq 1 ]; then
      break
  fi
  sleep 2
done

if [ "\$INTERNAL_OK" -eq 0 ] || [ "\$PUBLIC_OK" -eq 0 ]; then
    echo "ERROR: Health check timeout. Internal: \$INTERNAL_OK, Public: \$PUBLIC_OK"
    rollback_on_error 1
fi

# Inspect real /api/health implementation: Documented identity field only if present
ACTUAL_SHA=\$(jq -r '.version // .releaseId // .sha // empty' /tmp/hc.json 2>/dev/null || echo "")

if [ -n "\$ACTUAL_SHA" ]; then
    if [ "\$ACTUAL_SHA" != "\$COMMIT_SHA" ]; then
        echo "ERROR: Identity mismatch! Expected \$COMMIT_SHA, got \$ACTUAL_SHA"
        rollback_on_error 1
    fi
else
    echo "No identity field in health response. Verifying MainPID CWD against immutable release..."
    MAINPID=\$(systemctl show -p MainPID --value "\$SERVICE_NAME" || echo "0")
    if [ -z "\$MAINPID" ] || [ "\$MAINPID" == "0" ]; then
        echo "ERROR: Service is not running or MainPID is 0"
        rollback_on_error 1
    fi
    ACTUAL_CWD=\$(readlink -f /proc/\$MAINPID/cwd)
    if [ "\$ACTUAL_CWD" != "\$NEW_RELEASE_DIR" ]; then
        echo "ERROR: Process CWD mismatch! Expected \$NEW_RELEASE_DIR, got \$ACTUAL_CWD"
        rollback_on_error 1
    fi
    
    # Verify artifact checksum and exact release marker
    MARKER_SHA=\$(cat "\$NEW_RELEASE_DIR/.release-sha" 2>/dev/null || echo "")
    if [ "\$MARKER_SHA" != "\$COMMIT_SHA" ]; then
        echo "ERROR: Release marker mismatch! Expected \$COMMIT_SHA, got \$MARKER_SHA"
        rollback_on_error 1
    fi
fi

echo "Deployment successful: \$COMMIT_SHA"
REMOTE_SCRIPT
