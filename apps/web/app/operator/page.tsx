import { getVaults } from "../../lib/data/vaults";
import OperatorConsole from "../components/OperatorConsole";

export default async function OperatorPage() {
  const vaults = await getVaults();

  return (
    <main className="page">
      <OperatorConsole vaults={vaults} />
    </main>
  );
}
