#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
set -a
source images.env
set +a

CLUSTER="${E2E_CLUSTER:-posthog-e2e}"
export POSTHOG_PORT="${POSTHOG_PORT:-30800}"
NAMESPACE=posthog
export POSTHOG_HOST=http://localhost:$POSTHOG_PORT
POSTHOG_CLUSTER_HOST=http://web.$NAMESPACE.svc.cluster.local:8000
SRC=.out/src
SNAPSHOT="${XDG_CACHE_HOME:-$HOME/.cache}/posthog-e2e/$(sha256sum images.env | cut -c1-16).tar"
kc() { kubectl --context "kind-$CLUSTER" --namespace "$NAMESPACE" "$@"; }
apply() { envsubst "$VARS" < "manifests/$1.yaml" | kc apply -f -; }

start=$SECONDS
phase() {
  echo "e2e-timing $1 $((SECONDS - start))s"
  start=$SECONDS
}

full_name() {
  case "$1" in
    *.*/*) echo "$1" ;;
    */*) echo "docker.io/$1" ;;
    *) echo "docker.io/library/$1" ;;
  esac
}

preload() {
  local refs ref tags=()
  refs="$(sed -n '/^KIND_NODE_IMAGE=/d; s/^[A-Z_]*_IMAGE=//p' images.env)"
  for ref in $refs; do
    docker pull -q "$ref" > /dev/null
    docker tag "$ref" "${ref%@*}"
    tags+=("${ref%@*}")
  done
  docker save "${tags[@]}" | docker exec -i "$CLUSTER-control-plane" ctr -n k8s.io images import --snapshotter=overlayfs -
  for ref in $refs; do
    docker exec "$CLUSTER-control-plane" ctr -n k8s.io images tag "$(full_name "${ref%@*}")" "$(full_name "${ref%%:*}")@${ref#*@}" > /dev/null
  done
}

restore() {
  local dir dump
  dir="$(mktemp -d)"
  tar -xf "$SNAPSHOT" -C "$dir"
  kc wait --for=condition=Available deployment/db deployment/clickhouse deployment/zookeeper --timeout=30m
  for dump in "$dir"/*.pgdump; do
    kc exec -i deploy/db -- pg_restore -U posthog -d postgres --clean --if-exists --create < "$dump"
  done
  kc exec -i deploy/clickhouse -- sh -c 'mkdir -p /var/lib/clickhouse/backups && cat > /var/lib/clickhouse/backups/snapshot.zip' < "$dir/clickhouse.zip"
  kc exec deploy/clickhouse -- clickhouse-client -q "RESTORE ALL FROM File('snapshot.zip')"
}

bake() {
  local dir db
  dir="$(mktemp -d)"
  for db in $(kc exec deploy/db -- psql -U posthog -d postgres -Atc "SELECT datname FROM pg_database WHERE NOT datistemplate AND datname <> 'postgres' AND datname NOT LIKE 'temporal%'"); do
    kc exec deploy/db -- pg_dump -U posthog -Fc "$db" > "$dir/$db.pgdump"
  done
  kc exec deploy/clickhouse -- clickhouse-client -q "BACKUP ALL EXCEPT DATABASES system, information_schema, INFORMATION_SCHEMA TO File('snapshot.zip')"
  kc exec deploy/clickhouse -- cat /var/lib/clickhouse/backups/snapshot.zip > "$dir/clickhouse.zip"
  mkdir -p "$(dirname "$SNAPSHOT")"
  tar -cf "$SNAPSHOT" -C "$dir" .
}

fresh=false
if ! kind get clusters | grep -x "$CLUSTER" > /dev/null; then
  envsubst "\${POSTHOG_PORT}" < kind.yaml | kind create cluster --name "$CLUSTER" --image "$KIND_NODE_IMAGE" --config -
  fresh=true
  phase cluster-create
  preload
  phase image-preload
fi

mkdir -p "$SRC"
for f in \
  docker/clickhouse/config.xml \
  docker/clickhouse/config.d/default.xml \
  docker/clickhouse/users.xml \
  docker/clickhouse/user_defined_function.xml \
  docker/clickhouse/docker-entrypoint-initdb.d/init-db.sh \
  docker/kafka/topics.txt \
  docker/temporal/dynamicconfig/development-sql.yaml; do
  curl -fsSL "https://raw.githubusercontent.com/PostHog/posthog/$POSTHOG_COMMIT/$f" -o "$SRC/$(basename "$f")"
done

kubectl --context "kind-$CLUSTER" create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl --context "kind-$CLUSTER" apply -f -
kc create configmap clickhouse-config --dry-run=client -o yaml \
  --from-file="$SRC/config.xml" --from-file="$SRC/default.xml" --from-file="$SRC/users.xml" --from-file="$SRC/user_defined_function.xml" \
  --from-file=backups.xml=clickhouse-backups.xml | kc apply -f -
kc create configmap clickhouse-initdb --dry-run=client -o yaml --from-file="$SRC/init-db.sh" | kc apply -f -
kc create configmap kafka-topics --dry-run=client -o yaml --from-file="$SRC/topics.txt" | kc apply -f -
kc create configmap temporal-dynamicconfig --dry-run=client -o yaml --from-file="$SRC/development-sql.yaml" | kc apply -f -

VARS="$(sed -n 's/^\([A-Z_]*\)=.*/${\1}/p' images.env | tr '\n' ' ') \${POSTHOG_HOST}"
apply stores
phase config
if $fresh && [ -f "$SNAPSHOT" ]; then
  restore
  phase snapshot-restore
fi
apply posthog
apply personhog

kc wait --for=condition=complete job/kafka-topics --timeout=30m
kc wait --for=condition=Available deployment --all --timeout=90m
phase posthog-ready

BOOTSTRAP="$(kc exec -i deploy/web -- env PYTHONPATH=/code:/python-runtime python - < bootstrap.py | grep '^POSTHOG_')"
printf 'POSTHOG_HOST=%s\nPOSTHOG_CLUSTER_HOST=%s\n%s\n' "$POSTHOG_HOST" "$POSTHOG_CLUSTER_HOST" "$BOOTSTRAP" > .out/posthog.env
echo "wrote $(pwd)/.out/posthog.env"
phase bootstrap

if $fresh && [ ! -f "$SNAPSHOT" ]; then
  bake
  echo "baked $SNAPSHOT"
  phase snapshot-bake
fi
