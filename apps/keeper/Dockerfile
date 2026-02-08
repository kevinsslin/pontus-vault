# Keeper (deploy-executor) for Railway. Requires Node, pnpm, and Foundry.
# Build context must be repo root (so contracts/, packages/, apps/ are available).
FROM node:20-bookworm-slim

# Foundry
RUN apt-get update && apt-get install -y --no-install-recommends curl git ca-certificates perl && rm -rf /var/lib/apt/lists/*
ENV PATH="/root/.foundry/bin:${PATH}"
RUN curl -L https://foundry.paradigm.xyz | bash && foundryup

# pnpm
RUN corepack enable && corepack prepare pnpm@10.28.2 --activate

WORKDIR /app
COPY . .

# contracts/lib is gitignored; install Foundry deps (forge-std, oz, boring-vault) so forge script runs
WORKDIR /app/contracts
RUN bash script/install-deps.sh

WORKDIR /app
RUN pnpm install --frozen-lockfile

EXPOSE 8787
CMD ["pnpm", "--filter", "@pti/keeper", "start:deploy-executor"]
