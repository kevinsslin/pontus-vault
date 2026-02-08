import { getVaults } from "../../lib/data/vaults";
import OperatorConsoleShell from "../components/OperatorConsoleShell";

export const dynamic = "force-dynamic";
export const revalidate = 0;

export default async function OperatorPage() {
  const vaults = await getVaults();

  return (
    <main className="page">
      <OperatorConsoleShell vaults={vaults} />
    </main>
  );
}
