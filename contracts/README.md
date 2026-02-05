# Contracts (Foundry)

This workspace holds the BoringVault stack integration and tranche wrapper contracts.

**Structure**
- `src/`: contracts (to be added)
- `script/Deploy.s.sol`: deployment entrypoint
- `test/unit`: isolated logic tests
- `test/integration`: full assembly tests
- `test/fork`: Atlantic fork tests
- `test/invariant`: property-based tests

**BoringVault Dependency**
```bash
forge install Se7en-Seas/boring-vault@0e23e7fd3a9a7735bd3fea61dd33c1700e75c528 --no-git
```

**Commands**
```bash
forge build
forge test
forge fmt
```

Use pnpm helpers from the repo root if preferred:
```bash
pnpm --filter @ptvi/contracts build
pnpm --filter @ptvi/contracts test
pnpm --filter @ptvi/contracts deploy
```
