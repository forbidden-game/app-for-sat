import { readAdminAccessToken } from "@/lib/adminSessionServer";
import { getStudyBehaviorList } from "./actions";
import BehaviorClient from "./BehaviorClient";

export default async function BehaviorPage() {
  const accessToken = await readAdminAccessToken();
  if (!accessToken) {
    return <BehaviorClient />;
  }

  let data = null;
  let error: string | null = null;

  try {
    data = await getStudyBehaviorList(accessToken, { limit: 30, windowDays: 7 });
  } catch (err) {
    error = err instanceof Error ? err.message : "Failed to load study behavior.";
  }

  if (error) {
    return <BehaviorClient initialError={error} />;
  }

  return <BehaviorClient initialData={data} />;
}
