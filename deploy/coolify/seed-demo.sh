#!/bin/sh
# seed-demo.sh — roda o demo do agentmemory via curl (workaround até o
# pacote npm corrigir o bug do postJsonStrict sem AGENTMEMORY_SECRET).
#
# Uso:
#   docker exec -it agentmemory-bvxgl04myaxrdol7yx9opvob sh -c '
#     cat /opt/agentmemory/node_modules/@agentmemory/agentmemory/dist/seed-demo.sh | sh
#   '
#
# Ou copie este script para dentro do container e execute.

set -eu

BASE="http://localhost:3111"
SECRET="${AGENTMEMORY_SECRET:-$(cat /data/.hmac 2>/dev/null || echo '')}"

if [ -z "$SECRET" ]; then
  echo "ERRO: AGENTMEMORY_SECRET nao encontrado. Exporte ou rode dentro do container."
  exit 1
fi

AUTH="Authorization: Bearer $SECRET"

echo "=== Seeding demo data ==="

# Session 1: JWT auth setup
echo "--- Session 1: JWT auth setup ---"
S1="demo-jwt-$(date +%s)"
curl -sS -X POST "$BASE/agentmemory/session/start" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{\"sessionId\":\"$S1\",\"project\":\"demo\",\"cwd\":\"demo\"}" > /dev/null

for obs in \
  '{"hookType":"post_tool_use","sessionId":"'"$S1"'","project":"demo","cwd":"demo","timestamp":"'"$(date -Iseconds)"'","data":{"tool_name":"Write","tool_input":{"file_path":"src/middleware/auth.ts"},"tool_output":"Created JWT middleware using jose library. Tokens expire after 30 days. Chose jose over jsonwebtoken for Edge compatibility."}}' \
  '{"hookType":"post_tool_use","sessionId":"'"$S1"'","project":"demo","cwd":"demo","timestamp":"'"$(date -Iseconds)"'","data":{"tool_name":"Write","tool_input":{"file_path":"test/auth.test.ts"},"tool_output":"Added token validation tests covering expired, malformed, and valid cases."}}' \
  '{"hookType":"post_tool_use","sessionId":"'"$S1"'","project":"demo","cwd":"demo","timestamp":"'"$(date -Iseconds)"'","data":{"tool_name":"Bash","tool_input":{"command":"npm test"},"tool_output":"All 12 auth tests passing."}}'; do
  curl -sS -X POST "$BASE/agentmemory/observe" \
    -H "$AUTH" -H "Content-Type: application/json" \
    -d "$obs" > /dev/null
done
curl -sS -X POST "$BASE/agentmemory/session/end" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{\"sessionId\":\"$S1\"}" > /dev/null
echo "  Session 1 done"

# Session 2: PostgreSQL connection pool
echo "--- Session 2: PostgreSQL connection pool ---"
S2="demo-pg-$(date +%s)"
curl -sS -X POST "$BASE/agentmemory/session/start" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{\"sessionId\":\"$S2\",\"project\":\"demo\",\"cwd\":\"demo\"}" > /dev/null

for obs in \
  '{"hookType":"post_tool_use","sessionId":"'"$S2"'","project":"demo","cwd":"demo","timestamp":"'"$(date -Iseconds)"'","data":{"tool_name":"Write","tool_input":{"file_path":"src/db/pool.ts"},"tool_output":"Created PgPool with max 20 connections, 30s idle timeout, and automatic health checks."}}' \
  '{"hookType":"post_tool_use","sessionId":"'"$S2"'","project":"demo","cwd":"demo","timestamp":"'"$(date -Iseconds)"'","data":{"tool_name":"Write","tool_input":{"file_path":"src/db/migrate.ts"},"tool_output":"Added migration runner using postgres-js. Reads .sql files from migrations/ folder."}}' \
  '{"hookType":"post_tool_use","sessionId":"'"$S2"'","project":"demo","cwd":"demo","timestamp":"'"$(date -Iseconds)"'","data":{"tool_name":"Bash","tool_input":{"command":"npm run migrate:up"},"tool_output":"Migrations applied: 001_initial.sql, 002_add_users.sql"}}'; do
  curl -sS -X POST "$BASE/agentmemory/observe" \
    -H "$AUTH" -H "Content-Type: application/json" \
    -d "$obs" > /dev/null
done
curl -sS -X POST "$BASE/agentmemory/session/end" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{\"sessionId\":\"$S2\"}" > /dev/null
echo "  Session 2 done"

# Session 3: React component with accessibility
echo "--- Session 3: React component with accessibility ---"
S3="demo-react-$(date +%s)"
curl -sS -X POST "$BASE/agentmemory/session/start" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{\"sessionId\":\"$S3\",\"project\":\"demo\",\"cwd\":\"demo\"}" > /dev/null

for obs in \
  '{"hookType":"post_tool_use","sessionId":"'"$S3"'","project":"demo","cwd":"demo","timestamp":"'"$(date -Iseconds)"'","data":{"tool_name":"Write","tool_input":{"file_path":"src/components/DataTable.tsx"},"tool_output":"Built accessible DataTable with sorting, filtering, and keyboard navigation. Uses aria-sort, role=grid, and focus management."}}' \
  '{"hookType":"post_tool_use","sessionId":"'"$S3"'","project":"demo","cwd":"demo","timestamp":"'"$(date -Iseconds)"'","data":{"tool_name":"Write","tool_input":{"file_path":"src/hooks/useTableSort.ts"},"tool_output":"Custom hook for sort state management. Supports multi-column sort and stable sort for equal values."}}' \
  '{"hookType":"post_tool_use","sessionId":"'"$S3"'","project":"demo","cwd":"demo","timestamp":"'"$(date -Iseconds)"'","data":{"tool_name":"Bash","tool_input":{"command":"npx jest --coverage"},"tool_output":"DataTable tests: 98% coverage. All accessibility checks pass (axe-core)."}}'; do
  curl -sS -X POST "$BASE/agentmemory/observe" \
    -H "$AUTH" -H "Content-Type: application/json" \
    -d "$obs" > /dev/null
done
curl -sS -X POST "$BASE/agentmemory/session/end" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{\"sessionId\":\"$S3\"}" > /dev/null
echo "  Session 3 done"

echo ""
echo "=== Demo data seeded! Refresh the viewer. ==="