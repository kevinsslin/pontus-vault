"use client";

import type { VaultRecord } from "@pti/shared";
import OperatorConsole from "./OperatorConsole";

type OperatorConsoleShellProps = {
  vaults: VaultRecord[];
};

export default function OperatorConsoleShell({ vaults }: OperatorConsoleShellProps) {
  return <OperatorConsole vaults={vaults} />;
}
