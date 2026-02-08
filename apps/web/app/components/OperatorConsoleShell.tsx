"use client";

import type { VaultRecord } from "@pti/shared";
import DynamicBoundary from "./DynamicBoundary";
import OperatorConsole from "./OperatorConsole";

type OperatorConsoleShellProps = {
  vaults: VaultRecord[];
};

export default function OperatorConsoleShell({ vaults }: OperatorConsoleShellProps) {
  return (
    <DynamicBoundary>
      <OperatorConsole vaults={vaults} />
    </DynamicBoundary>
  );
}
