import { redirect } from "next/navigation";

export default async function RedeemPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  redirect(`/vaults/${id}#execute`);
}
