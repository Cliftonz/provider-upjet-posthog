#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
set -a
source images.env
set +a

CLUSTER=posthog-e2e
NAMESPACE=posthog
export POSTHOG_HOST=http://localhost:30800
POSTHOG_CLUSTER_HOST=http://web.$NAMESPACE.svc.cluster.local:8000
SRC=.out/src
kc() { kubectl --context "kind-$CLUSTER" --namespace "$NAMESPACE" "$@"; }

if ! kind get clusters | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER" --image "$KIND_NODE_IMAGE" --config kind.yaml
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
  --from-file="$SRC/config.xml" --from-file="$SRC/default.xml" --from-file="$SRC/users.xml" --from-file="$SRC/user_defined_function.xml" | kc apply -f -
kc create configmap clickhouse-initdb --dry-run=client -o yaml --from-file="$SRC/init-db.sh" | kc apply -f -
kc create configmap kafka-topics --dry-run=client -o yaml --from-file="$SRC/topics.txt" | kc apply -f -
kc create configmap temporal-dynamicconfig --dry-run=client -o yaml --from-file="$SRC/development-sql.yaml" | kc apply -f -

VARS="$(sed -n 's/^\([A-Z_]*\)=.*/${\1}/p' images.env | tr '\n' ' ') \${POSTHOG_HOST}"
for f in manifests/*.yaml; do envsubst "$VARS" < "$f" | kc apply -f -; done

kc wait --for=condition=complete job/kafka-topics --timeout=30m
kc wait --for=condition=Available deployment --all --timeout=90m

BOOTSTRAP="$(kc exec -i deploy/web -- env PYTHONPATH=/code:/python-runtime python - < bootstrap.py | grep '^POSTHOG_')"
printf 'POSTHOG_HOST=%s\nPOSTHOG_CLUSTER_HOST=%s\n%s\n' "$POSTHOG_HOST" "$POSTHOG_CLUSTER_HOST" "$BOOTSTRAP" > .out/posthog.env
echo "wrote $(pwd)/.out/posthog.env"
