import { readAdminAccessToken } from "@/lib/adminSessionServer";
import AiConfigClient from "./AiConfigClient";
import {
  getAiJobStatusSummary,
  getAiProviderKeyStatus,
  listAiJobControls,
  listAiPromptConfigs,
  type AiProvider,
} from "./actions";

const PROVIDERS: AiProvider[] = ["minimax", "openai", "openrouter"];

export default async function AiConfigPage() {
  const accessToken = await readAdminAccessToken();
  if (!accessToken) {
    return <AiConfigClient />;
  }

  let configs = null;
  let keyStatuses = null;
  let jobControls = null;
  let jobStatus = null;
  let error: string | null = null;

  try {
    const [loadedConfigs, providerStatuses, loadedControls, loadedStatus] = await Promise.all([
      listAiPromptConfigs(accessToken),
      Promise.all(PROVIDERS.map((provider) => getAiProviderKeyStatus(accessToken, provider))),
      listAiJobControls(accessToken),
      getAiJobStatusSummary(accessToken),
    ]);

    configs = loadedConfigs;
    jobControls = loadedControls;
    jobStatus = loadedStatus;
    keyStatuses = providerStatuses.reduce<Record<AiProvider, (typeof providerStatuses)[number]>>(
      (acc, status) => {
        acc[status.provider] = status;
        return acc;
      },
      {} as Record<AiProvider, (typeof providerStatuses)[number]>,
    );
  } catch (err) {
    error = err instanceof Error ? err.message : "Failed to load configs.";
  }

  if (error || !configs || !keyStatuses || !jobControls || !jobStatus) {
    return <AiConfigClient initialError={error ?? "Failed to load configs."} />;
  }

  return (
    <AiConfigClient
      initialConfigs={configs}
      initialKeyStatuses={keyStatuses}
      initialJobControls={jobControls}
      initialJobStatus={jobStatus}
    />
  );
}
