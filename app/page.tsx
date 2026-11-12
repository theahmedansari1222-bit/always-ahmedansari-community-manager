import { requireUser } from "@/lib/auth";
import Dashboard from "@/components/dashboard";
export const dynamic = "force-dynamic";
export default async function Home() {
  const { user, workspace } = await requireUser();
  return <Dashboard userEmail={user.email ?? "Account"} workspaceName={workspace.name} initialMode={workspace.reply_mode} />;
}
