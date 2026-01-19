import { readAdminAccessToken } from "@/lib/adminSessionServer";
import { getAdminOverview } from "./actions";
import AdminOverviewClient from "./AdminOverviewClient";

export default async function AdminPage() {
  const accessToken = readAdminAccessToken();
  if (!accessToken) {
    return <AdminOverviewClient />;
  }

  let overview = null;
  let error: string | null = null;

  try {
    overview = await getAdminOverview(accessToken);
  } catch (err) {
    error = err instanceof Error ? err.message : "Failed to load admin overview.";
  }

  if (error) {
    return <AdminOverviewClient initialError={error} />;
  }

  return <AdminOverviewClient initialOverview={overview} />;
}
