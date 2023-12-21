FROM node:18-alpine AS base

# Instalando dependecias somente quando necessario
FROM base AS deps

RUN apk add --no-cache libc6-compat
WORKDIR /app

# Instalando dependencias baseado no seu gerenciador de pacotes
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then yarn global add pnpm && pnpm i --frozen-lockfile; \
  else echo "Arquivo lock nao encontrado! " && exit 1; \
  fi

# Rebuildando somente quando necessario
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Desabilitando telemetria
ENV NEXT_TELEMETRY_DISABLED 1

RUN npm run build

# Imagem final, copia todos os arquivos e roda o next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

# configurando permissoes do cache
RUN mkdir .next
RUN chown nextjs:nodejs .next

# Recuperando saidas para diminuir tamanho da imagem
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000
ENV HOSTNAME "0.0.0.0"

CMD ["node", "server.js"]
